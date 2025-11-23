/**
 * Created by Devin on 2/10/2025.
 */
@IsTest
public with sharing class CompanyCamAuthControllerTest {
        @IsTest
        static void testHandleAuthCallback_Success() {
            // Mock the request with an authorization code
            RestRequest req = new RestRequest();
            req.requestUri = '/services/apexrest/yourEndpoint';
            req.httpMethod = 'GET';
            req.addParameter('code', 'testAuthCode');
            RestContext.request = req;

            RestResponse res = new RestResponse();
            RestContext.response = res;

            // Mock the CompanyCamAuthService to return a fake access token
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockCompanyCamAuthService());
            CompanyCamAuthController.handleAuthCallback();
            Test.stopTest();

            // Verify success response
            System.assertEquals('Success! Access token retrieved.', res.responseBody.toString(), 'Expected success message');
        }

        @IsTest
        static void testHandleAuthCallback_NoCode() {
            // Mock the request without an authorization code
            RestRequest req = new RestRequest();
            req.requestUri = '/services/apexrest/yourEndpoint';
            req.httpMethod = 'GET';
            RestContext.request = req;

            RestResponse res = new RestResponse();
            RestContext.response = res;

            // Call the method
            Test.startTest();
            CompanyCamAuthController.handleAuthCallback();
            Test.stopTest();

            // Verify error response
            System.assertEquals('Error: Failed to retrieve access token.', res.responseBody.toString(), 'Expected error for missing code');
        }

        @IsTest
        static void testHandleAuthCallback_FailedTokenRetrieval() {
            // Mock the request with an authorization code
            RestRequest req = new RestRequest();
            req.requestUri = '/services/apexrest/yourEndpoint';
            req.httpMethod = 'GET';
            req.addParameter('code', 'testAuthCode');
            RestContext.request = req;

            RestResponse res = new RestResponse();
            RestContext.response = res;

            // Mock the CompanyCamAuthService to return null (simulate failure)
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MockFailedCompanyCamAuthService());
            CompanyCamAuthController.handleAuthCallback();
            Test.stopTest();

            // Verify failure response
            System.assertEquals('Error: Failed to retrieve access token.', res.responseBody.toString(), 'Expected failure message');
        }

        // Mock class for successful token retrieval
        private class MockCompanyCamAuthService implements HttpCalloutMock {
            public HTTPResponse respond(HTTPRequest req) {
                HttpResponse res = new HttpResponse();
                res.setBody('{"access_token": "fakeAccessToken"}');
                res.setStatusCode(200);
                return res;
            }
        }

        // Mock class for failed token retrieval
        private class MockFailedCompanyCamAuthService implements HttpCalloutMock {
            public HTTPResponse respond(HTTPRequest req) {
                HttpResponse res = new HttpResponse();
                res.setBody('{}');
                res.setStatusCode(400);
                return res;
            }
        }
    @IsTest
    static void testGetAuthorizationUrl() {
        Test.startTest();

        // Call the method
        String authUrl = CompanyCamAuthController.getAuthorizationUrl();

        // Expected values
        String expectedClientId = 'mz4ATCzfXwiNSFkyASLp7SUXJqieVcrUrfQ7';
        String expectedRedirectUri = System.Url.getOrgDomainUrl().toString().replace('.com','-sites.com')+'/webhooks/services/apexrest/CompanyCamAuth';
        String expectedScope = 'read+write+destroy';

        // Assertions
        System.assert(authUrl.contains('client_id=' + expectedClientId), 'Client ID should be present in URL');
        System.assert(authUrl.contains('redirect_uri=' + expectedRedirectUri), 'Redirect URI should be correctly included');
        System.assert(authUrl.contains('response_type=code'), 'Response type should be "code"');
        System.assert(authUrl.contains('scope=' + expectedScope), 'Scope should be set correctly');

        Test.stopTest();
    }
    // ---------------------------------------------------------------------
    // Mock for a successful token refresh callout.
    // ---------------------------------------------------------------------
    private class RefreshAccessTokenSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            // Simulate a successful JSON response with new tokens.
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"access_token": "newAccessTokenValue", "refresh_token": "newRefreshTokenValue"}');
            res.setStatusCode(200);
            return res;
        }
    }

    // ---------------------------------------------------------------------
    // Mock for an error scenario (non-200 status code).
    // ---------------------------------------------------------------------
    private class RefreshAccessTokenErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            // Simulate an error response
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error": "invalid_request"}');
            res.setStatusCode(400);
            return res;
        }
    }

    // ---------------------------------------------------------------------
    // Test method for the successful token refresh.
    // ---------------------------------------------------------------------
    @isTest
    static void testRefreshAccessTokenSuccess() {
        // Set the mock callout for a successful response.
        Test.setMock(HttpCalloutMock.class, new RefreshAccessTokenSuccessMock());
        String dummyRefreshToken = 'dummyRefreshToken';

        Test.startTest();
        // Call the method; it will use the mock callout.
        Map<String, String> tokens = CompanyCamAuthService.refreshAccessToken(dummyRefreshToken);
        Test.stopTest();

        // Verify that the tokens are returned and have the expected values.
        System.assertNotEquals(null, tokens, 'Expected tokens to be returned');
        System.assertEquals('newAccessTokenValue', tokens.get('access_token'), 'Access token mismatch');
        System.assertEquals('newRefreshTokenValue', tokens.get('refresh_token'), 'Refresh token mismatch');
    }

    // ---------------------------------------------------------------------
    // Test method for the error scenario.
    // ---------------------------------------------------------------------
    @isTest
    static void testRefreshAccessTokenError() {
        // Set the mock callout for an error response.
        Test.setMock(HttpCalloutMock.class, new RefreshAccessTokenErrorMock());
        String dummyRefreshToken = 'dummyRefreshToken';

        Test.startTest();
        // Call the method; it will use the error mock callout.
        Map<String, String> tokens = CompanyCamAuthService.refreshAccessToken(dummyRefreshToken);
        Test.stopTest();

        // Since the response status is not 200, the method should return null.
        System.assertEquals(null, tokens, 'Expected null tokens when callout fails');
    }


}