/**
 * Created by noahr on 5/6/2024.
 */

global class Five9Response{

    // Request Handlers

    public static Response sfPostVC(String tasks){
        String req = new Five9Helper().sfPostVC(tasks);
        HttpResponse res = HttpCallout.process(req);
        Response response = new Response(res,'sfPostVC');

        System.debug(res.getStatusCode());
        System.debug(res.getBody());

        return response;
    }
    public static Response f9Login(){
        String req = new Five9Helper().f9Login();
        HttpResponse res = HttpCallout.process(req,false);
        Response response = new Response (res, 'f9Login');
        return response;
    }
    public static Response f9startSession(String f9SessionId, String f9tokenId, String f9farmId){
        String req = new Five9Helper().f9StartSession(f9SessionId,f9tokenId,f9farmId);
        HttpResponse res = HttpCallout.process(req,false);
        Response response = new Response (res, 'f9startSession');
        return response;
    }
    // figure out how to start here everytime w/ a list to run...only login when this res !="WORKING"
    public static Response f9CheckSession(String f9SessionId, String f9tokenId, String f9farmId) {
        String req = new Five9Helper().f9CheckSession(f9SessionId,f9tokenId,f9farmId);
        HttpResponse res = HttpCallout.process(req,false);
        Response response = new Response (res, 'f9CheckSession');
        return response;
    }
    public static Response f9GetNotice(String f9SessionId, String f9tokenId, String f9farmId){
        String req = new Five9Helper().f9GetNotice(f9SessionId,f9tokenId,f9farmId);
        HttpResponse res = HttpCallout.process(req,false);
        Response response = new Response (res,'f9GetNotice');
        return response;
    }
    public static Response f9AcceptNotice(String f9SessionId, String f9tokenId, String f9farmId,String f9noticeId){
        String req = new Five9Helper().f9AcceptNotice(f9SessionId,f9tokenId,f9farmId,f9noticeId);
        HttpResponse res = HttpCallout.process(req,false);
        Response response = new Response (res,'f9AcceptNotice');
        return response;
    }
    public static Response f9RecordingView(String f9SessionId, String f9tokenId, String f9farmId, String f9agentId,String f9callSessionId){
        String req = new Five9Helper().f9RecordingView(f9SessionId,f9tokenId,f9farmId,f9agentId);
        HttpResponse res = HttpCallout.process(req,false);
        Response response = new Response (res, 'f9RecordingView',f9callSessionId);
        return response;
    }
    public static Response f9RecordingViewNext(String f9SessionId, String f9tokenId, String f9farmId, String f9agentId,String f9callSessionId,String RecordingViewId){
        String req = new Five9Helper().f9RecordingViewNext(f9SessionId,f9tokenId,f9farmId,f9agentId,RecordingViewId);
        HttpResponse res = HttpCallout.process(req,false);
        Response response = new Response (res, 'f9RecordingViewNext',f9callSessionId);
        return response;
    }
    public static Response f9GetRecording(String f9SessionId, String f9tokenId, String f9farmId, String f9agentId,String f9callRecordingId){
        String req = new Five9Helper().f9GetRecording(f9SessionId,f9tokenId,f9farmId,f9agentId,f9callRecordingId);
        HttpResponse res = HttpCallout.process(req,false);
        Response response = new Response (res,'f9GetRecording');
        return response;
    }
    public static Response sfPostRecording(String uploadUrl,Blob audioFile,String boundary){
        String req = new Five9Helper().sfPostRecording(uploadUrl,audioFile,boundary);
        HttpResponse res = HttpCallout.process(req,true,audioFile);
        Response response = new Response(res, 'sfPostRecording');
        return response;
    }

    public class f9RecordingView{
        public String id;	//4739a8cd-b5f6-4f11-9888-e1f6009499fa
        public List<call> records;
        public Integer recordsTotal;	//2811
        public Boolean hasMore;
        public Integer currentPage;	//0

    }
    public class call {
        public String id;	//367409
        public String campaignId;	//20
        public Long created;	//1739923860115
        public String name;	//
        public Integer length;	//331160
        public String status;	//WAITING_FOR_UPLOAD
        public String callSessionId;	//E4A381470B794A46B32B43B38982467B
    }
    public static f9RecordingView parsef9RecordingView(String json){
        System.debug(json);
        return (f9RecordingView) System.JSON.deserialize(json, f9RecordingView.class);
    }
}