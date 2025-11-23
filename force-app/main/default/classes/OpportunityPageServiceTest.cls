/**
 * Created by noahr on 8/12/2024.
 */

@IsTest
public with sharing class OpportunityPageServiceTest {

    @IsTest
    static void ChangeStatusTest(){
        Account newAcc = new Account(
                Name = 'Placeholder Name'
        );
        insert newAcc;

        Opportunity newOpp = new Opportunity(
                Name = 'Placeholder',
                AccountId = newAcc.Id,
                StageName = 'Nurturing',
                CloseDate = Date.today()
        );
        insert newOpp;

        OpportunityPageController.ChangeStatusBuffer('Not Ready',newOpp.Id,' ',' ');
        Account returnedAcc = [SELECT Stage__c FROM Account WHERE Id = :newAcc.Id];
        System.assertEquals('Nurturing',returnedAcc.Stage__c);

        OpportunityPageController.ChangeStatusBuffer('Lost',newOpp.Id,'Unqualified','x');
        Account returnedAcc2 = [SELECT Stage__c,Account_Disposition__c FROM Account WHERE Id = :newAcc.Id];
        System.assertEquals('Lost',returnedAcc2.Stage__c);
        System.assertEquals('Unqualified: x',returnedAcc2.Account_Disposition__c);

        OpportunityPageController.ChangeStatusBuffer('Lost',newOpp.Id,'Closed / Lost','x');
        Account returnedAcc3 = [SELECT Stage__c,Account_Disposition__c FROM Account WHERE Id = :newAcc.Id];
        System.assertEquals('Lost',returnedAcc3.Stage__c);
        System.assertEquals('Closed / Lost: x',returnedAcc3.Account_Disposition__c);

        OpportunityPageController.ChangeStatusBuffer('No Interest',newOpp.Id,'w','x');
        Account returnedAcc4 = [SELECT Stage__c,Account_Disposition__c FROM Account WHERE Id = :newAcc.Id];
        System.assertEquals('Nurturing',returnedAcc4.Stage__c);
        System.assertEquals('w: x',returnedAcc4.Account_Disposition__c);

        OpportunityPageController.ChangeStatusBuffer('Reset',newOpp.Id,'w','x');
        Opportunity returnedOpp = [SELECT StageName FROM Opportunity WHERE Id = :newOpp.Id];
        System.assertEquals('Confirming',returnedOpp.StageName);
    }

    @IsTest
    static void CreateCallbackTest(){
        Account newAcc = new Account(
                Name = 'Placeholder'
        );
        insert newAcc;

        OpportunityPageController.CreateCallbackBuffer(Date.today(),' ',newAcc.Id,'005Hs00000DCEpBIAX',false);
        Task newTask = [SELECT Subject FROM Task WHERE WhatId = :newAcc.Id];
        System.assertEquals('Follow Up For: No Contacts in Account', newTask.Subject);

        OpportunityPageController.CreateCallbackBuffer(Date.today(),'',newAcc.Id,'005Hs00000DCEpBIAX',true);
        Task newTask2 = [SELECT Subject FROM Task WHERE WhatId = :newAcc.Id AND Subject = '(Unreachable)Follow Up For: No Contacts in Account'];
        System.assertEquals('(Unreachable)Follow Up For: No Contacts in Account', newTask2.Subject);

        Contact newCon = new Contact(
                FirstName = 'test',
                LastName = 'hehe',
                AccountId = newAcc.Id
        );
        insert newCon;

        Account newAcc2 = new Account(
                Id = newAcc.Id,
                Primary_Contact__c = newCon.Id
        );
        update newAcc2;

        OpportunityPageController.CreateCallbackBuffer(Date.today(),' ',newAcc.Id,'005Hs00000DCEpBIAX',false);
        Task newTask3 = [SELECT Subject FROM Task WHERE WhatId = :newAcc.Id AND Subject = 'Follow Up For: test hehe'];
        System.assertEquals('Follow Up For: test hehe', newTask3.Subject);

        OpportunityPageController.CreateCallbackBuffer(Date.today(),'',newAcc.Id,'005Hs00000DCEpBIAX',true);
        Task newTask4 = [SELECT Subject FROM Task WHERE WhatId = :newAcc.Id AND Subject = '(Unreachable)Follow Up For: test hehe'];
        System.assertEquals('(Unreachable)Follow Up For: test hehe', newTask4.Subject);

    }

    @IsTest
    static void WorkOrderCreationTest(){
        Account newAcc = new Account(
                Name = 'Placeholder'
        );
        insert newAcc;

        Contact newCon = new Contact(
                FirstName = 'test',
                LastName = 'hehe',
                AccountId = newAcc.Id
        );
        insert newCon;

        Opportunity newOpp = new Opportunity(
                AccountId = newAcc.Id,
                Name = 'test',
                StageName = 'Nurturing',
                CloseDate = Date.today()
        );
        insert newOpp;

        OpportunityPageController.WorkOrderCreationBuffer(Date.today(),'005Hs00000DCEpBIAX',newOpp.Id,'08qHs000000kgPPIAY',newAcc.Id);
        WorkOrder wo = [SELECT Id,WorkTypeId,OwnerId,Opportunity__c FROM WorkOrder WHERE AccountId = :newAcc.Id];

        System.assertEquals(newOpp.Id,wo.Opportunity__c);
        System.assertEquals('005Hs00000DCEpBIAX',wo.OwnerId);
        System.assertEquals('08qHs000000kgPPIAY',wo.WorkTypeId);
    }
}