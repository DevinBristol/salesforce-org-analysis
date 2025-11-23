/**
 * Created by Devin on 6/4/2024.
 */
//TODO RENAME TO LeadTriggerHelper
public with sharing class LeadService {

    public static List<Lead> DeformatLeadNumbers(List<Lead> leads){
        List<Lead> returnLeads;

        for(Lead l: leads){
            if(l.MobilePhone.containsAny('[^0-9]')){
                l.MobilePhone = PhoneNumberService.DeformatPhone(l.MobilePhone);
            }
            if(l.Phone.containsAny('[^0-9]')){
                l.Phone = PhoneNumberService.DeformatPhone(l.Phone);
            }
            if(l.Secondary_Contact_Mobile__c.containsAny('[^0-9]')){
                l.Secondary_Contact_Mobile__c = PhoneNumberService.DeformatPhone(l.Secondary_Contact_Mobile__c);
            }
            returnLeads.add(l);
        }
        return returnLeads;
    }
}