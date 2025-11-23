/**
 * Created by noahr on 5/16/2024.
 */
@IsTest
public class MultiRequestFive9MocksTest {
    static Integer testCallDepth = 0;
    static final Integer MAX_TEST_CALL_DEPTH = 3;  // Prevents infinite recursion

    @TestSetup
    static void setupTestData() {
        // Create a test user
        User testUser = new User(
                FirstName = 'Ben',
                LastName = 'TestUser',
                Username = 'ben.testuser@example.com' + System.currentTimeMillis(),
                Email = 'ben.testuser@example.com',
                Alias = 'btest',
                TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
                LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        // Create a test task associated with Five9 session
        Task testTask = new Task(
                OwnerId = testUser.Id,
                Five9DNIS__c = '4022174741',
                Five9ANI__c = '4022356146',
                Five9__Five9SessionId__c = '627B8A49487546EAA1B6F92418A6F9C2',
                Five9TalkAndHoldTimeInSeconds__c = 27,
                CallType = 'Outbound',
                Five9Agent__c = 'benr@bristolwindows.org',
                Subject = 'Test Five9 Task'
        );
        insert testTask;

        // Create an AudioProcessingJob entry
        AudioProcessingJob__c testJob = new AudioProcessingJob__c(
                TaskId__c = testTask.Id,
                Status__c = 'Queued'
        );
        insert testJob;
    }
//    public static void TestFive9Chain(){
//        testCallDepth++;
//        if (testCallDepth > MAX_TEST_CALL_DEPTH) {
//            System.debug('🔹 Test reached maximum depth, exiting early.');
//            return;
//        }
//        //PostVCMock
//        String SF_POST_VC_TEST_BODY = '{ "calls": [ { "errorMsg": null, "externalId": "163099", "isSuccess": true, "uploadUrl": "https://bristolnebraska.my.salesforce.com/services/data/v60.0/voicecalls/0LQR7000000p27p/audio_upload", "voiceCallId": "0LQR7000000p27p" } ] }';
//        MockHttpResponse sfPostVCTestMockRes = new MockHttpResponse(201,'Created',SF_POST_VC_TEST_BODY);
//
//        //LoginTestMock
//        String F9_LOGIN_TEST_BODY = '{ "tokenId": "a2ef69b0-07f1-11ef-e662-df316d04618c", "sessionId": "1e234ad6cd7843c15abd51905db26b935b3222a796cb378f5938272a8adb976a", "orgId": "138083", "userId": "4764534", "context": { "cloudClientUrl": "https://api.prod.us.five9.net/", "pwdExpiryDays": "269", "cloudTokenUrl": "https://api.prod.us.five9.net/", "farmId": "71" }, "metadata": { "freedomUrl": "https://app.five9.com", "dataCenters": [ { "name": "Santa Clara Data Center", "uiUrls": [ { "host": "app-scl.five9.com", "port": "443", "routeKey": "SCLUI2zOFh", "version": "13.0.247" } ], "apiUrls": [ { "host": "app-scl.five9.com", "port": "443", "routeKey": "SCLAPIPXB6", "version": "13.0.247" } ], "loginUrls": [ { "host": "app-scl.five9.com", "port": "443", "routeKey": "SCLLGNYoI4", "version": "13.0.244" } ], "active": true } ] } }';
//        MockHttpResponse f9LoginTestMockRes = new MockHttpResponse(200, 'OK',F9_LOGIN_TEST_BODY);
//
//        //StartSessionMock
//        MockHttpResponse f9StartSessionMockRes = new MockHttpResponse(204,'No Content','');
//
//        //CheckSessionMock
//        MockHttpResponse f9CheckSessionMockRes =  new MockHttpResponse(200,'OK','WORKING');
//
//        //RecordingViewMock
//        String F9_RECORDING_VIEW_TEST_BODY = '{"id":"e6fb995b-5cb6-4b35-8993-10eea1dd5806","records":[' +
//                        '{"id":"169874","campaignId":"20","created":1715302354617,"number":"4029472517","name":"","length":13700,"status":"WAITING_FOR_UPLOAD","callSessionId":"2F0B5FA878F9254E8AFFBC5402F5D536"},' +
//                        '{"id":"169878","campaignId":"20","created":1715302354617,"number":"4029472517","name":"","length":13700,"status":"WAITING_FOR_UPLOAD","callSessionId":"2F0B5FA878F9454E8AFFBC5402F5D536"},' +
//                        '{"id":"169877","campaignId":"20","created":1715302328685,"number":"4022766590","name":"","length":7060,"status":"WAITING_FOR_UPLOAD","callSessionId":"4FFFB2DC954A4FC1B074382F6D87CF09"}],"recordsTotal":4216,"hasMore":true,"currentPage":0}';
//        MockHttpResponse f9RecordingViewMockRes = new MockHttpResponse(200,'OK',F9_RECORDING_VIEW_TEST_BODY);
//
//        //GetRecordingMock
//        final Blob BLOB_BODY = Blob.toPdf('TEST BLOB');
//        MockHttpResponse f9GetRecordingMockRes = new MockHttpResponse(200,'OK',BLOB_BODY);
//
//        //sfPostRecordingMockRes
//        MockHttpResponse sfPostRecordingMockRes = new MockHttpResponse(204,'No Content', '');
//
//        Integer indexStart = System.Url.getOrgDomainUrl().toString().indexOf('=') + 1;
//        Integer indexEnd = System.Url.getOrgDomainUrl().toString().indexOf(']');
//
//        String orgUrl = System.Url.getOrgDomainUrl().toString().substring(indexStart,indexEnd);
//
//
//        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String,HttpCalloutMock>();
//        endpoint2TestResp.put(orgUrl+'/services/data/v60.0/voicecalls',sfPostVCTestMockRes);
//        endpoint2TestResp.put('https://app.five9.com/supsvcs/rs/svc/auth/login',f9LoginTestMockRes);
//        endpoint2TestResp.put('https://app-scl.five9.com/supsvcs/rs/svc/supervisors/4764534/session_start?force=true',f9StartSessionMockRes);
//        endpoint2TestResp.put('https://app-scl.five9.com/supsvcs/rs/svc/supervisors/4764534/login_state',f9CheckSessionMockRes);
//        endpoint2TestResp.put('https://app-scl.five9.com/supsvcs/rs/svc/supervisors/4764534/agents/4618727/recording_views',f9RecordingViewMockRes);
//        endpoint2TestResp.put('https://app-scl.five9.com/supsvcs/rs/svc/supervisors/4764534/agents/4618727/recording_views/e6fb995b-5cb6-4b35-8993-10eea1dd5806/next',f9RecordingViewMockRes);
//
//        endpoint2TestResp.put('https://app-scl.five9.com/strsvcs/rs/svc/agents/4618727/recordings/169877?download=true',f9GetRecordingMockRes);
//        endpoint2TestResp.put('https://bristolnebraska.my.salesforce.com/services/data/v60.0/voicecalls/0LQR7000000p27p/audio_upload',sfPostRecordingMockRes);
//
//        // Task:{Id=00TSu000001Ow5VMAS, WhoId=00QSu000004DuwYMAS, OwnerId=005Hs00000DCEpBIAX, CreatedDate=2024-05-15 00:57:09, five9AgentId__c=4618727, Five9DNIS__c=4022174741, Five9ANI__c=4022356146, Five9__Five9SessionId__c=627B8A49487546EAA1B6F92418A6F9C2, Five9TalkAndHoldTimeInSeconds__c=27, CallType=Outbound, Five9Agent__c=benr@bristolwindows.org}hehehehehasdlkgfhasd;lf haskl;dfhaskl;dfhAHAHAHHA PAIN
//
//        MultiRequestFive9Mocks multiRequestFive9Mocks = new MultiRequestFive9Mocks(endpoint2TestResp);
//
//        Test.setMock(HttpCalloutMock.class, multiRequestFive9Mocks);
//
//        Test.startTest();
//
//        // Fetch pre-inserted test task and job
//        Task newTask = [SELECT Id FROM Task WHERE Five9__Five9SessionId__c = '627B8A49487546EAA1B6F92418A6F9C2' LIMIT 1];
//
//        Five9API.TaskToVoiceCall(newTask.Id);
//        Five9API.f9ECIChain f9chain = new Five9API.f9ECIChain(newTask.Id);
//        Test.stopTest();
//
//        // Validate the job was created correctly
//        Id jobId = [SELECT Id FROM AudioProcessingJob__c WHERE TaskId__c = :newTask.Id LIMIT 1].Id;
//
//
//        System.assertNotEquals(null, jobId, 'JobId should not be null');
//        System.assertNotEquals(null, jobId, 'JobId should not be null');
//
//        //delete newTask;
//    }
}