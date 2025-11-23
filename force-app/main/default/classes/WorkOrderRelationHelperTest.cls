/**
 * Created by Ben on 8/30/2024.
 */

@IsTest
public class WorkOrderRelationHelperTest {
    @TestSetup
    static void setupTestData() {

        Account testAccount = new Account(Name = 'Test Account',Stage__c = 'Active',Name_of_Lead_Source__c = 'TestCraaap');
        insert testAccount;
        Account qTestAccount = [SELECT Id, Name FROM Account WHERE Name_of_Lead_Source__c = 'TestCraaap' LIMIT 1];
        Contact testCont = new Contact(FirstName = 'Test',LastName = 'Account',MobilePhone = '3554441221',AccountId = qTestAccount.Id);
        insert testCont;
        Property__c testProperty = new Property__c(Address__Street__s = '123 Test Street',
                Address__City__s = 'Lincoln', Address__StateCode__s = 'NE',
                Address__CountryCode__s = 'US', Address__PostalCode__s = '68521',
                AccountId__c = qTestAccount.Id);
        insert testProperty;
        Property__c qTestProperty = [SELECT Id, Name,AccountId__c FROM Property__c WHERE AccountId__c = :qTestAccount.Id LIMIT 1];
        Account_Property_Relationship__c testAPR = new Account_Property_Relationship__c(
                Account__c = qTestAccount.Id, Property__c = qTestProperty.Id);
        insert testAPR;


        Opportunity testOpp = new Opportunity(AccountId = qTestAccount.Id, Opportunity_Property__c = qTestProperty.Id,
                StageName = 'Pending', CloseDate = System.today().addDays(1));
        insert testOpp;
        Opportunity qTestOppty = [SELECT Id, Name,AccountId FROM Opportunity WHERE AccountId = :qTestAccount.Id LIMIT 1];
        WorkOrder testWO = new WorkOrder(AccountId = qTestAccount.Id, Opportunity__c = qTestOppty.Id,StartDate = System.now().addDays(1),EndDate = System.now().addDays(1).addHours(3),Duration = 180, DurationType = 'Minutes',Status = 'New');
        insert testWO;
        WorkOrder qTestWO = [SELECT Id, Subject,Status,AccountId FROM WorkOrder WHERE AccountId = :qTestAccount.Id LIMIT 1];

        ServiceAppointment testSA = new ServiceAppointment(Street = '123 Test Street',
                City = 'Lincoln', State = 'NE', Country = 'US', PostalCode = '68521',
                SchedStartTime = System.now().addDays(1), SchedEndTime = System.now().addDays(1).addHours(3),
                ParentRecordId = qTestWO.Id);
        insert testSA;

    }
    @IsTest
    static void testRelateUnrelatedAppointments() {
        Account testAccount = [SELECT Id,OwnerId FROM Account WHERE Name_of_Lead_Source__c = 'TestCraaap' LIMIT 1];
        WorkOrder testWO = [SELECT AccountId, Opportunity__c FROM WorkOrder WHERE AccountId = :testAccount.Id LIMIT 1];
        List<Id> accountIds = new List<Id>{testAccount.Id};
        List<Id> woIds = new List<Id>{testWO.Id};
        Test.startTest();
        WorkOrderRelationHelper.RelateUnrelatedAppointmentsFromAccountIds(woIds);
        Test.stopTest();

        Account updatedAccount = [SELECT Stage__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals('Active', updatedAccount.Stage__c, 'Account Stage should be Active');

        Opportunity relatedOpportunity = [SELECT StageName FROM Opportunity WHERE AccountId = :testAccount.Id LIMIT 1];
        System.assertEquals('Pending', relatedOpportunity.StageName, 'Opportunity Stage should be Pending');
    }
    @IsTest
    static void testHandleRelations(){
        Account testAccount = [SELECT Id,OwnerId FROM Account WHERE Name_of_Lead_Source__c = 'TestCraaap' LIMIT 1];
        ServiceAppointment testSA = [SELECT Id,ParentRecordId,AccountId,SchedStartTime FROM ServiceAppointment WHERE Street = '123 Test Street'];
        Property__c testProp = [SELECT Id FROM Property__c WHERE Address__Street__s = '123 Test Street'];
        WorkOrderRelationHelper.HandleRelations(testAccount, testSA,testProp);

    }
//    @IsTest
//    static void testHandleNoOpenOpportunity() {
//        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
//        Property__c testProperty = [SELECT Id FROM Property__c WHERE Address__Street__s = '123 Test St' LIMIT 1];
//        ServiceAppointment testSA = [SELECT Id, SchedStartTime FROM ServiceAppointment WHERE Street = '123 Test St' LIMIT 1];
//        WorkOrder testWO = [SELECT Id FROM WorkOrder WHERE AccountId = :testAccount.Id LIMIT 1];
//
//        Test.startTest();
//        WorkOrderRelationHelper.HandleNoOpenOpportunity(testAccount, testSA, testProperty, testWO);
//        Test.stopTest();
//
//        Account updatedAccount = [SELECT Stage__c FROM Account WHERE Id = :testAccount.Id];
//        System.assertEquals('Active', updatedAccount.Stage__c, 'Account Stage should be Active');
//
//        Opportunity newOpportunity = [SELECT StageName FROM Opportunity WHERE AccountId = :testAccount.Id ORDER BY CreatedDate DESC LIMIT 1];
//        System.assertEquals('Pending', newOpportunity.StageName, 'New Opportunity should be Pending');
//    }
    @IsTest
    static void testHandleOpenOpportunity() {
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name_of_Lead_Source__c LIKE 'TestCraaap' LIMIT 1];
        ServiceAppointment testSA = [SELECT Id,Subject, SchedStartTime FROM ServiceAppointment WHERE Street = '123 Test Street' LIMIT 1];
        Property__c testProperty = [SELECT Id,Name FROM Property__c WHERE Address__Street__s = '123 Test Street' LIMIT 1];
        WorkOrder testWO = [SELECT Id FROM WorkOrder WHERE AccountId = :testAccount.Id LIMIT 1];
        Opportunity testOpp = [SELECT Id FROM Opportunity WHERE AccountId = :testAccount.Id LIMIT 1];
        Test.startTest();
        WorkOrderRelationHelper.HandleOpenOpportunity(testAccount, testSA, testProperty, testWO, testOpp);
        Test.stopTest();

        Opportunity updatedOpportunity2 = [SELECT Id, StageName FROM Opportunity WHERE Id = :testOpp.Id LIMIT 1];
        System.assertEquals('Pending', updatedOpportunity2.StageName, 'Opportunity Stage should be updated to Pending');
    }
}