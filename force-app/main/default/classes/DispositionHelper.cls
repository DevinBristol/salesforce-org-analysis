/**
 * Created by Devin on 7/2/2024.
 */

public with sharing class DispositionHelper {
//BEN: I changed both lead&contact Bad_Phone__c fields to plain-Text(255) instead of Rich Text so we can filter by it in SOQL.
//BEN: I also changed the Bad_Phones__c format to only add a comma if Bad_Phones__c was previously not null so it can be easily loaded into csv.
    public static Lead LeadDisconnectedNumber(SObject lead, String DisconnectedNumber){
        Lead returnLead = (Lead)lead;
        if(returnLead.MobilePhone != null && returnLead.MobilePhone == DisconnectedNumber){
            returnLead.MobilePhone = '';
            returnLead.Bad_Phones__c = (returnLead.Bad_Phones__c == null
                ? DisconnectedNumber
                : returnLead.Bad_Phones__c + ',' + DisconnectedNumber);
        }
        if(returnLead.Phone != null && returnLead.Phone == DisconnectedNumber){
            returnLead.Phone = '';
            returnLead.Bad_Phones__c = (returnLead.Bad_Phones__c == null
                    ? DisconnectedNumber
                    : returnLead.Bad_Phones__c + ',' + DisconnectedNumber);
        }
        if(returnLead.Secondary_Contact_Mobile__c != null && returnLead.Secondary_Contact_Mobile__c == DisconnectedNumber){
            returnLead.Secondary_Contact_Mobile__c = '';
            returnLead.Bad_Phones__c = (returnLead.Bad_Phones__c == null
                    ? DisconnectedNumber
                    : returnLead.Bad_Phones__c + ',' + DisconnectedNumber);

        }
        return returnLead;
    }
    public static Contact ContactDisconnectedNumber(SObject contact, String DisconnectedNumber){
        Contact returnContact = (Contact)contact;
        if(returnContact.MobilePhone != null && returnContact.MobilePhone == DisconnectedNumber){
            returnContact.MobilePhone = '';
            returnContact.Bad_Phones__c = (returnContact.Bad_Phones__c == null
                    ? DisconnectedNumber
                    : returnContact.Bad_Phones__c + ',' + DisconnectedNumber);
        }
        if(returnContact.Phone != null && returnContact.Phone == DisconnectedNumber){
            returnContact.Phone = '';
            returnContact.Bad_Phones__c = (returnContact.Bad_Phones__c == null
                    ? DisconnectedNumber
                    : returnContact.Bad_Phones__c + ',' + DisconnectedNumber);
        }
        if(returnContact.HomePhone != null && returnContact.HomePhone == DisconnectedNumber){
            returnContact.HomePhone = '';
            returnContact.Bad_Phones__c = (returnContact.Bad_Phones__c == null
                    ? DisconnectedNumber
                    : returnContact.Bad_Phones__c + ',' + DisconnectedNumber);
        }

        return returnContact;
    }
    public static Lead LeadDoNotCall(SObject lead){
        Lead returnLead = (Lead)lead;
        return returnLead;
    }
    public static Contact ContactDoNotCall(SObject contact){
        Contact returnContact = (Contact)contact;
        return returnContact;
    }
}