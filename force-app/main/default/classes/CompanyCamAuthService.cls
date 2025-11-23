/**
 * Created by Devin on 1/30/2025.
 */

public with sharing class CompanyCamAuthService {
    private static final String CLIENT_ID = 'mz4ATCzfXwiNSFkyASLp7SUXJqieVcrUrfQ7';
    private static final String CLIENT_SECRET = 'sk_JomJZqjLyF5wJHUZq6ETnpUX73KUCB9RhGjF';
    private static final String TOKEN_URL = 'https://app.companycam.com/oauth/token';
    private static final String REDIRECT_URI = System.Url.getOrgDomainUrl().toString().replace('.com','-sites.com')+'/webhooks/services/apexrest/CompanyCamAuth';

    public static String getAccessToken(String authCode) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(TOKEN_URL);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        String body = 'client_id=' + CLIENT_ID +
                '&client_secret=' + CLIENT_SECRET +
                '&code=' + authCode +
                '&grant_type=authorization_code' +
                '&redirect_uri=' + REDIRECT_URI;
        req.setBody(body);

        Http http = new Http();
        HttpResponse res;
        try {
            res = http.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String accessToken = (String) responseMap.get('access_token');
                String refreshToken = (String) responseMap.get('refresh_token');

                // Store tokens in Custom Metadata, Platform Cache, or a Custom Object
                updateStoredTokens(accessToken, refreshToken);

                return accessToken;
            } else {
                System.debug('CompanyCam OAuth Error: ' + res.getBody());
                return null;
            }
        } catch (Exception e) {
            System.debug('CompanyCam OAuth Exception: ' + e.getMessage());
            return null;
        }
    }

    // Example: Store tokens in Custom Metadata, Platform Cache, or Custom Object
    private static void updateStoredTokens(String accessToken, String refreshToken) {
        // Logic to save accessToken & refreshToken (Custom Object, Custom Metadata, etc.)
        List<Company_Cam_Bearer_Token__c> companyCamBearerTokens = [SELECT Id,Token_Value__c,RefreshToken__c FROM Company_Cam_Bearer_Token__c];
        System.debug(companyCamBearerTokens);
        for (Company_Cam_Bearer_Token__c camBearerToken : companyCamBearerTokens){
            camBearerToken.Token_Value__c = accessToken;
            camBearerToken.RefreshToken__c = refreshToken;
        }
        System.debug(companyCamBearerTokens);
        update companyCamBearerTokens;
        System.debug('Access Token: ' + accessToken);
        System.debug('Refresh Token: ' + refreshToken);
    }

    public static Map<String,String> refreshAccessToken(String refreshToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(TOKEN_URL);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        String body = 'client_id=' + CLIENT_ID +
                '&client_secret=' + CLIENT_SECRET +
                '&refresh_token=' + refreshToken +
                '&grant_type=refresh_token';

        req.setBody(body);

        Http http = new Http();
        HttpResponse res;
        try {
            res = http.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String newAccessToken = (String) responseMap.get('access_token');
                String newRefreshToken = (String) responseMap.get('refresh_token');

                // Store new tokens
                updateStoredTokens(newAccessToken, newRefreshToken);
                Map<String,String> newAccessTokens = new Map<String, String>();
                newAccessTokens.put('access_token',newAccessToken);
                newAccessTokens.put('refresh_token',newRefreshToken);
                return newAccessTokens;
            } else {
                System.debug('CompanyCam Refresh Token Error: ' + res.getBody());
                return null;
            }
        } catch (Exception e) {
            System.debug('CompanyCam Refresh Token Exception: ' + e.getMessage());
            return null;
        }
    }
}