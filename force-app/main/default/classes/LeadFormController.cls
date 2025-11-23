/**
 * Created by noahr on 5/30/2024.
 */

public with sharing class LeadFormController {
    @AuraEnabled(Cacheable=false)
    public static String LeadCreationBuffer(String firstName, String lastName, String company,
            String sStreet, String sCity, String sCountry,
            String sState, String sPostalCode, String sPhoneNumber, String emailAddress, String Ecampaign) {
        if(sCountry=='United States'){sCountry = 'US';}
        return LeadFormService.createLead(firstName, lastName, company, sStreet, sCity, sCountry, sState, sPostalCode, sPhoneNumber, emailAddress, Ecampaign);
    }

    @AuraEnabled(Cacheable=false)
    public static String ContactCreationBuffer(String firstName, String lastName, String company,
            String sStreet, String sCity, String sCountry,
            String sState, String sPostalCode, String sPhoneNumber, String emailAddress, Date CallbackDate, String sCreatedById, Boolean isSecondContact,
            String secondFirstName, String secondLastName, String secondEmailAddress, String secondPhoneNumber, Boolean isMakeCallback, String Ecampaign) {

        return LeadFormService.createContact(firstName, lastName, company, sStreet, sCity, sCountry, sState, sPostalCode, sPhoneNumber, emailAddress, CallbackDate, sCreatedById,isSecondContact,
                secondFirstName,secondLastName,secondEmailAddress,secondPhoneNumber,isMakeCallback, Ecampaign);
    }

}