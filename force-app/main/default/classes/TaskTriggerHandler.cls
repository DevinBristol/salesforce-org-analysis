/**
 * Created by noahr on 5/6/2024.
 */
public with sharing class TaskTriggerHandler extends TriggerHandler {
    public override void afterInsert() {
        Map<Id,Task> Five9Tasks = new Map<Id,Task>();
        List<AudioProcessingJob__c> queueRecords = new List<AudioProcessingJob__c>();
        for (Task t : (List<Task>) Trigger.new) {
            if (String.isNotBlank(t.Five9__Five9SessionId__c)) {
                queueRecords.add(new AudioProcessingJob__c(
                        TaskId__c = t.Id,
                        Status__c = 'Queued'   // ✅ Changed from 'Pending' to 'Queued'
                ));
                Five9Tasks.put(t.Id,t);
            }
        }
        if (!queueRecords.isEmpty()) {
            insert queueRecords;
            if (!AudioJobManager.isJobRunning()) {
                AudioJobManager.startNextJob();
            }
        }
        DispoHandler.HandleDispos(Five9Tasks);
    }
    public override void beforeInsert(){
        for(Task t :(List<Task>) Trigger.new){
            if(String.isNotBlank(t.Five9__Five9SessionId__c)){
//                NamingUtility.formatTaskSubject(t);
                DispoHandler.NormalizeDispos(t);
            }
        }
    }
}