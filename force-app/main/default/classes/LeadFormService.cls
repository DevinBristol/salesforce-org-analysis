/**
 * Created by noahr on 5/30/2024.
 */
public with sharing class LeadFormService {
    public static String createLead(String fName, String lName, String companyName,
            String sStreet, String sCity, String sCountry,
            String sState, String sPostalCode, String sPhoneNumber,String emailAddress, String Ecampaign){

        System.debug(Ecampaign);
        Lead newLead = new Lead(
                FirstName = fName,
                LastName = lName,
                Company = 'placeholder',
                Status = 'Assigned',
                Phone = sPhoneNumber
        );

        newLead.City = sCity;
        newLead.Street = sStreet;
        newLead.Country = sCountry;
        newLead.State = sState;
        newLead.PostalCode = sPostalCode;

        if(!String.isBlank(emailAddress)){
            newLead.Email = emailAddress;
        }

        insert newLead;

        //Campaign selectedCampaign = [SELECT id FROM Campaign WHERE Name = :Ecampaign];

        CampaignMember newCampaignMember = new CampaignMember(
                LeadId = newLead.Id,
                CampaignId = Ecampaign

        );

        insert newCampaignMember;

        return newLead.Id;
    }

    public static String createContact(String fName, String lName, String companyName,
            String sStreet, String sCity, String sCountry,
            String sState, String sPostalCode,String sPhoneNumber,String emailAddress, Date CallbackDate,String sCreatedById, Boolean isSecondContact,
            String secondFirstName, String secondLastName, String secondEmailAddress, String secondPhoneNumber, Boolean isMakeCallback, String Ecampaign){

        Boolean isMakeProperty = LeadFormHelper.CheckForAddress(sStreet,sCity,sCountry,sState,sPostalCode);
        Account newAccount = new Account(
                Name = 'Trigger Isn\'t Working Devin'
        );
        if(isMakeCallback){
            newAccount.Call_Back_Date__c = CallbackDate;
        }
        insert newAccount;

        Contact newContact = new Contact(
                FirstName = fName,
                LastName = lName,
                AccountId = newAccount.Id,
                MobilePhone = sPhoneNumber
        );

        if(!String.isBlank(emailAddress)){
            newContact.Email = emailAddress;
        }

        upsert newContact;
        Contact nContact = [SELECT AccountId FROM Contact WHERE Id = :newContact.Id];
        Account newAccCheck = [SELECT Name FROM Account WHERE Id = :newContact.AccountId];

        CampaignMember newCampaignMember = new CampaignMember(
                ContactId = nContact.Id,
                CampaignId = Ecampaign

        );

        insert newCampaignMember;


        if(isMakeCallback) {
            Task newTask = new Task(
                    ActivityDate = CallbackDate,
                    WhatId = nContact.AccountId,
                    CreatedById = sCreatedById,
                    Subject = 'Callback For: ' + newAccCheck.Name
            );
            insert newTask;
        }

        Account newAcc = new Account(
                Id = nContact.AccountId
        );

        update newAcc;

        if(isSecondContact){
            Contact secondContact = new Contact(
                    FirstName = secondFirstName,
                    LastName = secondLastName,
                    AccountId = newAccount.Id,
                    MobilePhone = secondPhoneNumber
            );

            if(!String.isBlank(emailAddress)){
                secondContact.Email = secondEmailAddress;
            }

            upsert secondContact;
        }

        if(isMakeProperty) {

            Property__c newProperty = new Property__c(
                    Name = sStreet + ' ' + sCity + ', ' + sState
            );
            newProperty.Address__City__s = sCity;
            newProperty.Address__Street__s = sStreet;
            newProperty.Address__CountryCode__s = 'US';
            newProperty.Address__StateCode__s = sState;
            newProperty.Address__PostalCode__s = sPostalCode;
            newProperty.AccountId__c = newAccount.Id;

            insert newProperty;
        }
        newAcc.ShippingCity = sCity;
        newAcc.ShippingStreet = sStreet;
        newAcc.ShippingCountry = 'US';
        newAcc.ShippingState = sState;
        newAcc.ShippingPostalCode = sPostalCode;

        newAcc.BillingCity = sCity;
        newAcc.BillingStreet = sStreet;
        newAcc.BillingCountry = 'US';
        newAcc.BillingState = sState;
        newAcc.BillingPostalCode = sPostalCode;

        update newAcc;

        return newAcc.Id;
    }

}