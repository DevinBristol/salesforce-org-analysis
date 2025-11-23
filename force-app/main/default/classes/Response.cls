/**
 * Created by Devin on 5/7/2024.
 */

global virtual class Response {
    static final String DEFAULT_EXTRA_STRING = 'Nothing Passed';
    //Response Constructors
    public Response(HttpResponse res, String CallName, String extraString) {
        this.statusCode = res.getStatusCode();
        if(CallName == 'f9GetRecording'){
            this.bodyBlob = res.getBodyAsBlob();}
        else{
            this.body = res.getBody();
        }
        System.debug('Res ::: ' + res );
        System.debug('ResBody ::: ' + res.getBody() );
        System.debug('ResBodyBlob ::: ' + res.getBodyAsBlob());

        switch on CallName{
            when 'sfPostVC'{
                this.uploadUrl = JsonUtility.ParseByToken(this.body,'uploadUrl');
            }
            when 'f9Login'{
                this.f9tokenId = JsonUtility.ParseByToken(this.body,'tokenId');
                this.f9sessionId = JsonUtility.ParseByToken(this.body, 'sessionId');
                this.f9farmId = JsonUtility.ParseByToken(this.body,'farmId');
            }
            when 'f9RecordingView'{
                Five9Response.f9RecordingView f9RecordingView = Five9Response.parsef9RecordingView(this.body);
                System.debug('f9RecordingView ::: ' + f9RecordingView);
                System.debug(f9RecordingView);
                System.debug(f9RecordingView.hasMore);
                for(Five9Response.call call : f9RecordingView.records){
                    if(call.callSessionId == extraString){
                        this.f9callRecordingId = call.id;
                    }
                }
                this.f9RecordingViewId = f9RecordingView.id;
                this.hasMore = Boolean.valueOf(f9RecordingView.hasMore);
                //extraString is able to take sessionId for parsing purposes
//                this.f9callRecordingId = JsonUtility.ParseByTokenUntil(this.body,'id', extraString);
//                this.f9RecordingViewId = JsonUtility.ParseByTokenUntil(this.body,'id', extraString);
            }
            when 'f9GetNotice'{
                //extraString is able to take sessionId for parsing purposes
                this.f9NoticeId = JsonUtility.ParseByTokenUntil(this.body,'id', extraString);
            }
            when 'f9RecordingViewNext'{
                //extraString is able to take sessionId for parsing purposes
                Five9Response.f9RecordingView f9RecordingViewNext = Five9Response.parsef9RecordingView(this.body);
                System.debug(f9RecordingViewNext);
                System.debug(f9RecordingViewNext.hasMore);
                for(Five9Response.call call : f9RecordingViewNext.records){
                    System.debug(call);
                    if(call.callSessionId == extraString){
                        this.f9callRecordingId = call.id;
                    }
                }
                this.f9RecordingViewId = f9RecordingViewNext.id;
                this.hasMore = Boolean.valueOf(f9RecordingViewNext.hasMore);
            }
        }
    }

    public Response(HttpResponse res, String CallName) {
        this(res,CallName,DEFAULT_EXTRA_STRING);
    }

    // END Response constructors
    // sometimes an api key is supplied as part of the URL ...
    // because it's not always necessary, we make it a public member of the class
    public String body { get; set; }
    public Integer statusCode { get; set; }
    public String status {get; set; }
    //Switch Variables
    public String uploadUrl { get; set; }
    public String f9tokenId { get; set; }
    public String f9sessionId { get; set; }
    public String f9farmId { get; set; }
    public String f9NoticeId {get;set;}
    public String f9callRecordingId { get; set;}
    public String f9RecordingViewId { get; private set; }
    public Blob bodyBlob { get; set;}
    public Boolean hasMore {get; set;}
}