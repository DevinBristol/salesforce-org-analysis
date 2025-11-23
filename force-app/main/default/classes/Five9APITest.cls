/**
 * Created by Devin on 5/13/2024.
 */
//
@IsTest
private class Five9APITest {

    @IsTest static void sfPostVCTest(){
        //Prepare Test
        String TASK_ID = '00TSu000001KKejMAG';
        String SF_POST_VC_TEST_BODY = '{ "calls": [ { "errorMsg": null, "externalId": "163099", "isSuccess": true, "uploadUrl": "https://bristolnebraska.my.salesforce.com/services/data/v60.0/voicecalls/0LQR7000000p27p/audio_upload", "voiceCallId": "0LQR7000000p27p" } ] }';
        String EXPECTED_UPLOAD_URL = 'https://bristolnebraska.my.salesforce.com/services/data/v60.0/voicecalls/0LQR7000000p27p/audio_upload';

        MockHttpResponse sfPostVCTestMockRes = new MockHttpResponse(201,'Created',SF_POST_VC_TEST_BODY);
        Test.setMock(HttpCalloutMock.class,sfPostVCTestMockRes);


        Test.startTest();
        Five9API.sfPostVC sfPostVCTest = new Five9API.sfPostVC(TASK_ID);
        Test.stopTest();
        System.assertEquals(EXPECTED_UPLOAD_URL,sfPostVCTest.uploadUrl,'uploadUrl NO MATCH');

    }

    @IsTest static void f9LoginTest(){

        String F9_LOGIN_TEST_BODY = '{ "tokenId": "a2ef69b0-07f1-11ef-e662-df316d04618c", "sessionId": "1e234ad6cd7843c15abd51905db26b935b3222a796cb378f5938272a8adb976a", "orgId": "138083", "userId": "4764534", "context": { "cloudClientUrl": "https://api.prod.us.five9.net/", "pwdExpiryDays": "269", "cloudTokenUrl": "https://api.prod.us.five9.net/", "farmId": "71" }, "metadata": { "freedomUrl": "https://app.five9.com", "dataCenters": [ { "name": "Santa Clara Data Center", "uiUrls": [ { "host": "app-scl.five9.com", "port": "443", "routeKey": "SCLUI2zOFh", "version": "13.0.247" } ], "apiUrls": [ { "host": "app-scl.five9.com", "port": "443", "routeKey": "SCLAPIPXB6", "version": "13.0.247" } ], "loginUrls": [ { "host": "app-scl.five9.com", "port": "443", "routeKey": "SCLLGNYoI4", "version": "13.0.244" } ], "active": true } ] } }';
        String F9_EXPECTED_TOKEN_ID = 'a2ef69b0-07f1-11ef-e662-df316d04618c';
        String F9_EXPECTED_SESSION_ID = '1e234ad6cd7843c15abd51905db26b935b3222a796cb378f5938272a8adb976a';
        String F9_EXPECTED_FARM_ID = '71';

        MockHttpResponse f9LoginTestMockRes = new MockHttpResponse(200,'OK',F9_LOGIN_TEST_BODY);
        Test.setMock(HttpCalloutMock.class,f9LoginTestMockRes);

        Test.startTest();
        Five9API.f9Login f9LoginTest = new Five9API.f9Login();
        Test.stopTest();

        System.assertEquals(F9_EXPECTED_TOKEN_ID,f9LoginTest.f9tokenId,'Wrong token Id');
        System.assertEquals(F9_EXPECTED_SESSION_ID,f9LoginTest.f9sessionId,'Wrong f9sessionId');
        System.assertEquals(F9_EXPECTED_FARM_ID,f9LoginTest.f9farmId,'Wrong FarmId');

    }
    @IsTest static void f9StartSessionTest(){
        String F9_START_SESSION_TEST_BODY = '';
        String tokenId = 'a2ef69b0-07f1-11ef-e662-df316d04618c';
        String sessionId = '1e234ad6cd7843c15abd51905db26b935b3222a796cb378f5938272a8adb976a';
        String farmId = '71';

        MockHttpResponse f9StartSessionMockRes = new MockHttpResponse(204,'No Content',F9_START_SESSION_TEST_BODY);
        Test.setMock(HttpCalloutMock.class,f9StartSessionMockRes);
        Test.startTest();
        Five9API.f9StartSession f9StartSession = new Five9API.f9StartSession(sessionId,tokenId,farmId);
        Test.stopTest();
        System.assert(true);
        System.assertEquals(204,f9StartSession.statusCode,'Wrong code!!!');

    }
    @IsTest static void f9CheckSessionTest() {
        String F9_CHECK_SESSION_TEST_BODY = '"WORKING"';
        String tokenId = 'a2ef69b0-07f1-11ef-e662-df316d04618c';
        String sessionId = '1e234ad6cd7843c15abd51905db26b935b3222a796cb378f5938272a8adb976a';
        String farmId = '71';

        MockHttpResponse f9CheckSessionMockRes = new MockHttpResponse(200, 'OK', F9_CHECK_SESSION_TEST_BODY);
        Test.setMock(HttpCalloutMock.class, f9CheckSessionMockRes);
        Test.startTest();
        Five9API.f9CheckSession f9CheckSessionTest = new Five9API.f9CheckSession(sessionId,tokenId,farmId);
        Test.stopTest();

        System.assertEquals('"WORKING"', f9CheckSessionTest.body, 'the body is incorrect!!!');
    }
    @IsTest static void f9RecordingViewTest(){
        String F9_RECORDING_VIEW_TEST_BODY =
                '{"id":"e6fb995b-5cb6-4b35-8993-10eea1dd5806","records":[' +
                '{"id":"169874","campaignId":"20","created":1715302354617,"number":"4029472517","name":"","length":13700,"status":"WAITING_FOR_UPLOAD","callSessionId":"2F0B5FA878F9254E8AFFBC5402F5D536"},' +
                '{"id":"169878","campaignId":"20","created":1715302354617,"number":"4029472517","name":"","length":13700,"status":"WAITING_FOR_UPLOAD","callSessionId":"2F0B5FA878F9454E8AFFBC5402F5D536"},' +
                '{"id":"169877","campaignId":"20","created":1715302328685,"number":"4022766590","name":"","length":7060,"status":"WAITING_FOR_UPLOAD","callSessionId":"4FFFB2DC954A4FC1B074382F6D87CF09"}],"recordsTotal":4216,"hasMore":true,"currentPage":0}';
        String f9AgentId = '4618732';
        String f9CallRecordingId = '169878';
        String f9CallSessionId = '2F0B5FA878F9454E8AFFBC5402F5D536';
        String tokenId = 'a2ef69b0-07f1-11ef-e662-df316d04618c';
        String sessionId = '1e234ad6cd7843c15abd51905db26b935b3222a796cb378f5938272a8adb976a';
        String farmId = '71';
        MockHttpResponse f9RecordingViewMockRes = new MockHttpResponse(200, 'OK', F9_RECORDING_VIEW_TEST_BODY);
        Test.setMock(HttpCalloutMock.class, f9RecordingViewMockRes);
        Test.startTest();
        Five9API.f9RecordingView f9RecordingViewTest = new Five9API.f9RecordingView(sessionId, tokenId, farmId, f9AgentId,f9CallSessionId);
        Test.stopTest();

        // Assert that the returned recordingId is from the call with the expected sessionId.
        // In this case it should return the MIDDLE call from the provided Json Body...
        System.assertEquals(f9CallRecordingId,f9RecordingViewTest.f9callRecordingId, 'wrong recordingId!!!');
        System.assertEquals(200,f9RecordingViewTest.statusCode,'Status Code :::'+f9RecordingViewTest.statusCode);
    }
    @IsTest static void f9GetNoticeTest(){
        // Mock Response JSON
        String F9_GET_NOTICE_TEST_BODY = '{"notices":[{"id":"12345","message":"System maintenance scheduled"}]}';
        // Test Input Parameters
        String tokenId = 'a2ef69b0-07f1-11ef-e662-df316d04618c';
        String sessionId = '1e234ad6cd7843c15abd51905db26b935b3222a796cb378f5938272a8adb976a';
        String farmId = '71';
        MockHttpResponse f9GetNoticeMockRes = new MockHttpResponse(200, 'OK', F9_GET_NOTICE_TEST_BODY);
        Test.setMock(HttpCalloutMock.class, f9GetNoticeMockRes);
        Test.startTest();
        Five9API.f9GetNotice f9GetNotice = new Five9API.f9GetNotice(sessionId, tokenId, farmId);
        Test.stopTest();

        System.assertNotEquals(null, f9GetNotice.statusCode, 'Response should not be null');
        System.assert(f9GetNotice.body.toString().contains('"notices"'), 'Response should contain notices');
    }
    @IsTest static void f9RecordingViewNextTest(){
        String F9_RECORDING_VIEW_TEST_BODY =
                '{"id":"e6fb995b-5cb6-4b35-8993-10eea1dd5806","records":[' +
                '{"id":"169874","campaignId":"20","created":1715302354617,"number":"4029472517","name":"","length":13700,"status":"WAITING_FOR_UPLOAD","callSessionId":"2F0B5FA878F9254E8AFFBC5402F5D536"},' +
                '{"id":"169878","campaignId":"20","created":1715302354617,"number":"4029472517","name":"","length":13700,"status":"WAITING_FOR_UPLOAD","callSessionId":"2F0B5FA878F9454E8AFFBC5402F5D536"},' +
                '{"id":"169877","campaignId":"20","created":1715302328685,"number":"4022766590","name":"","length":7060,"status":"WAITING_FOR_UPLOAD","callSessionId":"4FFFB2DC954A4FC1B074382F6D87CF09"}],"recordsTotal":4216,"hasMore":true,"currentPage":0}';
        String f9AgentId = '4618732';
        String f9CallRecordingId = '169878';
        String f9CallSessionId = '2F0B5FA878F9454E8AFFBC5402F5D536';
        String tokenId = 'a2ef69b0-07f1-11ef-e662-df316d04618c';
        String sessionId = '1e234ad6cd7843c15abd51905db26b935b3222a796cb378f5938272a8adb976a';
        String farmId = '71';
        String RecordingViewId = 'e6fb995b-5cb6-4b35-8993-10eea1dd5806';
        MockHttpResponse f9RecordingViewMockRes = new MockHttpResponse(200, 'OK', F9_RECORDING_VIEW_TEST_BODY);
        Test.setMock(HttpCalloutMock.class, f9RecordingViewMockRes);
        Test.startTest();
        Five9API.f9RecordingViewNext f9RecordingViewTest = new Five9API.f9RecordingViewNext(sessionId, tokenId, farmId, f9AgentId,f9CallSessionId,RecordingViewId);
        Test.stopTest();

        // Assert that the returned recordingId is from the call with the expected sessionId.
        // In this case it should return the MIDDLE call from the provided Json Body...
        System.assertEquals(f9CallRecordingId,f9RecordingViewTest.f9callRecordingId, 'wrong recordingId!!!');
        System.assertEquals(200,f9RecordingViewTest.statusCode,'Status Code :::'+f9RecordingViewTest.statusCode);
    }
    @IsTest static void f9GetRecordingTest(){
        final String TOKEN_ID = 'a2ef69b0-07f1-11ef-e662-df316d04618c';
        final String SESSION_ID = '1e234ad6cd7843c15abd51905db26b935b3222a796cb378f5938272a8adb976a';
        final String FARM_ID = '71';
        final String AGENT_ID = '4618732';
        final String CALL_RECORDING_ID = '169748';
        final Blob BLOB_BODY = Blob.toPdf('TEST BLOB');

        MockHttpResponse f9GetRecordingMockRes = new MockHttpResponse(200,'OK',BLOB_BODY);
        Test.setMock(HttpCalloutMock.class,f9GetRecordingMockRes);
        Test.startTest();
        Five9API.f9GetRecording f9GetRecording = new Five9API.f9GetRecording(SESSION_ID,TOKEN_ID,FARM_ID,AGENT_ID,CALL_RECORDING_ID);
        Test.stopTest();
        System.assertNotEquals(null,f9GetRecording.bodyBlob,'File is null!');
        System.assertEquals(200,f9GetRecording.statusCode,'Status Code :::'+f9GetRecording.statusCode);
    }
    @IsTest static void f9AcceptNoticeTest(){

        String tokenId = 'a2ef69b0-07f1-11ef-e662-df316d04618c';
        String sessionId = '1e234ad6cd7843c15abd51905db26b935b3222a796cb378f5938272a8adb976a';
        String farmId = '71';
        String RecordingViewId = 'e6fb995b-5cb6-4b35-8993-10eea1dd5806';

        MockHttpResponse f9GetRecordingMockRes = new MockHttpResponse(200,'OK',RecordingViewId);
        Test.setMock(HttpCalloutMock.class,f9GetRecordingMockRes);
        Test.startTest();
        Five9API.f9AcceptNotice f9AcceptNotice = new Five9API.f9AcceptNotice(sessionId,tokenId,farmId,RecordingViewId);
        Test.stopTest();
        System.assertEquals(200,f9AcceptNotice.statusCode,'Status Code :::'+f9AcceptNotice.statusCode);
    }


    @IsTest static void sfPostRecordingTest(){
        final String UPLOAD_URL = 'https://bristolnebraska.my.salesforce.com/services/data/v60.0/voicecalls/0LQR7000000p27p/audio_upload';
        final String BOUNDARY = '----------------------------741e90d31eff';
        final Blob BLOB_BODY = Blob.toPdf('TEST BLOB');

        MockHttpResponse sfPostRecordingMockRes = new MockHttpResponse(204,'No Content','');
        Test.setMock(HttpCalloutMock.class,sfPostRecordingMockRes);
        Test.startTest();
        Five9API.sfPostRecording sfPostRecordingTest = new Five9API.sfPostRecording(UPLOAD_URL,BLOB_BODY,BOUNDARY);
        Test.stopTest();
        System.assertEquals(204,sfPostRecordingTest.statusCode,'Status Code :::'+sfPostRecordingTest.statusCode);
    }

    @IsTest static void testGetFive9MediaProviderId(){

        Test.startTest();
        String Five9MediaProviderId = OrgSettings.getFive9MediaProviderId();
        Test.stopTest();

        System.Assert.isNotNull(Five9MediaProviderId);
    }


}