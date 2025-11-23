/**
 * Created by noahr on 8/8/2024.
 */

@IsTest
private class LeadConversionServiceTest {

    @IsTest
    static void UpdateLeadTest(){
        Lead newLead = new Lead(
                FirstName = 'testFirst',
                LastName = 'testLast',
                Street = '5500 south 88th street',
                City = 'Lincoln',
                State = 'NE',
                Country = 'US',
                PostalCode = '68526',
                MobilePhone = '4022194185'
        );

        insert newLead;

//        LeadConversionController.UpdateLeadBuffer('testNewFirst','testNewLast', '','5500 south 88th street','Lincoln','NE','68526','US',
//                newLead.Id, '','','Google Organic');
//
//        Lead anotherLead = [SELECT FirstName,LastName FROM Lead WHERE Id = :newLead.Id];
//
//        System.assertEquals('testNewFirst',anotherLead.FirstName);
//        System.assertEquals('testNewLast',anotherLead.LastName);
    }

    @IsTest
    static void ConvertLeadTest(){
        Lead newLead = new Lead(
                FirstName = 'testFirst',
                LastName = 'testLast',
                Street = '5500 south 88th street',
                City = 'Lincoln',
                State = 'NE',
                Country = 'US',
                PostalCode = '68526',
                MobilePhone = '4022194185'
        );

        insert newLead;

//        String accId = LeadConversionController.ConvertLeadBuffer(newLead.Id,'Customer','Residential','testF',
//                'testL','','email@email.calm');
//
//        Account newAccount = [SELECT Name FROM Account WHERE Id = :accId];
//
//        System.assertEquals('testF testL & testFirst testLast',newAccount.Name);
//
//        LeadConversionController.CreatePropertyBuffer(newAccount.Id, 'Residential');
//        Account newAccount2 = [SELECT Name,BillingAddress FROM Account WHERE Id = :accId];
//        System.assertNotEquals(null,newAccount2.BillingAddress);

    }

    @IsTest
    static void CreateCallbackTest(){
        Account newAcc = new Account(
                Name = 'placeHolder'
        );
        insert newAcc;

        Contact newContact = new Contact(
                FirstName = 'firstName',
                LastName = 'lastName',
                AccountId = newAcc.Id
        );
        insert newContact;

        LeadConversionController.CreateCallbackBuffer(Date.today(),'',newAcc.Id,'005R70000031PSUIA2');

        Task madeTask = [SELECT Subject FROM Task WHERE WhatId = :newAcc.Id];
        System.assertEquals('Follow Up For: firstName lastName', madeTask.Subject);


        Account newAccTwo = new Account(
                Name = 'firstName lastName'
        );
        insert newAccTwo;

        Contact newContactTwo = new Contact(
                FirstName = 'firstName',
                LastName = 'lastName',
                AccountId = newAccTwo.Id
        );
        insert newContactTwo;

        newAccTwo.Primary_Contact__c = newContactTwo.Id;
        update newAccTwo;

        LeadConversionController.CreateCallbackBuffer(Date.today(),'',newAccTwo.Id,'005R70000031PSUIA2');

        Task madeTaskTwo = [SELECT Subject FROM Task WHERE WhoId = :newContactTwo.Id];
        System.assertEquals('Follow Up For: firstName lastName', madeTaskTwo.Subject);
    }
}