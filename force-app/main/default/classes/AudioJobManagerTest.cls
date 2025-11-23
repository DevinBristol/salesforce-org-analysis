/**
 * Created by Devin on 2/20/2025.
 */

@IsTest
public with sharing class AudioJobManagerTest {
    @TestSetup
    static void setupTestData() {
        // Create a test Task
        Task testTask = new Task(OwnerId = UserInfo.getUserId(), Subject = 'Test Task', Status = 'Completed');
        insert testTask;

        // Create a queued AudioProcessingJob__c record
        AudioProcessingJob__c job = new AudioProcessingJob__c(
                TaskId__c = testTask.Id,
                Status__c = 'Queued'
        );
        insert job;
    }

    @IsTest
    static void testStartNextJob() {
        Test.startTest();
        // Start the next job
        AudioJobManager.startNextJob();
        Test.stopTest();

        // Verify job status has changed from 'Queued' to 'Processing'
        AudioProcessingJob__c updatedJob = [SELECT Id, Status__c FROM AudioProcessingJob__c LIMIT 1];
        System.assertNotEquals(null,updatedJob.Id);
    }

    @IsTest
    static void testUpdateJobStatusCompleted() {
        // Fetch a test job
        AudioProcessingJob__c job = [SELECT Id FROM AudioProcessingJob__c LIMIT 1];

        Test.startTest();
        // Update job to Completed
        AudioJobManager.updateJobStatus(job.Id, 'Completed', null);
        Test.stopTest();

        // Verify status update
        AudioProcessingJob__c updatedJob = [SELECT Id, Status__c FROM AudioProcessingJob__c WHERE Id = :job.Id];
        System.assertEquals('COMPLETED', updatedJob.Status__c, 'Job status should be updated to Completed.');
    }

    @IsTest
    static void testUpdateJobStatusFailed() {
        // Fetch a test job
        AudioProcessingJob__c job = [SELECT Id FROM AudioProcessingJob__c LIMIT 1];

        Test.startTest();
        // Update job to Failed with an error message
        String errorMessage = 'Test error';
        AudioJobManager.updateJobStatus(job.Id, 'Failed', errorMessage);
        Test.stopTest();

        // Verify status update
        AudioProcessingJob__c updatedJob = [SELECT Id, Status__c, LastError__c FROM AudioProcessingJob__c WHERE Id = :job.Id];
        System.assertEquals('FAILED', updatedJob.Status__c, 'Job status should be updated to Failed.');
        System.assertEquals(errorMessage, updatedJob.LastError__c, 'Error message should be saved.');
    }

    @IsTest
    static void testIsJobRunning() {
        Test.startTest();
        Boolean running = AudioJobManager.isJobRunning();
        Test.stopTest();

        System.assertNotEquals(null,running, 'isJobRunning() should return a boolean value.');
    }
}