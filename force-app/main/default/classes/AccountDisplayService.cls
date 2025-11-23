/**
 * Created by noahr on 6/18/2024.
 */

public with sharing class AccountDisplayService {
    public static void CreateNewProperty(String street, String city, String state, String postalCode, String country, String accId,Boolean isPrimary){
        Property__c newProperty = new Property__c(
                Name = street + ' ' + city + ', ' + state
        );
        newProperty.Address__City__s = city;
        newProperty.Address__Street__s = street;
        newProperty.Address__CountryCode__s = 'US';
        newProperty.Address__StateCode__s = state;
        newProperty.Address__PostalCode__s = postalCode;
        newProperty.AccountId__c = accId;

        insert newProperty;

//        Account_Property_Relationship__c newRel = new Account_Property_Relationship__c(
//                Account__c = accId,
//                Property__c = newProperty.Id
//        );
//
//        insert newRel;
//
//        Account_Property_Relationship__c currPrim = new Account_Property_Relationship__c();
//        try{
//            currPrim =  [SELECT isPrimaryResidence__c FROM Account_Property_Relationship__c WHERE Account__c = :accId AND isPrimaryResidence__c = TRUE LIMIT 1];
//        } catch (Exception ex) {
//            currPrim = null;
//        }
//
//        if(currPrim == null){
//            newRel.isPrimaryResidence__c = true;
//            update newRel;
//        }
//        else if(isPrimary){
//            setNewPrimaryAddress(accId,newProperty.Id);
//        }
    }

    public static void CreateNewCallback(Datetime followUpDate, String sDescription, String accountId,Id userId){
        Account linkedAccount = [SELECT Name,Primary_Contact__c FROM Account WHERE Id = :accountId LIMIT 1];

        linkedAccount.Call_Back_Date__c = followUpDate;
        linkedAccount.Account_Disposition__c = 'Following Up';

        update linkedAccount;

        Date setDate = Date.newInstance(followUpDate.year(),followUpDate.month(),followUpDate.day());
        if(String.isEmpty(sDescription)){
            sDescription = ' ';
        }
        if(linkedAccount.Primary_Contact__c != null) {
            Task newTask = new Task(
                    Subject = 'Follow Up For: ' + linkedAccount.Name,
                    ActivityDate = setDate,
                    IsReminderSet = true,
                    ReminderDateTime = followUpDate,
                    Description = sDescription,
                    OwnerId = userId,
                    WhatId = accountId,
                    WhoId = linkedAccount.Primary_Contact__c
            );

            insert newTask;
        } else{
            Task newTask = new Task(
                    Subject = 'Follow Up For: ' + linkedAccount.Name,
                    ActivityDate = setDate,
                    IsReminderSet = true,
                    ReminderDateTime = followUpDate,
                    Description = sDescription,
                    OwnerId = userId,
                    WhatId = accountId
            );

            insert newTask;
        }

        try{
            List<Opportunity> openOps = [SELECT Id FROM Opportunity WHERE AccountId = :linkedAccount.Id AND IsClosed = FALSE];
            System.debug(openOps);
            for(Opportunity op : openOps){
                op.Next_Step_Date__c = setDate;
                op.NextStep = sDescription;
            }
            update openOps;
        } catch(Exception e) {

        }


    }

    public static void setNewPrimaryAddress(String accountId, String propId){
        Account_Property_Relationship__c newPrim = [SELECT isPrimaryResidence__c FROM Account_Property_Relationship__c WHERE Account__c = :accountId AND Property__c = :propId LIMIT 1];
        Account_Property_Relationship__c currPrim = new Account_Property_Relationship__c();
        try{
            currPrim =  [SELECT isPrimaryResidence__c FROM Account_Property_Relationship__c WHERE Account__c = :accountId AND isPrimaryResidence__c = TRUE LIMIT 1];
        } catch (Exception ex) {
            currPrim = null;
        }

        if(currPrim != null){
            currPrim.isPrimaryResidence__c = false;
            update currPrim;
        }

        newPrim.isPrimaryResidence__c = true;
        update newPrim;

    }

    public static List<Property__c> GetRelatedProperties(String accId){
        List<Property__c> propList = [SELECT Name,Id FROM Property__c WHERE AccountId__c = :accId];
        List<Id> ids = new List<Id>();

        for(Property__c c : propList){
            ids.add(c.Id);
        }

        return propList;
    }

    public static String getPrimaryProperty(String accountId){
        List<Account_Property_Relationship__c> propLists = [SELECT isPrimaryResidence__c, Property__c FROM Account_Property_Relationship__c WHERE Account__c = :accountId];

        Account_Property_Relationship__c primRes = new Account_Property_Relationship__c();
        for(Account_Property_Relationship__c ap : propLists){
            if(ap.isPrimaryResidence__c){
                primRes = ap;
                break;
            }
        }

        return primRes.Property__c;
    }

    public static List<Property__c> getLinkedProperties(String accountId){
        List<Property__c> propList = new List<Property__c>();
        List<Account_Property_Relationship__c> propLists = [SELECT Property__c, Property__r.Name FROM Account_Property_Relationship__c WHERE Account__c = :accountId];

        for(Account_Property_Relationship__c ap : propLists) {
            Property__c prop = new Property__c(
                    Name = ap.Property__r.Name,
                    Id = ap.Property__c
            );
            propList.add(prop);
        } 

        return propList;
    }
}