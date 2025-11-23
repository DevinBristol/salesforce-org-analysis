/**
 * Created by noahr on 5/6/2024.
 * TODO Eliminate extra class "TaskToVoiceCall" ?
 * TODO TestClass inside of FIVE9APITEST for JsonCreation (Needs an expected JsonBody)
 * TODO Finish BinaryFile testClass
 * TODO Can we change OrgSettings Values right before deployment? META DATA BETTER? AHHHHHH PAIN!
 */

global with sharing class Five9API implements Queueable, Database.AllowsCallouts{
    private Id taskId;

    public Five9API(Id taskId) {
        this.taskId = taskId;
    }

    public void execute(QueueableContext context) {
        try {
            // ✅ Process Task
            TaskToVoiceCall(taskId);
            AudioJobManager.updateJobStatus(getJobId(taskId), 'Completed', null);
        } catch (Exception e) {
            System.debug('Job failed: ' + e.getMessage());
            AudioJobManager.updateJobStatus(getJobId(taskId), 'Failed', e.getMessage());
        }

        // ✅ Fire the next job in queue
        AudioJobManager.startNextJob();
    }

    public static void TaskToVoiceCall(Id taskId) {
        f9ECIChain ECIChain = new f9ECIChain(taskId);
    }

    // ✅ Find Job ID for Task
    public static Id getJobId(Id taskId) {
        AudioProcessingJob__c job = [SELECT Id FROM AudioProcessingJob__c WHERE TaskId__c = :taskId LIMIT 1];
        return job.Id;
    }

    public class f9ECIChain {
        public f9ECIChain(Id taskId) {
            System.debug(taskId);
            Task task = [SELECT Id, WhoId, OwnerId,CreatedDate,Five9DNIS__c, Five9ANI__c, Five9__Five9SessionId__c, Five9TalkAndHoldTimeInSeconds__c, CallType, Five9Agent__c FROM Task WHERE Id = :taskId];
            String AgentId = [SELECT Id,F9AgentId__c FROM User WHERE Id = :task.OwnerId LIMIT 1].F9AgentId__c;
            String CallRecordingId;
            System.debug(AgentId);
            String boundary = '----------------------------741e90d31eff';

            sfPostVC sfPostVCCall = new sfPostVC(createVoiceCallJsonInput(task));
            System.debug(sfPostVCCall.uploadUrl);

            if(task.Five9TalkAndHoldTimeInSeconds__c > 2.0) { f9Login f9LoginCall = new f9Login();
                f9StartSession f9StartSessionCall = new f9StartSession(f9LoginCall.f9sessionId, f9LoginCall.f9tokenId, f9LoginCall.f9farmId);
                System.debug(f9StartSessionCall.statusCode);
                f9CheckSession f9CheckSessionCall = new f9CheckSession(f9LoginCall.f9sessionId, f9LoginCall.f9tokenId, f9LoginCall.f9farmId);
                System.debug(f9CheckSessionCall.statusCode);
                System.debug(f9CheckSessionCall.body);
                System.debug(f9CheckSessionCall);


                if(f9CheckSessionCall.toString().contains('ACCEPT')){
                    f9GetNotice f9GetNoticeCall= new f9GetNotice(f9LoginCall.f9sessionId,f9LoginCall.f9tokenId,f9LoginCall.f9farmId);
                    System.debug(f9GetNoticeCall.statusCode);
                    f9AcceptNotice f9AcceptNoticeCall= new f9AcceptNotice(f9LoginCall.f9sessionId,f9LoginCall.f9tokenId,f9LoginCall.f9farmId,f9GetNoticeCall.noticeId);
                    System.debug(f9AcceptNoticeCall.statusCode);
                }

                f9RecordingView f9RecordingViewCall = new f9RecordingView(f9LoginCall.f9sessionId, f9LoginCall.f9tokenId, f9LoginCall.f9farmId,AgentId, task.Five9__Five9SessionId__c);
                System.debug(f9RecordingViewCall.f9callRecordingId);
                System.debug(f9RecordingViewCall.hasMore);
                System.debug(f9RecordingViewCall.f9RecordingViewId);

                if(f9RecordingViewCall.f9callRecordingId == null){
                    f9RecordingViewNext f9RecordingViewNext;
                    if(f9RecordingViewCall.hasMore){
                        do{
                            f9RecordingViewNext = new f9RecordingViewNext(f9LoginCall.f9sessionId, f9LoginCall.f9tokenId, f9LoginCall.f9farmId,AgentId, task.Five9__Five9SessionId__c,f9RecordingViewCall.f9RecordingViewId);
                            System.debug(f9RecordingViewNext.statusCode);
                            if(f9RecordingViewNext.f9callRecordingId != null){
                                CallRecordingId = f9RecordingViewNext.f9callRecordingId;
                            }
                        } while (f9RecordingViewNext.hasMore && CallRecordingId == null);
                    }
                } else {
                    CallRecordingId = f9RecordingViewCall.f9callRecordingId;
                }
                if(CallRecordingId != null) {
                    f9GetRecording f9GetRecordingCall = new f9GetRecording(f9LoginCall.f9sessionId, f9LoginCall.f9tokenId, f9LoginCall.f9farmId, AgentId, CallRecordingId);
                    BinaryFile binaryFile = new BinaryFile(f9GetRecordingCall.bodyBlob, task.Five9__Five9SessionId__c + '.mp3', boundary, false);
                    sfPostRecording sfPostRecordingCall = new sfPostRecording(sfPostVCCall.uploadUrl, binaryFile.fileAsBlob, boundary);
                    System.debug(sfPostRecordingCall.status);
                    System.debug(sfPostRecordingCall.statusCode);
                }
            }
        }
    }

    public static String createVoiceCallJsonInput(Task task) {
        Datetime EndTime = task.CreatedDate;
        Integer minusSeconds = (Integer) task.Five9TalkAndHoldTimeInSeconds__c;
        Datetime startTime = EndTime.addSeconds(-minusSeconds);
        String StartDate = startTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        String EndDate = EndTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');

        String JsonInput = '{"calls":[{"mediaProviderId":"'+OrgSettings.getFive9MediaProviderId()+'","userId":"' + task.OwnerId + '","toPhoneNumber":"' + task.Five9DNIS__c + '","fromPhoneNumber": "' + task.Five9ANI__c + '","startDateTime": "' + StartDate + '","endDateTime":"' + EndDate + '","callType": "' + task.CallType + '","recordingDuration":"' + task.Five9TalkAndHoldTimeInSeconds__c + '","externalId": "' + task.Five9__Five9SessionId__c + '","recordingFormat": "mp3","activityId":"' + task.Id + '","recordId":"' + task.WhoId + '"}]}';
        System.debug(JsonInput);
        return JsonInput;
    }

//    /CONSTRUCTORS FOR POSTS

    global class sfPostVC {
        public sfPostVC(String taskId) {
            Response response = Five9Response.sfPostVC(taskId);
            this.statusCode = response.statusCode;
            this.body = response.body;
            this.status = response.status;
            this.uploadUrl = response.uploadUrl;
        }
        public String body { get; private set; }
        public Integer statusCode { get; private set; }
        public String uploadUrl { get; private set; }
        public String status { get; private set; }
    }
    public class f9Login {
        public f9Login() {
            Response response = Five9Response.f9Login();
            this.statusCode = response.statusCode;
            this.body = response.body;
            this.status = response.status;
            this.f9tokenId = response.f9tokenId;
            this.f9farmId = response.f9farmId;
            this.f9sessionId = response.f9sessionId;
        }
        public String f9sessionId { get; private set; }
        public String f9farmId { get; private set; }
        public String f9tokenId { get; private set; }
        public String body { get; private set; }
        public Integer statusCode { get; private set; }
        public String status { get; private set; }
    }
    public class f9StartSession {
        public f9StartSession(String f9sessionId, String f9tokenId, String f9farmId) {
            Response response = Five9Response.f9startSession(f9sessionId, f9tokenId, f9farmId);
            this.statusCode = response.statusCode;
            this.body = response.body;
            this.status = response.status;
        }
        public String body { get; private set; }
        public Integer statusCode { get; private set; }
        public String status { get; private set; }
    }
    public class f9CheckSession {
        public f9CheckSession(String f9sessionId, String f9tokenId, String f9farmId) {
            Response response = Five9Response.f9CheckSession(f9sessionId, f9tokenId, f9farmId);
            this.statusCode = response.statusCode;
            this.body = response.body;
            this.status = response.status;
        }
        public String body { get; private set; }
        public Integer statusCode { get; private set; }
        public String status { get; private set; }
    }
    public class f9GetNotice{
        public f9GetNotice(String f9sessionId, String f9tokenId, String f9farmId){
            Response response = Five9Response.f9GetNotice(f9sessionId,f9tokenId,f9farmId);
            this.statusCode = response.statusCode;
            this.body = response.body;
            this.status = response.status;
            this.noticeId = response.f9NoticeId;
        }
        public String body { get; private set; }
        public Integer statusCode { get; private set; }
        public String status { get; private set; }
        public String noticeId { get; private set;}
    }
    public class f9AcceptNotice{
        public f9AcceptNotice(String f9sessionId, String f9tokenId, String f9farmId,String f9noticeId){
            Response response=Five9Response.f9AcceptNotice(f9sessionId,f9tokenId,f9farmId,f9noticeId);
            this.statusCode=response.statusCode;
            this.body=response.body;
            this.status=response.status;
        }
        public String body { get; private set; }
        public Integer statusCode { get; private set; }
        public String status { get; private set; }
    }
    public class f9RecordingViewNext {
        public f9RecordingViewNext(String f9sessionId, String f9tokenId, String f9farmId, String f9agentId, String f9callSessionId,String RecordingViewId) {
            Response response = Five9Response.f9RecordingViewNext(f9sessionId, f9tokenId, f9farmId, f9agentId, f9callSessionId,RecordingViewId);
            this.statusCode = response.statusCode;
            this.body = response.body;
            this.status = response.status;
            this.f9callRecordingId = response.f9callRecordingId;
            this.f9RecordingViewId = response.f9RecordingViewId;
            this.hasMore = response.hasMore;
        }
        public String body { get; private set; }
        public Integer statusCode { get; private set; }
        public String status { get; private set; }
        public String f9callRecordingId { get; private set; }
        public String f9RecordingViewId { get; private set; }
        public Boolean hasMore { get; private set; }
    }

    public class f9RecordingView {
        public f9RecordingView(String f9sessionId, String f9tokenId, String f9farmId, String f9agentId, String f9callSessionId) {
            Response response = Five9Response.f9RecordingView(f9sessionId, f9tokenId, f9farmId, f9agentId, f9callSessionId);
            this.statusCode = response.statusCode;
            this.body = response.body;
            this.status = response.status;
            this.f9callRecordingId = response.f9callRecordingId;
            this.f9RecordingViewId = response.f9RecordingViewId;
            this.hasMore = response.hasMore;
        }
        public String body { get; private set; }
        public Integer statusCode { get; private set; }
        public String status { get; private set; }
        public String f9callRecordingId { get; private set; }
        public String f9RecordingViewId { get; private set; }
        public Boolean hasMore { get; private set; }
    }


    public class f9GetRecording {
        public f9GetRecording(String f9sessionId, String f9tokenId, String f9farmId, String f9agentId, String f9callRecordingId) {
            Response response = Five9Response.f9GetRecording(f9sessionId, f9tokenId, f9farmId, f9agentId, f9callRecordingId);
            this.statusCode = response.statusCode;
            this.body = response.body;
            this.status = response.status;
            this.bodyBlob = response.bodyBlob;
        }
        public String body { get; private set; }
        public Integer statusCode { get; private set; }
        public String status { get; private set; }
        public Blob bodyBlob { get; private set; }
    }
    public class sfPostRecording {
        public sfPostRecording(String uploadUrl,Blob audioFile,String boundary) {
            Response response = Five9Response.sfPostRecording(uploadUrl,audioFile,boundary);
            this.statusCode = response.statusCode;
            this.body = response.body;
            this.status = response.status;
            this.bodyBlob = response.bodyBlob;
        }
        public String body { get; private set; }
        public Integer statusCode { get; private set; }
        public String status { get; private set; }
        public Blob bodyBlob { get; private set; }
    }

}