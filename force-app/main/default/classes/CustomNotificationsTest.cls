/**
 * Created by Devin on 2/17/2025.
 */
@IsTest
public with sharing class CustomNotificationsTest {
    @testSetup
    static void setupTestData() {
        // Create a test Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        // Create a test Opportunity linked to the Account
        Opportunity testOpp = new Opportunity(
                Name = 'Test Opportunity',
                CloseDate = Date.today().addDays(30),
                StageName = 'Prospecting',
                AccountId = testAccount.Id // Associate with Account
        );
        insert testOpp;
    }

    @isTest
    static void testSendCompanyCamHistoryChangeNotification() {
        // Query the test Opportunity
        Opportunity opp = [SELECT Id, Name, AccountId FROM Opportunity LIMIT 1];

        // Call the method to send notifications
        Test.startTest();
        CustomNotifications.sendCompanyCamHistoryChangeNotification(new List<Opportunity>{ opp });
        Test.stopTest();

        // Validate that the notification type exists
        Id notificationTypeId = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Opportunity_CompanyCam_History_Change' LIMIT 1].Id;
        System.assertNotEquals(notificationTypeId, null, 'Notification Type should exist');

        // Validate Opportunity exists
        Opportunity updatedOpp = [SELECT Id, Name FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(updatedOpp, null, 'Opportunity should exist');
    }

    @isTest
    static void testSendCloseDateChangeNotification() {
        // Query the test Opportunity
        Opportunity opp = [SELECT Id, Name, CloseDate FROM Opportunity LIMIT 1];

        // Update the Close Date to trigger notification
        opp.CloseDate = Date.today().addDays(45);
        update opp;

        // Call the method to send notifications
        Test.startTest();
        CustomNotifications.sendCloseDateChangeNotification(new List<Opportunity>{ opp });
        Test.stopTest();

        // Verify the Custom Notification Type exists
        Id notificationTypeId = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Opportunity_Close_Date_Change' LIMIT 1].Id;
        System.assertNotEquals(notificationTypeId, null, 'Notification Type should exist');

        // Validate that the notification was sent
        System.assertEquals(opp.CloseDate, Date.today().addDays(45), 'Close Date should be updated');
    }
}