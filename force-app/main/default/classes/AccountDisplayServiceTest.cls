/**
 * Created by noahr on 8/9/2024.
 */

@IsTest
private class AccountDisplayServiceTest {

    @IsTest
    static void CreateNewPropertyTest(){
        Account newAcc = new Account(
                Name = 'Placeholder'
        );
        insert newAcc;

        AccountDisplayController.CreateNewPropertyBuffer('street','lincoln','NE','68526','US',
                                                         newAcc.Id,true);
        AccountDisplayController.CreateNewPropertyBuffer('street2','lincoln2','NE','68526','US',
                newAcc.Id,true);

        List<Account_Property_Relationship__c> newRels = [SELECT Id,Property__c FROM Account_Property_Relationship__c WHERE Account__c = :newAcc.Id];
        System.assertEquals(1,newRels.size());

        Account newAcc2 = new Account(
                Name = 'Placeholder'
        );
        insert newAcc2;

        Property__c newProperty = new Property__c(
                Name = 'Placeholder'
        );
        newProperty.Address__City__s = 'h';
        newProperty.Address__Street__s = 'h';
        newProperty.Address__CountryCode__s = 'US';
        newProperty.Address__StateCode__s = 'NE';
        newProperty.Address__PostalCode__s = '68526';
        newProperty.AccountId__c = newAcc2.Id;

        insert newProperty;
        Account_Property_Relationship__c newRelInsert = new Account_Property_Relationship__c(
                Account__c = newAcc2.Id,
                Property__c = newProperty.Id
        );
        insert newRelInsert;

        AccountDisplayController.setNewPrimaryAddressBuffer(newAcc2.Id,newProperty.Id);

        Account_Property_Relationship__c newRel = [SELECT Property__c FROM Account_Property_Relationship__c WHERE Account__c = :newAcc2.Id];

        System.assertEquals(newRel.Property__c, newProperty.Id);
    }

    @IsTest
    static void CreateNewCallbackTest(){
        Account newAcc = new Account(
                Name = 'Placeholder'
        );
        insert newAcc;

        Contact newCon = new Contact(
                FirstName = 'first',
                LastName = 'last',
                AccountId = newAcc.Id
        );
        insert newCon;

        AccountDisplayController.CreateNewCallbackBuffer(Date.today(),'',newAcc.Id,'005R70000031PSUIA2');
        Account returningAcc = [SELECT Call_Back_Date__c FROM Account WHERE Id = :newAcc.Id];
        Task newTask = [SELECT Id,Description,Subject FROM Task WHERE WhatId = :newAcc.Id];

        System.assertEquals('Follow Up For: first last',newTask.Subject);
        System.assertEquals(null,newTask.Description);
        System.assertEquals(Date.today(),returningAcc.Call_Back_Date__c);

        Account accountPulled = [SELECT Id FROM Account WHERE Id = :newAcc.Id];
        accountPulled.Primary_Contact__c = newCon.Id;
        update accountPulled;

        AccountDisplayController.CreateNewCallbackBuffer(Date.today(),'',newAcc.Id,'005R70000031PSUIA2');
        Account returningAccTwo = [SELECT Call_Back_Date__c FROM Account WHERE Id = :newAcc.Id];
        Task newTaskTwo = [SELECT Id,Description,Subject,WhoId FROM Task WHERE WhatId = :newAcc.Id AND WhoId = :newCon.Id];

        System.assertEquals('Follow Up For: first last',newTaskTwo.Subject);
        System.assertEquals(null,newTaskTwo.Description);
        System.assertEquals(Date.today(),returningAccTwo.Call_Back_Date__c);
        System.assertEquals(newCon.Id,newTaskTwo.WhoId);

    }

    @IsTest
    static void GetRelatedPropsTest(){
        Account newAcc2 = new Account(
                Name = 'Placeholder'
        );
        insert newAcc2;

        Property__c newProperty = new Property__c(
                Name = 'Placeholder'
        );
        newProperty.Address__City__s = 'h';
        newProperty.Address__Street__s = 'h';
        newProperty.Address__CountryCode__s = 'US';
        newProperty.Address__StateCode__s = 'NE';
        newProperty.Address__PostalCode__s = '68526';
        newProperty.AccountId__c = newAcc2.Id;

        insert newProperty;
        Account_Property_Relationship__c newRelInsert = new Account_Property_Relationship__c(
                Account__c = newAcc2.Id,
                Property__c = newProperty.Id
        );
        insert newRelInsert;

        List<Property__c> propList = AccountDisplayController.GetRelatedPropertiesBuffer(newAcc2.Id);

        System.assertEquals(propList[0].Id,newProperty.Id);
    }

    @IsTest
    static void GetPrimaryPropTest(){
        Account newAcc2 = new Account(
                Name = 'Placeholder'
        );
        insert newAcc2;

        Property__c newProperty = new Property__c(
                Name = 'Placeholder'
        );
        newProperty.Address__City__s = 'h';
        newProperty.Address__Street__s = 'h';
        newProperty.Address__CountryCode__s = 'US';
        newProperty.Address__StateCode__s = 'NE';
        newProperty.Address__PostalCode__s = '68526';
        newProperty.AccountId__c = newAcc2.Id;

        insert newProperty;
        Account_Property_Relationship__c newRelInsert = new Account_Property_Relationship__c(
                Account__c = newAcc2.Id,
                Property__c = newProperty.Id,
                isPrimaryResidence__c = true
        );
        insert newRelInsert;

        System.assertEquals(AccountDisplayController.getPrimaryPropertyBuffer(newAcc2.Id),newProperty.Id);
    }

    @IsTest
    static void GetLinkedPropsTest(){
        Account newAcc2 = new Account(
                Name = 'Placeholder'
        );
        insert newAcc2;

        Property__c newProperty = new Property__c(
                Name = 'Placeholder'
        );
        newProperty.Address__City__s = 'h';
        newProperty.Address__Street__s = 'h';
        newProperty.Address__CountryCode__s = 'US';
        newProperty.Address__StateCode__s = 'NE';
        newProperty.Address__PostalCode__s = '68526';
        newProperty.AccountId__c = newAcc2.Id;

        insert newProperty;
        Account_Property_Relationship__c newRelInsert = new Account_Property_Relationship__c(
                Account__c = newAcc2.Id,
                Property__c = newProperty.Id
        );
        insert newRelInsert;

        List<Property__c> propList = AccountDisplayController.getLinkedPropertiesBuffer(newAcc2.Id);

        System.assertEquals(propList[0].Id,newProperty.Id);
    }
}