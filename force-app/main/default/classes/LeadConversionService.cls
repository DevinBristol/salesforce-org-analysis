/**
 * Created by noahr on 6/3/2024.
 */

public with sharing class LeadConversionService {

    public static void UpdateLead(String fName, String lName, String company, String sStreet, String sCity,
                                        String sState, String sPostalCode, String sCountry, Id leadId, String sMobilePhone,
                                        String sEmail, String leadSource,String accountOwner,String sPhone,String relatedCampaign)
    {
        Lead updatedLead = [SELECT Id FROM Lead WHERE Id = :leadId];

        updatedLead.FirstName = fName;
        updatedLead.LastName = lName;
        updatedLead.Street = sStreet;
        updatedLead.City = sCity;
        updatedLead.State = sState;
        updatedLead.Country = 'US';
        updatedLead.PostalCode = sPostalCode;
        updatedLead.MobilePhone = sMobilePhone;
        updatedLead.Email = sEmail;
        updatedLead.LeadSource = leadSource;
        updatedLead.OwnerId = accountOwner;
        updatedLead.Phone = sPhone;

        update updatedLead;

        try{
            CampaignMember newCM = new CampaignMember(
                    LeadId = updatedLead.Id,
                    CampaignId = relatedCampaign
            );

            upsert newCM;
        } catch(Exception e){
            System.debug(e);
        }
    }

    public static void CreateProperty(String convertedLead,String propertyType){
        Account newAccount = [SELECT BillingAddress FROM Account WHERE Id = :convertedLead];
        Address accAddress = newAccount.BillingAddress;

        Boolean isMakeProperty = LeadFormHelper.CheckForAddress(accAddress.street,accAddress.city,accAddress.country,
                accAddress.state,accAddress.postalCode);


        if(isMakeProperty) {
            Property__c newProperty = new Property__c(
                    Name =  accAddress.street + ' ' +  accAddress.city + ', ' +  accAddress.state
            );
            newProperty.Address__City__s =  accAddress.city;
            newProperty.Address__Street__s =  accAddress.street;
            newProperty.Address__CountryCode__s = 'US';
            newProperty.Address__StateCode__s =  accAddress.state;
            newProperty.Address__PostalCode__s =  accAddress.postalCode;
            newProperty.AccountId__c = convertedLead;
            newProperty.Property_Type__c = propertyType;

            insert newProperty;
        }
    }


    public static String ConvertLead(Id leadId, String accountType, String PropertyType, String secondFName, String secondLName,
                                     String secondMobile, String secondEmail,String secondPhone,String leadSource,String relatedCampaign){
        LeadStatus convertStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = TRUE LIMIT 1];
        List<Database.LeadConvert> leadConverts = new List <Database.LeadConvert>();

        Lead lead = [SELECT Name, Company, OwnerId, Id, IsConverted,Street,City,State,Country,PostalCode FROM Lead WHERE Id = :leadId LIMIT 1];
        lead.Lead_Type__c = accountType;

        if(!lead.IsConverted){
            Database.LeadConvert lc = new Database.LeadConvert();

            lc.setLeadId(lead.Id);
            lc.setDoNotCreateOpportunity(true);
            lc.setConvertedStatus(convertStatus.MasterLabel);

            leadConverts.add(lc);
        }

        List<Database.LeadConvertResult> lcr = Database.convertLead(leadConverts);
        Lead convertedLead = [SELECT ConvertedAccountId FROM Lead WHERE Id = :leadId];

        Boolean isMakeProperty = LeadFormHelper.CheckForAddress(lead.Street,lead.City,lead.Country,lead.State,lead.PostalCode);
        System.debug(isMakeProperty);


        if(!String.isBlank(secondFName)){
            Contact secondaryContact = new Contact(
                    FirstName = secondFName,
                    LastName = secondLName,
                    MobilePhone = secondMobile,
                    Email = secondEmail,
                    AccountId = convertedLead.ConvertedAccountId,
                    Phone = secondPhone
            );

            insert secondaryContact;
        }
        Account newAcc = [SELECT Id,Primary_Contact__c FROM Account WHERE Id = :convertedLead.ConvertedAccountId];
        newAcc.Type = accountType;
        newAcc.Account_Disposition__c = 'Converted: Working';

        Campaign linkedCampaign = [SELECT Name FROM Campaign WHERE Id = :relatedCampaign];
        newAcc.Name_of_Lead_Source__c = linkedCampaign.Name;

//        CampaignMember newMem = new CampaignMember(
//                AccountId = newAcc.Id,
//                ContactId = newAcc.Primary_Contact__c
//        );
//
//        upsert newMem;
        update newAcc;

        return convertedLead.ConvertedAccountId;
    }

    public static void CreateCallback(Datetime followUpDate, String sDescription, String accountId,Id userId){
        Account linkedAccount = [SELECT Name,Primary_Contact__c FROM Account WHERE Id = :accountId LIMIT 1];

        Date d = Date.newInstance(followUpDate.year(),followUpDate.month(),followUpDate.day());
        if(String.isEmpty(sDescription)){
            sDescription = ' ';
        }

        if(linkedAccount.Primary_Contact__c != null){
            Task newTask = new Task(
                    Subject = 'Follow Up For: ' + linkedAccount.Name,
                    ActivityDate = d,
                    IsReminderSet = true,
                    ReminderDateTime = followUpDate,
                    Description = sDescription,
                    OwnerId = userId,
                    WhatId = accountId,
                    WhoId = linkedAccount.Primary_Contact__c
            );

            insert newTask;
        }else {
            Task newTask = new Task(
                    Subject = 'Follow Up For: ' + linkedAccount.Name,
                    ActivityDate = d,
                    IsReminderSet = true,
                    ReminderDateTime = followUpDate,
                    Description = sDescription,
                    OwnerId = userId,
                    WhatId = accountId
            );

            insert newTask;
        }
    }

    public static String getMostRecentCampaign(String leadId){
        List<CampaignMember> CampaignMembers = [SELECT CampaignId FROM CampaignMember WHERE LeadId = :leadId ORDER BY CreatedDate];
        System.debug(CampaignMembers);
        if(CampaignMembers.size() > 0){
            String mostRecentCampaignId = CampaignMembers[0].CampaignId;
            Campaign mostRecentCampaign = [SELECT Name,Id FROM Campaign WHERE Id = :mostRecentCampaignId];
            System.debug(mostRecentCampaign.Id);
            return mostRecentCampaign.Id;
        } else {
            System.debug('hge');
            return null;
        }

    }

}