/**
 * Created by Devin on 7/5/2024.
 */

public with sharing class PhoneNumberTriggerHelper {

    public static void PhoneNumberRunway(List<PhoneNumber__c> PhoneNumbers){
        PhoneNumberTriggerHelper.RecordPicker recordPicker = new PhoneNumberTriggerHelper.RecordPicker(PhoneNumbers);
        PhoneNumberTriggerHelper.ContactLooper contactLooper = new PhoneNumberTriggerHelper.ContactLooper(recordPicker.contacts,recordPicker.PhoneStatusMap,recordPicker.PhoneFlagMap);
        PhoneNumberTriggerHelper.LeadLooper leadLooper = new PhoneNumberTriggerHelper.LeadLooper(recordPicker.leads,recordPicker.PhoneStatusMap,recordPicker.PhoneFlagMap);

        if(contactLooper.updateContacts.size() > 0){
            update contactLooper.updateContacts;
        }
        if(leadLooper.updateLeads.size() > 0){
            System.debug(leadLooper.updateLeads);
            update leadLooper.updateLeads;
        }
    }
    public class RecordPicker{
        public RecordPicker(List<PhoneNumber__c> PhoneNumbers){
            System.debug('PhoneNumberTriggerHelper : PhoneNumbers ::: ' + PhoneNumbers);
            PhoneStatusMap = new Map<String,String>();
            PhoneFlagMap = new Map<String,Boolean>();
            leads = new List<Lead>();
            contacts = new List<Contact>();
            List<String> AllPhoneNames = new List<String>();

            for(PhoneNumber__c p : PhoneNumbers){
                AllPhoneNames.add(p.Name);
                if(p.Do_Not_Call__c == true){
                    PhoneStatusMap.put(p.Name,'DoNotCall');
                }
                else if(p.Disconnected__c == true){
                    PhoneStatusMap.put(p.Name,'Disconnected');
                }
            }
            leads = [SELECT Id, MobilePhone,Phone,Secondary_Contact_Mobile__c,Bad_Phone_History__c FROM Lead WHERE MobilePhone IN :AllPhoneNames OR Phone IN :AllPhoneNames OR Secondary_Contact_Mobile__c IN :AllPhoneNames];
            contacts = [SELECT Id,MobilePhone,Phone,HomePhone,Bad_Phone_History__c FROM Contact WHERE MobilePhone IN :AllPhoneNames OR Phone IN :AllPhoneNames OR HomePhone IN :AllPhoneNames];

        }
        public Map<String,String> PhoneStatusMap { get; set; }
        public List<Lead> leads { get; set; }
        public List<Contact> contacts { get; set; }
        public Map<String,Boolean> PhoneFlagMap { get; set; }
    }

    public class ContactLooper{
        public ContactLooper(List<Contact> contacts, Map<String,String> PhoneStatusMap, Map<String,Boolean> PhoneFlagMap){
            updateContacts = new List<Contact>();
            for(Contact c : contacts){
                Boolean ContactUpdatable = false;
                if(c.MobilePhone != null){
                    if(PhoneStatusMap.get(c.MobilePhone) == 'Disconnected'){
                        c.Bad_Phone_History__c = 'Disconnected : '+ c.MobilePhone +' -- ' + System.Datetime.now() + ', ' + '\r\n' + c.Bad_Phone_History__c;
                        c.Bad_Phone_History__c = c.Bad_Phone_History__c.remove('null, ');
                        ContactUpdatable = true;
                    }
                }
                if(c.Phone != null){
                    if(PhoneStatusMap.get(c.Phone) == 'Disconnected'){
                        c.Bad_Phone_History__c = 'Disconnected : '+ c.Phone +' -- ' + System.Datetime.now() + ', ' + '\r\n' + c.Bad_Phone_History__c;
                        c.Bad_Phone_History__c = c.Bad_Phone_History__c.remove('null, ');
                        ContactUpdatable = true;
                    }
                }
                if(c.HomePhone != null){
                    if(PhoneStatusMap.get(c.HomePhone) == 'Disconnected'){
                        c.Bad_Phone_History__c = 'Disconnected : '+ c.HomePhone +' -- ' + System.Datetime.now() + ', ' + '\r\n' + c.Bad_Phone_History__c;
                        c.Bad_Phone_History__c = c.Bad_Phone_History__c.remove('null, ');
                        ContactUpdatable = true;
                    }
                }
                if(ContactUpdatable == true){
                    updateContacts.add(c);
                }
            }
        }
        public List<Contact> updateContacts { get; set; }
    }

    public class LeadLooper{
        public LeadLooper(List<Lead> leads, Map<String,String> PhoneStatusMap,Map<String,Boolean> PhoneFlagMap){
            updateLeads = new List<Lead>();
            for(Lead l : leads){
                Boolean LeadIsUpdatable = false;
                if(l.MobilePhone != null){
                    if(PhoneStatusMap.get(l.MobilePhone) == 'Disconnected' || PhoneStatusMap.get(l.MobilePhone) == 'DoNotCall'){
                        l.Bad_Phone_History__c = PhoneStatusMap.get(l.MobilePhone)+ ' : '+ l.MobilePhone +' -- ' + System.Datetime.now() + ', ' + '\r\n' + l.Bad_Phone_History__c;
                        l.Bad_Phone_History__c = l.Bad_Phone_History__c.remove('null, ');
                        l.Flagged__c = true;
                        LeadIsUpdatable = true;
                    }
                }
                if(l.Phone != null){
                    if(PhoneStatusMap.get(l.Phone) == 'Disconnected' || PhoneStatusMap.get(l.Phone) == 'DoNotCall'){
                        l.Bad_Phone_History__c = PhoneStatusMap.get(l.Phone) + ' : '+ l.Phone +' -- ' + System.Datetime.now() + ', ' + '\r\n' + l.Bad_Phone_History__c;
                        l.Bad_Phone_History__c = l.Bad_Phone_History__c.remove('null, ');
                        l.Flagged__c = true;
                        LeadIsUpdatable = true;
                    }
                }
                if(l.Secondary_Contact_Mobile__c != null){
                    if(PhoneStatusMap.get(l.Secondary_Contact_Mobile__c) == 'Disconnected' || PhoneStatusMap.get(l.Secondary_Contact_Mobile__c) == 'DoNotCall'){
                        l.Bad_Phone_History__c = PhoneStatusMap.get(l.Secondary_Contact_Mobile__c) + ' : '+ l.Secondary_Contact_Mobile__c +' -- ' + System.Datetime.now() + ', ' + '\r\n' + l.Bad_Phone_History__c;
                        l.Bad_Phone_History__c = l.Bad_Phone_History__c.remove('null, ');
                        l.Flagged__c = true;
                        LeadIsUpdatable = true;
                    }
                }
                if(LeadIsUpdatable){
                    updateLeads.add(l);
                }
            }
        }
        public List<Lead> updateLeads { get; set; }
    }

}