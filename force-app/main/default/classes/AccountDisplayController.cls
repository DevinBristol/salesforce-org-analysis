/**
 * Created by noahr on 6/18/2024.
 */

public with sharing class AccountDisplayController {
    @AuraEnabled(Cacheable=false)
    public static void CreateNewPropertyBuffer(String street, String city, String state, String postalCode, String country,String accId,Boolean isPrimary){
        AccountDisplayService.CreateNewProperty(street,city,state,postalCode,country,accId,isPrimary);
    }

    @AuraEnabled(Cacheable=false)
    public static void CreateNewCallbackBuffer(Datetime followUpDate, String sDescription, String accountId,Id userId){
        AccountDisplayService.CreateNewCallback(followUpDate,sDescription,accountId,userId);
    }

//    @AuraEnabled(Cacheable=false)
//    public static void CreateNewOpportunityBuffer(Datetime workDate, String sOwnerId, String propertyId, String workTypeId, String sAccountId) {
//        AccountDisplayService.CreateNewOpportunity(workDate,sOwnerId,propertyId,workTypeId,sAccountId);
//    }

    @AuraEnabled(Cacheable=false)
    public static void setNewPrimaryAddressBuffer(String accountId, String propId){
        AccountDisplayService.setNewPrimaryAddress(accountId,propId);
    }

    @AuraEnabled(Cacheable=false)
    public static List<Property__c> GetRelatedPropertiesBuffer(String accId){
        return AccountDisplayService.GetRelatedProperties(accId);
    }
    @AuraEnabled(Cacheable=false)
    public static String getPrimaryPropertyBuffer(String accountId){
        return AccountDisplayService.getPrimaryProperty(accountId);
    }

    @AuraEnabled(Cacheable=false)
    public static List<Property__c> getLinkedPropertiesBuffer(String accountId){
        return AccountDisplayService.getLinkedProperties(accountId);
    }
}