/**
 * Created by Devin on 6/13/2024.
 */

public with sharing class ContactTriggerHelper {

    public static Boolean PhoneIsDeformatable(Contact c){
        Boolean isDeformatable;
        if(c.MobilePhone != null && c.MobilePhone.containsAny('[^0-9]') || c.Phone != null && (c.Phone.containsAny('[^0-9]') || c.Phone.startsWith('1')) || c.HomePhone != null && (c.HomePhone.containsAny('[^0-9]')||c.HomePhone.startsWith('1'))){
            isDeformatable = true;
        } else {
            isDeformatable = false;
        }
        return isDeformatable;
    }

    public static List<List<SObject>> pickRecords(List<Contact> contacts) {

        List<List<SObject>> returnLists = new List<List<SObject>>();
        List<SObject> opportunitiesNameable = new List<SObject>();
        List<SObject> contactsNameable = new List<SObject>();
        List<SObject> accountsNameable = new List<SObject>();
        List<Contact> contactsPhoneRelations = new List<Contact>();
        List<Contact> contactsPhoneFormat = new List<Contact>();

        if(Trigger.isInsert && Trigger.isBefore){
            for(Contact c : contacts){
                if(c.MobilePhone != null && c.MobilePhone.containsAny('[^0-9]') || c.Phone != null && (c.Phone.containsAny('[^0-9]') || c.Phone.startsWith('1')) || c.HomePhone != null && (c.HomePhone.containsAny('[^0-9]')||c.HomePhone.startsWith('1'))){
                    contactsPhoneFormat.add(c);
                }
            }
        }
        if(Trigger.isInsert && Trigger.isAfter) {
            for (Contact c : contacts) {
                Account acc = new Account(Id = c.AccountId);
                accountsNameable.add((SObject)acc);
            }
            contactsPhoneRelations.addAll(contacts);
        }
        if(Trigger.isUpdate && Trigger.isBefore){
            for(Contact c : contacts){
                if(c.MobilePhone != null && c.MobilePhone.containsAny('[^0-9]') || c.Phone != null && (c.Phone.containsAny('[^0-9]') || c.Phone.startsWith('1')) || c.HomePhone != null && (c.HomePhone.containsAny('[^0-9]')||c.HomePhone.startsWith('1'))){
                    contactsPhoneFormat.add(c);
                }
            }
        }
        if(Trigger.isUpdate && Trigger.isAfter) {
            for(Contact c : contacts){
                Contact oldContact = (Contact)Trigger.oldMap.get(c.Id);
                if((c.FirstName != oldContact.FirstName) || (c.LastName != oldContact.LastName)){
                    Account acc = new Account(Id = c.AccountId);
                    accountsNameable.add((SObject)acc);
                }
                if((c.AccountId != oldContact.AccountId)){
                    Account accAfter = new Account(Id = c.AccountId);
                    Account accBefore = new Account(Id = oldContact.AccountId);
                    accountsNameable.add((SObject)accAfter);
                    accountsNameable.add((SObject)accBefore);
                }
                if(c.MobilePhone != oldContact.MobilePhone || c.Phone != oldContact.Phone || c.HomePhone != oldContact.HomePhone){
                    contactsPhoneRelations.add(c);
                }
            }
        }
        if(Trigger.isAfter && Trigger.isDelete){
            for(Contact c : contacts){
                Account accBefore = new Account(Id = c.AccountId);
                accountsNameable.add((SObject)accBefore);
            }
            contactsPhoneRelations.addAll(contacts);
        }
        returnLists.add(contactsNameable);
        returnLists.add(opportunitiesNameable);
        returnLists.add(accountsNameable);
        returnLists.add(contactsPhoneRelations);
        returnLists.add(contactsPhoneFormat);
        return returnLists;
    }

    public static List<Contact> DeformatContactNumbers(List<Contact> contacts){

        List<Contact> returnContacts = new List<Contact>();

        for(Contact c : contacts){
            if(c.MobilePhone != null && (c.MobilePhone.containsAny('[^0-9]') || c.MobilePhone.startsWith('1'))){
                c.MobilePhone = PhoneNumberService.DeformatPhone(c.MobilePhone);
            }
            if(c.Phone != null && (c.Phone.containsAny('[^0-9]') || c.Phone.startsWith('1'))){
                c.Phone = PhoneNumberService.DeformatPhone(c.Phone);
            }
            if(c.HomePhone != null && (c.HomePhone.containsAny('[^0-9]')||c.HomePhone.startsWith('1'))){
                c.HomePhone = PhoneNumberService.DeformatPhone(c.HomePhone);
            }
        }
        return returnContacts;
    }

}