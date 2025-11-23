/**
 * Created by noahr on 5/6/2024.
 */

public with sharing class Five9Helper {

    public String sfPostVC(String tasks) {
        //list of task objects from taskTrigger.triggernew()

        String reqBodyJSON = tasks;
        String sessionIdpar1 = UserInfo.getOrganizationId().substring(0,15);
        String sessionIdpar2 = UserInfo.getSessionId().substring(15);

        Map<String,String> headers = new Map<String,String>{'Content-Type'=>'application/json','Authorization'=>'Bearer '+sessionIdpar1+''+sessionIdpar2};

        Integer indexStart = System.Url.getOrgDomainUrl().toString().indexOf('=') + 1;
        Integer indexEnd = System.Url.getOrgDomainUrl().toString().indexOf(']');

        String orgUrl = System.Url.getOrgDomainUrl().toString().substring(indexStart,indexEnd);
        String endpoint = orgUrl+'/services/data/v63.0/voicecalls';
        String method = 'POST';

        Callout c = new Callout(reqBodyJSON,endpoint,method,headers);
        System.debug(c);
        String cString = JSON.serialize(c);
        return cString;
    }

    //five9login
    public String f9Login(){
        String endpoint = 'https://app-scl.five9.com/supsvcs/rs/svc/auth/login';
        String method = 'POST';
        String reqBodyJSON = '{"passwordCredentials":{"username":"syncerfn@gmail.com","password":"SyncerPass1!"},"policy":"ForceIn"}';
        Map<String,String> headers = new Map<String,String>{'Content-Type'=>'application/json'};
        Callout c = new Callout(reqBodyJSON,endpoint,method,headers);
        String cString = JSON.serialize(c);
        System.debug('F9Login cString ::: ' + cString);
        return cString;
    }

    public String f9StartSession(String f9sessionId,String f9tokenId,String f9farmId) {
        // Map<String, String> Headers = new Map<String, String>;
        String endpoint = 'https://app-scl.five9.com/supsvcs/rs/svc/supervisors/4764534/session_start?force=true';
        String method = 'PUT';
        String reqBodyJSON = '{"stationId":null,"stationType":"EMPTY"}';
        Map<String,String> headers = new Map<String,String>{'Content-Type'=>'application/json','Session-Id'=>f9sessionId,'Authorization'=>f9tokenId,'farmId'=>f9farmId};
        Callout c = new Callout(reqBodyJSON, endpoint, method,headers);
        String cString = JSON.serialize(c);
        System.debug('F9StartSession cString ::: ' + cString);
        return cString;
    }

    public String f9CheckSession(String f9sessionId, String f9tokenId, String f9farmId){
        String endpoint = 'https://app-scl.five9.com/supsvcs/rs/svc/supervisors/4764534/login_state';
        String method = 'GET';
        String reqBodyJSON = '';
        Map<String,String> headers = new Map<String,String>{'Content-Type'=>'application/json','Session-Id'=>f9sessionId,'Authorization'=>f9tokenId,'farmId'=>f9farmId};
        Callout c = new Callout(reqBodyJSON, endpoint, method,headers);
        String cString = JSON.serialize(c);
        return cString;
    }
    public String f9GetNotice(String f9sessionId,String f9tokenId,String f9farmId){
        String endpoint='https://app-scl.five9.com/supsvcs/rs/svc/supervisors/4764534/maintenance_notices';
        String method='GET';
        String reqBodyJSON = '';
        Map<String,String> headers = new Map<String,String>{'Content-Type'=>'application/json','Session-Id'=>f9sessionId,'Authorization'=>f9tokenId,'farmId'=>f9farmId};
        Callout c = new Callout(reqBodyJSON, endpoint, method,headers);
        String cString = JSON.serialize(c);
        return cString;
    }
    public String f9AcceptNotice(String f9sessionId,String f9tokenId,String f9farmId,String noticeId){
        String endpoint='https://app-scl.five9.com/supsvcs/rs/svc/supervisors/4764534/maintenance_notices/'+noticeId+'/accept';
        String method='PUT';
        String reqBodyJSON = '';
        Map<String,String> headers = new Map<String,String>{'Content-Type'=>'application/json','Session-Id'=>f9sessionId,'Authorization'=>f9tokenId,'farmId'=>f9farmId};
        Callout c = new Callout(reqBodyJSON, endpoint, method,headers);
        String cString = JSON.serialize(c);
        return cString;
    }
    public String f9RecordingView(String f9sessionId, String f9tokenId, String f9farmId, String f9agentId) {
        String endpoint = 'https://app-scl.five9.com/supsvcs/rs/svc/supervisors/4764534/agents/'+f9agentId+'/recording_views';
        String method = 'POST';
        String reqBodyJSON = '{"limit":300,"sortField":"CREATED","ascending":false,"showUploaded":true}';
        Map<String,String> headers = new Map<String,String>{'Content-Type'=>'application/json','Session-Id'=>f9sessionId,'Authorization'=>f9tokenId,'farmId'=>f9farmId};
        Callout c = new Callout(reqBodyJSON, endpoint, method,headers);
        String cString = JSON.serialize(c);
        return cString;
    }
    public String f9RecordingViewNext(String f9sessionId, String f9tokenId, String f9farmId, String f9agentId,String RecordingViewId) {
        String endpoint = 'https://app-scl.five9.com/supsvcs/rs/svc/supervisors/4764534/agents/'+f9agentId+'/recording_views/'+ RecordingViewId+'/next';
        String method = 'PUT';
        String reqBodyJSON = '{"limit":300,"sortField":"CREATED","ascending":false,"showUploaded":true}';
        Map<String,String> headers = new Map<String,String>{'Content-Type'=>'application/json','Session-Id'=>f9sessionId,'Authorization'=>f9tokenId,'farmId'=>f9farmId};
        Callout c = new Callout(reqBodyJSON, endpoint, method,headers);
        String cString = JSON.serialize(c);
        return cString;
    }

    public String f9GetRecording(String f9sessionId, String f9tokenId, String f9farmId, String f9AgentId, String recordingId){
        String endpoint = 'https://app-scl.five9.com/strsvcs/rs/svc/agents/'+f9AgentId+'/recordings/'+recordingId+'?download=true';
        String method = 'GET';
        String reqBodyJSON = '';
        Map<String,String> headers = new Map<String,String>{'Content-Type'=>'application/json','Session-Id'=>f9sessionId,'Authorization'=>f9tokenId,'farmId'=>f9farmId};
        Callout c = new Callout(reqBodyJSON, endpoint, method, headers);
        String cString = JSON.serialize(c);
        return cString;
    }

    public String sfPostRecording(String uploadUrl, Blob audioFile, String boundary){
        String endpoint = uploadUrl;
        String method = 'POST';
        String sessionIdPar1 = UserInfo.getOrganizationId().substring(0,15);
        String sessionIdPar2 = UserInfo.getSessionId().substring(15);
        Map<String,String> headers = new Map<String,String>{
                'Authorization' => 'Bearer '+sessionIdPar1+''+sessionIdPar2,
                'Content-Type' => 'multipart/form-data;boundary='+boundary};
        Callout c = new Callout(audioFile, endpoint, method, headers);
        String cString = JSON.serialize(c);
        return cString;
    }

//    public String vcSetBody(List<Task> tasks){
//
//        Map<String, Object> requestBodyObj = new Map<String, Object>();  //  {  Calls:{ [{call0},{call1},{call2}. . .{call(n)}] }  };
//        final String CALL_COACHING_PROVIDER_ID = '0hnSu00000000WHIAY';
//        List<Map<String, Object>> Calls = new List<Map<String, Object>>();
//
//        for (Task t : tasks) {
//            Map<String, Object> call = new Map<String, Object>{
//                    'mediaProviderId' => CALL_COACHING_PROVIDER_ID,
//                    'userId' => t.OwnerId,
//                    'toPhoneNumber' => t.Five9DNIS__c,
//                    'fromPhoneNumber' => t.Five9ANI__c,
//                    'endDateTime' => t.CreatedDate.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
//                    'startDateTime' => t.CreatedDate.addSeconds(-t.Five9TalkAndHoldTimeInSeconds__c.intValue()).format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
//                    'callType' => t.Five9__Five9TaskType__c,
//                    'recordingDuration' => t.Five9TalkAndHoldTimeInSeconds__c,
//                    'externalId' => t.Five9__Five9SessionId__c,
//                    'recordingFormat' => 'mp3'
//            };
//            Calls.add(call);
//        }
//        requestBodyObj.put('calls', Calls);
//        String jsonReqBody = JSON.serialize(requestBodyObj);
//        return jsonReqBody;
//    }
}