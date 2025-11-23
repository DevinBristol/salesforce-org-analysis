/**
 * Created by noahr on 5/9/2024.
 */

/**
 * TODO: SET STATIC FINAL AT TOP
 * TODO: SET UP MOCK RESPONSES
 * TODO: IMPLEMENT
 */

@IsTest
public with sharing class Five9ResponseTests {

    @IsTest static void sfPostVCTest(){
        //Prepare Test
        String TASK_ID = '00TSu000001KKejMAG';
        String SF_POST_VC_TEST_BODY = '{ "calls": [ { "errorMsg": null, "externalId": "163099", "isSuccess": true, "uploadUrl": "https://bristolnebraska.my.salesforce.com/services/data/v60.0/voicecalls/0LQR7000000p27p/audio_upload", "voiceCallId": "0LQR7000000p27p" } ] }';
        String EXPECTED_UPLOAD_URL = 'https://bristolnebraska.my.salesforce.com/services/data/v60.0/voicecalls/0LQR7000000p27p/audio_upload';

        MockHttpResponse sfPostVCMockRes = new MockHttpResponse(201,'Created',SF_POST_VC_TEST_BODY);
        Test.setMock(HttpCalloutMock.class,sfPostVCMockRes);
        Test.startTest();
        Response sfPostVCResponse = Five9Response.sfPostVC(TASK_ID);
        Test.stopTest();
        System.assertEquals(EXPECTED_UPLOAD_URL,sfPostVCResponse.uploadUrl, 'uploadUrl NOT FOUND');
    }
    @IsTest static void f9LoginTest(){
        String F9_LOGIN_TEST_BODY = '{ "tokenId": "a2ef69b0-07f1-11ef-e662-df316d04618c", "sessionId": "1e234ad6cd7843c15abd51905db26b935b3222a796cb378f5938272a8adb976a", "orgId": "138083", "userId": "4764534", "context": { "cloudClientUrl": "https://api.prod.us.five9.net/", "pwdExpiryDays": "269", "cloudTokenUrl": "https://api.prod.us.five9.net/", "farmId": "71" }, "metadata": { "freedomUrl": "https://app.five9.com", "dataCenters": [ { "name": "Santa Clara Data Center", "uiUrls": [ { "host": "app-scl.five9.com", "port": "443", "routeKey": "SCLUI2zOFh", "version": "13.0.247" } ], "apiUrls": [ { "host": "app-scl.five9.com", "port": "443", "routeKey": "SCLAPIPXB6", "version": "13.0.247" } ], "loginUrls": [ { "host": "app-scl.five9.com", "port": "443", "routeKey": "SCLLGNYoI4", "version": "13.0.244" } ], "active": true } ] } }';
        String F9_EXPECTED_TOKEN_ID = 'a2ef69b0-07f1-11ef-e662-df316d04618c';
        String F9_EXPECTED_SESSION_ID = '1e234ad6cd7843c15abd51905db26b935b3222a796cb378f5938272a8adb976a';
        String F9_EXPECTED_FARM_ID = '71';
        MockHttpResponse f9LoginMockRes = new MockHttpResponse(200,'OK',F9_LOGIN_TEST_BODY);
        Test.setMock(HttpCalloutMock.class,f9LoginMockRes);
        Test.startTest();
        Response f9loginResponse = Five9Response.f9Login();
        Test.stopTest();
        System.assertEquals(F9_EXPECTED_TOKEN_ID,f9loginResponse.f9tokenId,'Wrong token Id');
        System.assertEquals(F9_EXPECTED_SESSION_ID,f9loginResponse.f9sessionId,'Wrong f9sessionId');
        System.assertEquals(F9_EXPECTED_FARM_ID,f9loginResponse.f9farmId,'Wrong FarmId');
    }

    @IsTest static void f9StartSessionTest(){
        String F9_START_SESSION_TEST_BODY = '';
        String tokenId = 'a2ef69b0-07f1-11ef-e662-df316d04618c';
        String sessionId = '1e234ad6cd7843c15abd51905db26b935b3222a796cb378f5938272a8adb976a';
        String farmId = '71';
        MockHttpResponse f9StartSessionMockRes = new MockHttpResponse(204,'No Content',F9_START_SESSION_TEST_BODY);
        Test.setMock(HttpCalloutMock.class,f9StartSessionMockRes);
        Test.startTest();
        Response f9StartSessionResponse = Five9Response.f9startSession(sessionId,tokenId,farmId);
        Test.stopTest();
        System.assertEquals(204,f9StartSessionResponse.statusCode,'Wrong code!!!');
    }
    @IsTest static void f9CheckSessionTest() {
        String F9_CHECK_SESSION_TEST_BODY = '"WORKING"';
        String tokenId = 'a2ef69b0-07f1-11ef-e662-df316d04618c';
        String sessionId = '1e234ad6cd7843c15abd51905db26b935b3222a796cb378f5938272a8adb976a';
        String farmId = '71';

        MockHttpResponse f9CheckSessionMockRes = new MockHttpResponse(200, 'OK', F9_CHECK_SESSION_TEST_BODY);
        Test.setMock(HttpCalloutMock.class, f9CheckSessionMockRes);
        Test.startTest();
        Response f9CheckSessionResponse = Five9Response.f9CheckSession(sessionId, tokenId,farmId);
        Test.stopTest();

        System.assertEquals('"WORKING"', f9CheckSessionResponse.body, 'the body is incorrect!!!');
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
        Response f9RecordingViewResponse = Five9Response.f9RecordingView(sessionId, tokenId, farmId, f9AgentId,f9CallSessionId);
        Test.stopTest();

        // Assert that the returned recordingId is from the call with the expected sessionId.
        // In this case it should return the MIDDLE call from the provided Json Body...
        System.assertEquals(f9CallRecordingId,f9RecordingViewResponse.f9callRecordingId, 'wrong recordingId!!!');
        System.assertEquals(200,f9RecordingViewResponse.statusCode,'Status Code :::'+f9RecordingViewResponse.statusCode);
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
        Response f9GetRecordingResponse = Five9Response.f9GetRecording(SESSION_ID,TOKEN_ID,FARM_ID,AGENT_ID,CALL_RECORDING_ID);
        Test.stopTest();
        System.assertNotEquals(null,f9GetRecordingResponse.bodyBlob,'File is null!');
        System.assertEquals(200,f9GetRecordingResponse.statusCode,'Status Code :::'+f9GetRecordingResponse.statusCode);
    }


    @IsTest static void sfPostRecordingTest(){
        final String UPLOAD_URL = 'https://code-with-me.global.jetbrains.com/vGzrhnKR0aC3rGyjmMYcDA#p=IU&fp=FCA7943A364C190FAD9237C74C746024BA9ECEDAFCF4A8B1A2A25D4533290B5E&newUi=true';
        final String BOUNDARY = '----------------------------741e90d31eff';
        final Blob BLOB_BODY = Blob.toPdf('TEST BLOB');

        MockHttpResponse sfPostRecordingMockRes = new MockHttpResponse(204,'No Content','');
        Test.setMock(HttpCalloutMock.class,sfPostRecordingMockRes);
        Test.startTest();
        Response sfPostRecordingRes = Five9Response.sfPostRecording(UPLOAD_URL,BLOB_BODY,BOUNDARY);
        Test.stopTest();
        System.assertEquals(204,sfPostRecordingRes.statusCode,'Status Code :::'+sfPostRecordingRes.statusCode);
    }



}