/**
 * Created by Devin on 6/17/2024.
 */

public with sharing class PhoneRelationHelper {

    public static List<List<SObject>> getRecords(Set<String> PhoneValues){
        System.debug('PhoneRelationHelper : getRecords : PhoneValues :::' + PhoneValues);
        PhoneValues.remove('');
        PhoneValues.remove(' ');
        PhoneValues.remove(null);
        List<List<SObject>> returnRecords = new List<List<SObject>>();
        List<Lead> returnLeads = new List<Lead>(getLeads(PhoneValues));
        List<Contact> returnContacts = new List<Contact>(getContacts(PhoneValues));
        List<PhoneNumber__c> ExistingPhoneNumbers = new List<PhoneNumber__c>(getPhones(PhoneValues));
        List<PhoneNumber__c> returnPhoneNumbers = new List<PhoneNumber__c>(CreateNonExistingPhoneNumbers(PhoneValues,ExistingPhoneNumbers));

        returnRecords.add(returnLeads);
        returnRecords.add(returnContacts);
        returnRecords.add(returnPhoneNumbers);
        System.debug('PhoneRelationHelper : getRecords : returnRecords :::' + returnRecords);
        return returnRecords;
    }

    public static void HandlePPRs(List<List<SObject>> Records){
        Set<PhonePersonRelationship__c> PPRsDeletable = new Set<PhonePersonRelationship__c>();
        Set<PhonePersonRelationship__c> PPRsCreatable = new Set<PhonePersonRelationship__c>();
        Set<PhonePersonRelationship__c> PPRsExisting = new Set<PhonePersonRelationship__c>();
        List<PhonePersonRelationship__c> PPRsRemaining = new List<PhonePersonRelationship__c>();
        Map<Id,List<String>> PersonPhonesUnrelatable = new Map<Id,List<String>>();

        List<Lead> leads = new List<Lead>((List<Lead>)Records[0]);
        List<Contact> contacts = new List<Contact>((List<Contact>)Records[1]);
        List<PhoneNumber__c> phoneNumbers = new List<PhoneNumber__c>((List<PhoneNumber__c>)Records[2]);
        Map<String,Id> PhoneMap = new Map<String,Id>(makePhoneMap(phoneNumbers));
        System.debug('PhoneRelationHelper Leads being updated::: ' + leads);
        System.debug('PhoneRelationHelper PhoneNumbers being updated::: ' + phoneNumbers);
        System.debug(PhoneMap.keySet());

        for(PhoneNumber__c p : phoneNumbers){
            for(PhonePersonRelationship__c ppr : p.Phonenumbers2Individuals__r){
                if(ppr.Contact__c == null && ppr.Lead__c == null){
                    PPRsDeletable.add(ppr);
                }
                PPRsExisting.add(ppr);
            }
        }
        if(leads.size() > 0) {
            for (Lead l : leads) {
                Set<String> phones = new Set<String>(makePhoneValuesLead(l));
                Set<String> PPRExistingNames = new Set<String>();
                // Make PPRs Deletable and add Existing PPRs to PPRExistingNames
                for (PhonePersonRelationship__c ppr : l.Phone2LeadRelationship__r) {
                    // if another ppr with the same PhoneNumber.Name is found on second loop it will be a duplicate and added to delete list
                    if(PPRExistingNames.contains(ppr.Phonenumber__r.Name)){
                        PPRsDeletable.add(ppr);
                    }
                    if(!phones.contains(ppr.Phonenumber__r.Name)) {
                        PPRsDeletable.add(ppr);
                    }
                    PPRExistingNames.add(ppr.Phonenumber__r.Name);
                }
                // Make PPRs Creatable
                for (String s : phones) {
                    if(!PPRExistingNames.contains(s)) {
                        if(PhoneMap.get(s) != null){
                            PhonePersonRelationship__c pprNew = new PhonePersonRelationship__c(Lead__c = l.Id, Phonenumber__c = PhoneMap.get(s));
                            PPRsCreatable.add(pprNew);
                        } else {
                            if(PersonPhonesUnrelatable.get(l.Id) == null){
                                PersonPhonesUnrelatable.put(l.Id,new List<String>{s});
                            } else {
                                PersonPhonesUnrelatable.get(l.Id).add(s);
                            }
                        }
                    }
                }
            }
        }
        if(contacts.size() > 0){
            for (Contact c : contacts){
                Set<String> phones = new Set<String>(makePhoneValuesContact(c));
                Set<String> PPRExistingNames = new Set<String>();
                // Make PPRs Deletable and add Existing PPRs to PPRExistingNames
                for (PhonePersonRelationship__c ppr : c.Phone2ContactRelationship__r) {
                    if(PPRExistingNames.contains(ppr.Phonenumber__r.Name)){
                        PPRsDeletable.add(ppr);
                    }
                    if(!phones.contains(ppr.Phonenumber__r.Name)) {
                        PPRsDeletable.add(ppr);
                    }
                    PPRExistingNames.add(ppr.Phonenumber__r.Name);
                }
                // Make PPRs Creatable
                for (String s : phones) {
                    if(!PPRExistingNames.contains(s)) {
                        if(PhoneMap.get(s) != null){
                            PhonePersonRelationship__c pprNew = new PhonePersonRelationship__c(Contact__c = c.Id, Phonenumber__c = PhoneMap.get(s));
                            PPRsCreatable.add(pprNew);
                        } else {
                            if(PersonPhonesUnrelatable.get(c.Id) == null){
                                PersonPhonesUnrelatable.put(c.Id,new List<String>{s});
                            } else {
                                PersonPhonesUnrelatable.get(c.Id).add(s);
                            }
                        }
                    }
                }
            }
        }
        List<PhonePersonRelationship__c> InsertPPRs = new List<PhonePersonRelationship__c>();
        InsertPPRs.addAll(PPRsCreatable);
        System.debug(PPRsCreatable);
        List<PhonePersonRelationship__c> DeletePPRs = new List<PhonePersonRelationship__c>();
        DeletePPRs.addAll(PPRsDeletable);
        System.debug(JSON.serializePretty(InsertPPRs));

        insert InsertPPRs;
        delete DeletePPRs;

        PPRsRemaining = [SELECT Id,Phonenumber__r.Name FROM PhonePersonRelationship__c WHERE Phonenumber__r.Name IN :PhoneMap.keySet()];

        if(PPRsRemaining.size() > 0){
            Set<String> FlaggedPhoneStrings = MakePhoneFlags(PPRsRemaining);
            Set<Lead> UpdatableLeads = new Set<Lead>();
            Set<Contact> UpdateableContacts = new Set<Contact>();

            if(leads.size() > 0){
                for (Lead l : leads){
                    Boolean LeadIsUpdateable = false;
                    Set<String> phones = new Set<String>(makePhoneValuesLead(l));
                    Set<String> phonesRemovingFlaggedPhones = new Set<String>(phones);
                    phonesRemovingFlaggedPhones.removeAll(FlaggedPhoneStrings);
                    if(phonesRemovingFlaggedPhones.size() != phones.size()){
                        l.Flagged__c = true;
                        LeadIsUpdateable = true;
                    }
                    else if(l.Flagged__c == true){
                        l.Flagged__c = false;
                        LeadIsUpdateable = true;
                    }
                    if(LeadIsUpdateable == true) {
                        UpdatableLeads.add(l);
                    }
                }
            }

            if(contacts.size() > 0){
                for (Contact c : contacts){
                    Boolean ContactIsUpdateable = false;
                    Set<String> phones = new Set<String>(makePhoneValuesContact(c));
                    Set<String> phonesRemovingFlaggedPhones = new Set<String>(phones);
                    phonesRemovingFlaggedPhones.removeAll(FlaggedPhoneStrings);
                    if(phonesRemovingFlaggedPhones.size() != phones.size()){
                        c.Flagged__c = true;
                        ContactIsUpdateable = true;
                    }
                    else if(c.Flagged__c == true){
                        c.Flagged__c = false;
                        ContactIsUpdateable = true;
                    }
                    if(ContactIsUpdateable == true) {
                        UpdateableContacts.add(c);
                    }
                }
            }

            List<Contact> UpdateableContactList = new List<Contact>(UpdateableContacts);
            List<Lead> UpdateableLeadList = new List<Lead>(UpdatableLeads);
            System.debug(UpdateableLeadList);

            update UpdateableContactList;
            update UpdateableLeadList;
        }
    }

    public static Set<String> MakePhoneFlags(List<PhonePersonRelationship__c> PPRsRemaining){
        Set<String> PhoneStringsAlreadyLooped = new Set<String>();
        Set<String> PhoneStringsToFlag = new Set<String>();
        for(PhonePersonRelationship__c ppr : PPRsRemaining){
            if(PhoneStringsAlreadyLooped.contains(ppr.Phonenumber__r.Name)){
                PhoneStringsToFlag.add(ppr.Phonenumber__r.Name);
            }
            PhoneStringsAlreadyLooped.add(ppr.Phonenumber__r.Name);
        }
        return PhoneStringsToFlag;
    }

    public static Set<String> getPhoneValues(List<Lead> leads){
        Set<String> PhoneValues = new Set<String>();

        for(Lead l : leads){
            if(Trigger.isExecuting && Trigger.isUpdate){
                Lead oldLead = (Lead)Trigger.oldMap.get(l.Id);
                if(oldLead.MobilePhone != null){
                    PhoneValues.add(oldLead.MobilePhone);
                }
                if(oldLead.Phone != null){
                    PhoneValues.add(oldLead.Phone);
                }
                if(oldLead.Secondary_Contact_Mobile__c != null){
                    PhoneValues.add(oldLead.Secondary_Contact_Mobile__c);
                }
            }
            if(l.MobilePhone != null){
                PhoneValues.add(l.MobilePhone);
            }
            if(l.Phone != null){
                PhoneValues.add(l.Phone);
            }
            if(l.Secondary_Contact_Mobile__c != null){
                PhoneValues.add(l.Secondary_Contact_Mobile__c);
            }
        }
        System.debug('PhoneRelationHelper : PhoneValues ::: ' + PhoneValues);
        System.debug('Contains Needed Value 4027912672 ' + PhoneValues.contains('4027912672').toString());
        System.debug('Contains Needed Value 4025400366 ' + PhoneValues.contains('4025400366').toString());
        return PhoneValues;
    }
    public static Set<String> getPhoneValues(List<Contact> contacts){
        Set<String> PhoneValues = new Set<String>();
        for(Contact c : contacts){
            if(Trigger.isExecuting && Trigger.isUpdate){
                Contact oldContact = (Contact)Trigger.oldMap.get(c.Id);
                if(oldContact.MobilePhone != null){
                    PhoneValues.add(oldContact.MobilePhone);
                }
                if(oldContact.Phone != null){
                    PhoneValues.add(oldContact.Phone);
                }
                if(oldContact.HomePhone != null){
                    PhoneValues.add(oldContact.HomePhone);
                }
            }
            if(c.MobilePhone != null){
                PhoneValues.add(c.MobilePhone);
            }
            if(c.Phone != null){
                PhoneValues.add(c.Phone);
            }
            if(c.HomePhone != null){
                PhoneValues.add(c.HomePhone);
            }
        }
        return PhoneValues;
    }
    private static List<PhoneNumber__c> CreateNonExistingPhoneNumbers(Set<String> PhoneValues, List<PhoneNumber__c> PhonesExisting){
        List<PhoneNumber__c> returnPhoneNumbers = new List<PhoneNumber__c>();
        Set<String> PhoneValuesExisting = new Set<String>();
        List<PhoneNumber__c> PhonesCreatable = new List<PhoneNumber__c>();

        for(PhoneNumber__c p : PhonesExisting){
            PhoneValuesExisting.add(p.Name);
        }

        for(String s : PhoneValues){
            if(!PhoneValuesExisting.contains(s)){
                PhoneNumber__c newPhoneNumber = new PhoneNumber__c(Name=s);
                PhonesCreatable.add(newPhoneNumber);
            }
        }

        insert PhonesCreatable;

        returnPhoneNumbers.addAll(PhonesExisting);
        returnPhoneNumbers.addAll(PhonesCreatable);

        return returnPhoneNumbers;
    }

    private static Map<String,Id> makePhoneMap(List<PhoneNumber__c> phoneNumbers){
        Map<String,Id> phoneMap = new Map<String,Id>();
        for(PhoneNumber__c p : phoneNumbers){
            phoneMap.put(p.Name,p.Id);
        }
        return phoneMap;
    }

    private static Set<String> makePhoneValuesLead(Lead l){
        Set<String> returnPhoneValues = new Set<String>();
        if(l.MobilePhone != null){
            returnPhoneValues.add(l.MobilePhone);
        }
        if(l.Phone != null){
            returnPhoneValues.add(l.Phone);
        }
        if(l.Secondary_Contact_Mobile__c != null){
            returnPhoneValues.add(l.Secondary_Contact_Mobile__c);
        }
        return returnPhoneValues;
    }

    private static Set<String> makePhoneValuesContact(Contact c){
        Set<String> returnPhoneValues = new Set<String>();
        if(c.MobilePhone != null){
            returnPhoneValues.add(c.MobilePhone);
        }
        if(c.Phone != null){
            returnPhoneValues.add(c.Phone);
        }
        if(c.HomePhone != null){
            returnPhoneValues.add(c.HomePhone);
        }
        return returnPhoneValues;
    }

    // Selectors
    private static List<Lead> getLeads(Set<String> PhoneValues){
        PhoneValues.remove('');
        PhoneValues.remove(null);
        List<Lead> returnLeads = new List<Lead>();
        Set<Id> QueryIds = MakeQueryIds();
        returnLeads.addAll([SELECT Id,MobilePhone,Phone,Secondary_Contact_Mobile__c,Flagged__c, (SELECT Id,Lead__c,Contact__c,Phonenumber__r.Name FROM Phone2LeadRelationship__r) FROM Lead WHERE (Phone IN :PhoneValues OR MobilePhone IN :PhoneValues OR Secondary_Contact_Mobile__c IN :PhoneValues OR Id IN :QueryIds)]);
        return returnLeads;
    }

    private static List<Contact> getContacts(Set<String> PhoneValues){
        PhoneValues.remove('');
        PhoneValues.remove(null);
        List<Contact> returnContacts = new List<Contact>();
        Set<Id> QueryIds = MakeQueryIds();
        returnContacts.addAll([SELECT Id,MobilePhone,Phone,HomePhone,Flagged__c, (SELECT Id, Lead__c, Contact__c, Phonenumber__r.Name FROM Phone2ContactRelationship__r) FROM Contact WHERE Phone IN :PhoneValues OR MobilePhone IN :PhoneValues OR HomePhone IN :PhoneValues OR Id IN :QueryIds]);
        return returnContacts;
    }

    private static Set<Id> MakeQueryIds(){
        Set<Id> QueryIds = new Set<Id>();
        if(Trigger.isExecuting){
            if(!Trigger.isDelete){
                for(SObject sObj : Trigger.new){
                    if(Trigger.isInsert){
                        QueryIds.add(sObj.Id);
                    } else if(sObj.getSObjectType() == Contact.SObjectType){
                        if(isContactPhonesChanged((Contact)sObj)){
                            QueryIds.add(sObj.Id);
                        }
                    } else {
                        if(isLeadPhonesChanged((Lead)sObj)){
                            QueryIds.add(sObj.Id);
                        }
                    }
                }
            } else {
                QueryIds = Trigger.oldMap.keySet();
            }
        } else {
            QueryIds.clear();
        }
        return QueryIds;
    }
    private static Boolean isContactPhonesChanged(Contact c){
        Boolean isChanged;
        Contact oldContact = (Contact)Trigger.oldMap.get(c.Id);
        if(c.MobilePhone != oldContact.MobilePhone) {
            isChanged = true;
        } else if(c.Phone != oldContact.Phone){
            isChanged = true;
        } else if(c.HomePhone != oldContact.HomePhone){
            isChanged = true;
        } else {
            isChanged = false;
        }

        return isChanged;
    }
    private static Boolean isLeadPhonesChanged(Lead l){
        Boolean isChanged;
        Lead oldLead = (Lead)Trigger.oldMap.get(l.Id);
        if(l.MobilePhone != oldLead.MobilePhone) {
            isChanged = true;
        } else if(l.Phone != oldLead.Phone){
            isChanged = true;
        } else if(l.Secondary_Contact_Mobile__c != oldLead.Secondary_Contact_Mobile__c){
            isChanged = true;
        } else {
            isChanged = false;
        }
        return isChanged;
    }
    private static List<PhoneNumber__c> getPhones(Set<String> PhoneValues){
        PhoneValues.remove('');
        PhoneValues.remove(null);
        List<PhoneNumber__c> returnPhones = new List<PhoneNumber__c>([SELECT Id,Name,Do_Not_Call__c,Disconnected__c, (SELECT Id,Contact__c,Lead__c,Phonenumber__c FROM Phonenumbers2Individuals__r) FROM PhoneNumber__c WHERE Name IN :PhoneValues]);
        return returnPhones;
    }
}