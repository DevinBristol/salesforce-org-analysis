/**
 * Created by noahr on 6/3/2024.
 */

public with sharing class LeadConversionController {
    @AuraEnabled(Cacheable=false)
    public static void UpdateLeadBuffer(String fName, String lName, String company, String sStreet, String sCity,
                                        String sState, String sPostalCode, String sCountry, Id leadId, String mobilePhone,
                                        String email,String leadSource, String accountId,String sPhone,String relatedCampaign){
        LeadConversionService.UpdateLead(fName,lName,company,sStreet,sCity,sState,sPostalCode,sCountry,leadId,mobilePhone,email,leadSource,accountId,sPhone,relatedCampaign);
    }
    @AuraEnabled(Cacheable=false)
    public static String ConvertLeadBuffer(Id leadId, String accountType, String PropertyType, String secondFName, String secondLName,
            String secondMobile, String secondEmail,String secondPhone,String leadSource,String relatedCampaign){
        String returnString = LeadConversionService.ConvertLead(leadId,accountType,PropertyType,secondFName,secondLName,secondMobile,secondEmail,secondPhone,leadSource,relatedCampaign);
        return returnString;
    }
    @AuraEnabled(Cacheable=false)
    public static void CreateCallbackBuffer(Datetime followUpDate, String description, String accountId,Id userId){
        LeadConversionService.CreateCallback(followUpDate, description, accountId, userId);
    }
    @AuraEnabled(Cacheable=false)
    public static void CreatePropertyBuffer(String convertedLead,String propertyType){
        LeadConversionService.CreateProperty(convertedLead,propertyType);
    }
    @AuraEnabled(Cacheable=true)
    public static String getMostRecentCampaignBuffer(String leadId){
        return LeadConversionService.getMostRecentCampaign(leadId);
    }

//    @AuraEnabled(Cacheable=false)
//    public static void WorkOrderCreationBuffer(Datetime workDate, String ownerId, String propertyId, String workType, String accountId,String productItemId,Integer numberOfItems){
//        LeadConversionService.WorkOrderCreation(workDate,ownerId,propertyId,workType,accountId,productItemId,numberOfItems);
//    }
}