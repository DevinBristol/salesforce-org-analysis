/**
 * Created by Devin on 2/19/2025.
 */

global class AudioScavengeBatch implements Database.Batchable<SObject>,Database.Stateful, Database.AllowsCallouts{
    public String queryString;
    public String qTail;
    public List<VoiceCall>delVCs=new List<VoiceCall>();
    public Set<Id>scopeTasks=new Set<Id>();
    public Map<Id,VoiceCall>taskVCmap=new Map<Id,VoiceCall>();
    public Map<String,Object> bindMap=new Map<String,Object>();
    public AudioScavengeBatch(){
        this.qTail='\r'+'ORDER BY CreatedDate DESC,OwnerId DESC,Five9__Five9SessionId__c DESC';
        List<AudioProcessingJob__c> apjs=[SELECT Id,Voice_Call__c,TaskId__c,OwnerId FROM AudioProcessingJob__c WHERE Status__c='FAILED' AND CreatedDate>=LAST_N_DAYS:31];
        makeScope();
        this.queryString=
            'SELECT Id,TaskSubtype,Task_Type__c,Five9__Five9TaskType__c,Five9CallType__c,CallType,Five9MediaSubtype__c,' +
                    'Five9DistributionMode__c,Five9Campaign__c,ActivityDate,Subject,WhoId,CallDisposition,Five9__Five9SessionId__c,Five9InteractionDuration__c,OwnerId,Status, \n'+
                '   Five9DNIS__c,Five9ANI__c,Five9TalkAndHoldTimeInSeconds__c,Five9Queue__c,CallDurationInSeconds,CallObject,CreatedDate\n'+
                'FROM Task WHERE Id IN :scopeTasks \n'
            +qTail;
        System.debug('queryString = '+queryString);
        delete delVCs;
    }
    public void makeScope(){
        List<Task> allTasks=[SELECT Id,
        (SELECT Id,TranscribedLanguage FROM VoiceCallActivities)
        FROM Task WHERE CreatedDate>=LAST_N_DAYS:31  AND
        CallDisposition!=NULL AND CallDisposition!='No Answer'AND CallDisposition!='No-Answer'AND
        CallDisposition!='Answering Machine'AND CallDisposition!='Answering-Machine' AND
        Five9TalkAndHoldTimeInSeconds__c>9 AND Five9__Five9SessionId__c!=NULL];
        for(Task t : allTasks){
            // include tasks without a transcripted vc// exclude tasks with a transcripted vc// delete all non transcripted vcs & dupe transcripted vcs
            if(t.VoiceCallActivities.size()==0){
                this.scopeTasks.add(t.Id);
            } else { for(VoiceCall vc : t.VoiceCallActivities){ if(vc.TranscribedLanguage==null){ delVCs.add(vc);
                        System.debug('deleting(no transcript)...'+vc);
                    } else {
                        if(taskVCmap.get(t.Id)==null){taskVCmap.put(t.Id,vc); } else { delVCs.add(vc);
                            System.debug('deleting(transcripted dupe)...'+vc);
                        }
                    }
                }
                if(!taskVCmap.containsKey(t.Id)){ scopeTasks.add(t.Id); }
            }
        }
        System.debug('allTasks size='+allTasks.size());
        System.debug('scopeTasks (size='+scopeTasks.size()+')—>'+scopeTasks);
        System.debug('delVCs (size='+delVCs.size()+')—>'+delVCs);
        System.debug('taskVCmap (keys size='+taskVCmap.keySet().size()+', values size='+taskVCmap.values().size()+')—>\r'+taskVCmap);
        bindMap.put('scopeTasks',scopeTasks);
    }
    global Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('bindMap...'+this.bindMap);
        return Database.getQueryLocatorWithBinds(queryString,bindMap,AccessLevel.USER_MODE);
    }
    global void execute(Database.BatchableContext bc, List<Task> scope) {
        for(Task t : scope){ Five9API.f9ECIChain chain = new Five9API.f9ECIChain(t.Id); }
    }

    global void finish(Database.BatchableContext bc) {

    }
}