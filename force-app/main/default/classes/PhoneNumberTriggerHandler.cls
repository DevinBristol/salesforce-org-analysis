/**
 * Created by Devin on 7/5/2024.
 */

public with sharing class PhoneNumberTriggerHandler extends TriggerHandler{

    public override void afterUpdate(){
        List<PhoneNumber__c> phonesNumbersChanged = new List<PhoneNumber__c>();
        for (PhoneNumber__c pn : (List<PhoneNumber__c>)Trigger.new){
            if(!Trigger.new.isEmpty()) {
                if(PhoneValuesAreChanged(pn)) {
                    phonesNumbersChanged.add(pn);
                }
            }
        }
        PhoneNumberTriggerHelper.PhoneNumberRunway(phonesNumbersChanged);

//        PhoneNumberTriggerHelper.RecordPicker recordPicker = new PhoneNumberTriggerHelper.RecordPicker((List<PhoneNumber__c>)Trigger.new);
//        PhoneNumberTriggerHelper.ContactLooper contactLooper = new PhoneNumberTriggerHelper.ContactLooper(recordPicker.contacts,recordPicker.PhoneStatusMap,recordPicker.PhoneFlagMap);
//        PhoneNumberTriggerHelper.LeadLooper leadLooper = new PhoneNumberTriggerHelper.LeadLooper(recordPicker.leads,recordPicker.PhoneStatusMap,recordPicker.PhoneFlagMap);
//        if(contactLooper.updateContacts.size() > 0){
//            update contactLooper.updateContacts;
//        }
//        if(leadLooper.updateLeads.size() > 0){
//            update leadLooper.updateLeads;
//        }
    }

    private static Boolean PhoneValuesAreChanged(PhoneNumber__c phoneNumber){
        Boolean ValuesAreChanged = false;
        PhoneNumber__c oldPhoneNumber = (PhoneNumber__c)Trigger.oldMap.get(phoneNumber.Id);
        if(phoneNumber.Disconnected__c != oldPhoneNumber.Disconnected__c){
            ValuesAreChanged = true;
        } else if(phoneNumber.Do_Not_Call__c != oldPhoneNumber.Do_Not_Call__c) {
            ValuesAreChanged = true;
        }
        return ValuesAreChanged;
    }
}