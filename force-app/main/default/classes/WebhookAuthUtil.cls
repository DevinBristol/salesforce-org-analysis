/**
 * Created by Devin on 10/30/2025.
 */
global with sharing class WebhookAuthUtil {

    // ---------------- NEW: Config DTO & Provider ----------------
    public class Config {
        public String  developerKey;
        public Boolean enabled;
        public Boolean requireSharedKey;
        public String  sharedKeyHeader;
        public Boolean requireSignature;
        public String  signatureHeader;
        public String  signaturePrefix;
        public String  timestampHeader;
        public Integer timestampToleranceSeconds;
        public String  webhookPath;
        public Integer idempotencyWindowSeconds;
        public String  matchBy;
        public String  matchValue;
    }
    public interface ConfigProvider {
        Config load(String developerKey);
    }
    // Real provider that reads CMDT in production orgs
    public class CmdtConfigProvider implements ConfigProvider {
        public Config load(String developerKey) {
            Webhook_Config__mdt m = [
                    SELECT DeveloperKey__c, Enabled__c,
                            Require_Shared_Key__c, Shared_Key_Header__c,
                            Require_Signature__c, Signature_Header__c, Signature_Prefix__c,
                            Timestamp_Header__c, Timestamp_Tolerance_Seconds__c,
                            Webhook_Path__c, Idempotency_Window_Seconds__c,
                            Match_By__c, Match_Value__c
                    FROM Webhook_Config__mdt
                    WHERE DeveloperKey__c = :developerKey
                    LIMIT 1
            ];
            if (m == null) return null;
            Config c = new Config(); c.developerKey = m.DeveloperKey__c; c.enabled = m.Enabled__c; c.requireSharedKey = m.Require_Shared_Key__c; c.sharedKeyHeader = m.Shared_Key_Header__c; c.requireSignature = m.Require_Signature__c; c.signatureHeader = m.Signature_Header__c; c.signaturePrefix = m.Signature_Prefix__c; c.timestampHeader = m.Timestamp_Header__c; c.timestampToleranceSeconds  = (m.Timestamp_Tolerance_Seconds__c == null) ? null : Integer.valueOf(m.Timestamp_Tolerance_Seconds__c); c.webhookPath = m.Webhook_Path__c; c.idempotencyWindowSeconds = (m.Idempotency_Window_Seconds__c == null) ? null : Integer.valueOf(m.Idempotency_Window_Seconds__c); c.matchBy = m.Match_By__c; c.matchValue = m.Match_Value__c;
            return c;
        }
    }

    @TestVisible private static ConfigProvider cfgProvider = new CmdtConfigProvider();
    public static void setConfigProviderForTest(ConfigProvider p) { cfgProvider = p; }
    public static void resetConfigProviderForTest() { cfgProvider = new CmdtConfigProvider(); }

    // ---------------- existing Result class stays the same ----------------
    global class Result {
        public Boolean ok;
        public String reason;
        public String developerKey;
        public String apiKey;
        public String sharedSecret;
        public Map<String,String> headers = new Map<String,String>();
    }

    // ---------------- authorize(req) — only the CMDT load is swapped ----------------
    global static Result authorize(RestRequest req) {
        Result r = new Result();
        String devKey = getHeader(req, 'X-Partner-Key');
        r.developerKey = devKey;

        if (String.isBlank(devKey)) {
            r.ok = false; r.reason = 'Missing X-Partner-Key'; return r;
        }

        // 🔁 NEW: load config via provider (mockable in tests)
        Config cfg = (cfgProvider == null) ? null : cfgProvider.load(devKey);
        if (cfg == null || cfg.enabled != true) {
            r.ok = false; r.reason = 'Partner disabled or not found'; return r;
        }

        // Optional path guard
        if (!String.isBlank(cfg.webhookPath) && req != null && !String.isBlank(req.requestURI)) {
            if (!req.requestURI.toLowerCase().contains(cfg.webhookPath.toLowerCase())) {
                r.ok = false; r.reason = 'Path mismatch for partner config'; return r;
            }
        }

        // Secrets remain from List Custom Setting (DML allowed in tests)
        Webhook_Secrets__c sec = [
                SELECT Developer_Key__c, Api_Key__c, Shared_Secret__c, Active__c
                FROM Webhook_Secrets__c
                WHERE Developer_Key__c = :devKey
                LIMIT 1
        ];
        if (sec == null || sec.Active__c != true) {
            r.ok = false; r.reason = 'Secret not found or inactive'; return r;
        }
        r.apiKey       = sec.Api_Key__c;
        r.sharedSecret = sec.Shared_Secret__c;

        // Resolve header names
        String apiKeyHeader = !String.isBlank(cfg.sharedKeyHeader) ? cfg.sharedKeyHeader : 'X-API-Key';
        String sigHeader    = !String.isBlank(cfg.signatureHeader) ? cfg.signatureHeader : 'X-Signature';
        String tsHeader     = cfg.timestampHeader;

        // Collect headers
        Map<String,String> H = new Map<String,String>{
                'X-Partner-Key'   => getHeader(req, 'X-Partner-Key'),
                apiKeyHeader      => getHeader(req, apiKeyHeader),
                sigHeader         => getHeader(req, sigHeader),
                'Idempotency-Key' => getHeader(req, 'Idempotency-Key')
        };
        if (!String.isBlank(tsHeader)) H.put(tsHeader, getHeader(req, tsHeader));
        r.headers = H;

        // Idempotency (per-transaction)
        if (cfg.idempotencyWindowSeconds != null && cfg.idempotencyWindowSeconds > 0) {
            String idem = H.get('Idempotency-Key');
            if (!String.isBlank(idem)) {
                if (isRecentDuplicate(devKey, idem, cfg.idempotencyWindowSeconds)) {
                    r.ok = false; r.reason = 'Duplicate within idempotency window'; return r;
                } else {
                    rememberIdempotencyKey(devKey, idem);
                }
            }
        }

        // Timestamp tolerance
        if (!String.isBlank(tsHeader) && cfg.timestampToleranceSeconds != null && cfg.timestampToleranceSeconds > 0) {
            String tsStr = H.get(tsHeader);
            if (!String.isBlank(tsStr)) {
                Long nowSec = Datetime.now().getTime() / 1000;
                Long reqSec;
                try { reqSec = Long.valueOf(tsStr); } catch (Exception e) { reqSec = null; }
                if (reqSec != null && Math.abs(nowSec - reqSec) > cfg.timestampToleranceSeconds) {
                    r.ok = false; r.reason = 'Timestamp outside tolerance'; return r;
                }
            }
        }

        // API Key required?
        if (cfg.requireSharedKey) {
            String providedApiKey = H.get(apiKeyHeader);
            if (String.isBlank(r.apiKey) || !constTimeEquals(r.apiKey, providedApiKey)) {
                r.ok = false; r.reason = 'Invalid ' + apiKeyHeader; return r;
            }
        }

        // Signature required?
        if (cfg.requireSignature) {
            String providedSig = H.get(sigHeader);
            if (String.isBlank(providedSig) || String.isBlank(r.sharedSecret)) {
                r.ok = false; r.reason = 'Missing signature'; return r;
            }
            if (!String.isBlank(cfg.signaturePrefix) && providedSig.startsWithIgnoreCase(cfg.signaturePrefix)) {
                providedSig = providedSig.substring(cfg.signaturePrefix.length());
            }
            Blob body   = (req != null && req.requestBody != null) ? req.requestBody : Blob.valueOf('');
            String base = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', body));
            if (!String.isBlank(tsHeader) && !String.isBlank(H.get(tsHeader))) base = base + '|' + H.get(tsHeader);
            String expected = hmacSha256Hex(base, r.sharedSecret);
            if (!constTimeEquals(expected, providedSig)) {
                r.ok = false; r.reason = 'Invalid signature'; return r;
            }
        }

        // If neither factor is required, accept either one if provided
        if (!cfg.requireSharedKey && !cfg.requireSignature) {
            Boolean eitherOk = false;
            if (!eitherOk && !String.isBlank(H.get(apiKeyHeader)) && !String.isBlank(r.apiKey)) {
                eitherOk = constTimeEquals(r.apiKey, H.get(apiKeyHeader));
            }
            if (!eitherOk && !String.isBlank(H.get(sigHeader)) && !String.isBlank(r.sharedSecret)) {
                String providedSig = H.get(sigHeader);
                if (!String.isBlank(cfg.signaturePrefix) && providedSig.startsWithIgnoreCase(cfg.signaturePrefix)) {
                    providedSig = providedSig.substring(cfg.signaturePrefix.length());
                }
                Blob body   = (req != null && req.requestBody != null) ? req.requestBody : Blob.valueOf('');
                String base = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', body));
                if (!String.isBlank(tsHeader) && !String.isBlank(H.get(tsHeader))) base = base + '|' + H.get(tsHeader);
                String expected = hmacSha256Hex(base, r.sharedSecret);
                eitherOk = constTimeEquals(expected, providedSig);
            }
            if (!eitherOk) { r.ok = false; r.reason = 'No valid auth factor provided'; return r; }
        }

        r.ok = true; r.reason = 'ok';
        return r;
    }

    // ------------- existing helpers (unchanged) -------------
    private static String getHeader(RestRequest req, String name){
        return (req == null || req.headers == null) ? null : req.headers.get(name);
    }
    private static Set<String> idemKeys = new Set<String>();
    private static Boolean isRecentDuplicate(String devKey, String idemKey, Integer windowSec){ return idemKeys.contains(devKey + '|' + idemKey); }
    private static void rememberIdempotencyKey(String devKey, String idemKey){ idemKeys.add(devKey + '|' + idemKey); }

    global static Boolean constTimeEquals(String a, String b){
        if (String.isBlank(a) || String.isBlank(b)) return false;
        Blob da = Crypto.generateDigest('SHA-256', Blob.valueOf(a));
        Blob db = Crypto.generateDigest('SHA-256', Blob.valueOf(b));
        return EncodingUtil.convertToHex(da) == EncodingUtil.convertToHex(db);
    }
    global static String hmacSha256Hex(String message, String secret){
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(message), Blob.valueOf(secret));
        return EncodingUtil.convertToHex(mac);
    }
}