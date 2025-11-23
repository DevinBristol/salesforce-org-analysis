/**
 * Created by Devin on 2/18/2025.
 */

public with sharing class AudioJobManager {

    // ✅ Start Next Available Job
    public static void startNextJob() {
        List<AudioProcessingJob__c> jobs = [SELECT Id, TaskId__c
        FROM AudioProcessingJob__c
        WHERE Status__c = 'Queued'
        ORDER BY CreatedDate ASC
        LIMIT 1];

        if (jobs.isEmpty()) {
            System.debug('No queued jobs found.');
            return;
        }
        // ✅ Fire the next job
        if(!isJobRunning()){
            System.debug('Starting job: ' + jobs[0].Id);
            System.enqueueJob(new Five9API(jobs[0].TaskId__c));
        }
    }

    // ✅ Update Job Status (Completed/Failed)
    public static void updateJobStatus(Id jobId, String status, String errorMessage) {
        AudioProcessingJob__c job = [SELECT Id FROM AudioProcessingJob__c WHERE Id = :jobId LIMIT 1];

        job.Status__c = status;
        if (status == 'Failed') {
            job.LastError__c = errorMessage;
        }

        update job;
    }

    // ✅ Check if a job is already running using AsyncApexJob
    public static Boolean isJobRunning() {
        Integer runningJobs = [SELECT COUNT() FROM AsyncApexJob
        WHERE JobType = 'Queueable'
        AND Status IN ('Processing', 'Preparing') AND ApexClass.Name = 'Five9API'];

        System.debug('Running jobs count: ' + runningJobs);
        return runningJobs > 1;
    }
}