/**
 * Created by Devin on 10/31/2025.
 */
@IsTest
private class WebhookAuthUtilTest {

    // --- Mock provider that returns a fixed config ---
    private class MockCfgProvider implements WebhookAuthUtil.ConfigProvider {
        WebhookAuthUtil.Config cfg;
        MockCfgProvider(WebhookAuthUtil.Config c){ this.cfg = c; }
        public WebhookAuthUtil.Config load(String developerKey) { return cfg; }
    }

    // Helper to build a baseline config
    private static WebhookAuthUtil.Config baseCfg(Boolean reqKey, Boolean reqSig,
            String path, Integer tsTol, Integer idemSec) {
        WebhookAuthUtil.Config c = new WebhookAuthUtil.Config();
        c.developerKey              = 'boomerang';
        c.enabled                   = true;
        c.requireSharedKey          = reqKey;
        c.sharedKeyHeader           = 'X-API-Key';
        c.requireSignature          = reqSig;
        c.signatureHeader           = 'X-Signature';
        c.signaturePrefix           = 'sha256=';
        c.timestampHeader           = (tsTol == null) ? null : 'X-Timestamp';
        c.timestampToleranceSeconds = tsTol;
        c.webhookPath               = path;
        c.idempotencyWindowSeconds  = idemSec;
        return c;
    }

    private static RestRequest makeReq(Map<String,String> headers, String uri, String body) {
        RestRequest r = new RestRequest();
        r.httpMethod  = 'POST';
        r.requestURI  = String.isBlank(uri) ? '/services/apexrest/external/v1/BoomWorkOrder' : uri;
        r.requestBody = Blob.valueOf(body == null ? '' : body);
        if (headers != null) for (String k : headers.keySet()) r.addHeader(k, headers.get(k));
        return r;
    }

    private static void upsertSecret(String apiKey, String secret, Boolean active) {
        upsert new Webhook_Secrets__c(
                Name             = 'boomerang',
                Developer_Key__c = 'boomerang',
                Api_Key__c       = apiKey,
                Shared_Secret__c = secret,
                Active__c        = active
        ) Name;
    }

    @IsTest
    static void apiKey_ok() {
        // Inject config: require API key, no signature
        WebhookAuthUtil.setConfigProviderForTest(new MockCfgProvider(
                baseCfg(true, false, '/external/v1/BoomWorkOrder', null, null)
        ));
        upsertSecret('K-123', 'S-123', true);

        Map<String,String> h = new Map<String,String>{
                'X-Partner-Key' => 'boomerang',
                'X-API-Key'     => 'K-123'
        };
        WebhookAuthUtil.Result r = WebhookAuthUtil.authorize(makeReq(h, null, '{}'));
        System.assert(r.ok, r.reason);

        WebhookAuthUtil.resetConfigProviderForTest();
    }

    @IsTest
    static void missing_partner_key() {
        WebhookAuthUtil.setConfigProviderForTest(new MockCfgProvider(
                baseCfg(true, false, '/external/v1/BoomWorkOrder', null, null)
        ));
        upsertSecret('K-123', 'S-123', true);

        Map<String,String> h = new Map<String,String>{ 'X-API-Key' => 'K-123' };
        WebhookAuthUtil.Result r = WebhookAuthUtil.authorize(makeReq(h, null, '{}'));
        System.assertEquals(false, r.ok);
        System.assertEquals('Missing X-Partner-Key', r.reason);

        WebhookAuthUtil.resetConfigProviderForTest();
    }

    @IsTest
    static void path_mismatch_blocked() {
        WebhookAuthUtil.setConfigProviderForTest(new MockCfgProvider(
                baseCfg(true, false, '/external/v1/BoomWorkOrder', null, null)
        ));
        upsertSecret('K-123', 'S-123', true);

        Map<String,String> h = new Map<String,String>{
                'X-Partner-Key' => 'boomerang',
                'X-API-Key'     => 'K-123'
        };
        WebhookAuthUtil.Result r = WebhookAuthUtil.authorize(
                makeReq(h, '/services/apexrest/external/v1/OtherPath', '{}')
        );
        System.assertEquals(false, r.ok);
        System.assertEquals('Path mismatch for partner config', r.reason);

        WebhookAuthUtil.resetConfigProviderForTest();
    }

    @IsTest
    static void signature_ok_with_timestamp() {
        WebhookAuthUtil.setConfigProviderForTest(new MockCfgProvider(
                baseCfg(false, true, '/external/v1/BoomWorkOrder', 300, null)
        ));
        upsertSecret(null, 'SECRET-xyz', true);

        String body = '{"a":1}';
        Long ts = Datetime.now().getTime()/1000;

        String base = EncodingUtil.convertToHex(
                Crypto.generateDigest('SHA-256', Blob.valueOf(body))
        ) + '|' + String.valueOf(ts);
        String sig = 'sha256=' + WebhookAuthUtil.hmacSha256Hex(base, 'SECRET-xyz');

        Map<String,String> h = new Map<String,String>{
                'X-Partner-Key' => 'boomerang',
                'X-Timestamp'   => String.valueOf(ts),
                'X-Signature'   => sig
        };
        WebhookAuthUtil.Result r = WebhookAuthUtil.authorize(makeReq(h, null, body));
        System.assert(r.ok, r.reason);

        WebhookAuthUtil.resetConfigProviderForTest();
    }

    @IsTest
    static void timestamp_out_of_tolerance() {
        WebhookAuthUtil.setConfigProviderForTest(new MockCfgProvider(
                baseCfg(false, true, '/external/v1/BoomWorkOrder', 60, null)
        ));
        upsertSecret(null, 'SECRET-xyz', true);

        String body = '{}';
        Long ts = (Datetime.now().addSeconds(-3600).getTime()/1000); // way too old

        String base = EncodingUtil.convertToHex(
                Crypto.generateDigest('SHA-256', Blob.valueOf(body))
        ) + '|' + String.valueOf(ts);
        String sig = 'sha256=' + WebhookAuthUtil.hmacSha256Hex(base, 'SECRET-xyz');

        Map<String,String> h = new Map<String,String>{
                'X-Partner-Key' => 'boomerang',
                'X-Timestamp'   => String.valueOf(ts),
                'X-Signature'   => sig
        };
        WebhookAuthUtil.Result r = WebhookAuthUtil.authorize(makeReq(h, null, body));
        System.assertEquals(false, r.ok);
        System.assertEquals('Timestamp outside tolerance', r.reason);

        WebhookAuthUtil.resetConfigProviderForTest();
    }

    @IsTest
    static void idempotency_duplicate_rejected() {
        WebhookAuthUtil.setConfigProviderForTest(new MockCfgProvider(
                baseCfg(true, false, '/external/v1/BoomWorkOrder', null, 300)
        ));
        upsertSecret('K-123', 'S-123', true);

        Map<String,String> h = new Map<String,String>{
                'X-Partner-Key'   => 'boomerang',
                'X-API-Key'       => 'K-123',
                'Idempotency-Key' => 'dup-001'
        };

        RestRequest req = makeReq(h, null, '{}');

        WebhookAuthUtil.Result r1 = WebhookAuthUtil.authorize(req);
        WebhookAuthUtil.Result r2 = WebhookAuthUtil.authorize(req);

        System.assertEquals(true,  r1.ok, r1.reason);
        System.assertEquals(false, r2.ok);
        System.assertEquals('Duplicate within idempotency window', r2.reason);

        WebhookAuthUtil.resetConfigProviderForTest();
    }
}