/**
 * Created by Devin on 2/10/2025.
 */

@isTest
private class CompanyCamScheduledJobTest {

    @testSetup
    static void setupTestData() {
        // Insert Custom Metadata record using SetupOwnerId (ProfileId)
        Company_Cam_Bearer_Token__c tokenRecord = new Company_Cam_Bearer_Token__c(
                SetupOwnerId = UserInfo.getProfileId(),  // Profile-specific metadata
                RefreshToken__c = 'test_refresh_token'
        );
        insert tokenRecord;
    }

    @isTest
    static void testScheduledJobExecution() {
        // Set up mock HTTP response for token refresh
        Test.setMock(HttpCalloutMock.class, new CompanyCamAuthMock());

        Test.startTest();

        // Execute the scheduled job
        RefreshCompanyCamTokenJob job = new RefreshCompanyCamTokenJob();
        job.execute(null);

        Test.stopTest();

        // Fetch updated token to verify that it was refreshed
        Company_Cam_Bearer_Token__c updatedToken = Company_Cam_Bearer_Token__c.getInstance(UserInfo.getProfileId());

        // Assertions
        System.assertNotEquals(updatedToken.RefreshToken__c, 'test_refresh_token', 'Refresh token should be updated');
        System.assert(updatedToken.RefreshToken__c.startsWith('mock_'), 'Token value should be from the mock response');
    }

    // Mock class for handling token refresh responses
    private class CompanyCamAuthMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"access_token": "mock_access_token", "refresh_token": "mock_refresh_token"}');
            return res;
        }
    }
}