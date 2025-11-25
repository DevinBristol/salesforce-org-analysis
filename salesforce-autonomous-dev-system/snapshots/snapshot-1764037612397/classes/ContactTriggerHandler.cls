///**
// * Created by Devin on 6/7/2024.
// */
//
public with sharing class ContactTriggerHandler extends TriggerHandler{
    public override void beforeInsert(){
        List<Contact> PhoneDeformatableContacts = new List<Contact>();
        for(Contact c : (List<Contact>)Trigger.new){
            if(ContactTriggerHelper.PhoneIsDeformatable(c)){
                PhoneDeformatableContacts.add(c);
            }
        }
        ContactTriggerHelper.DeformatContactNumbers(PhoneDeformatableContacts);
    }
    public override void afterInsert(){
        List<List<SObject>> recordLists = ContactTriggerHelper.pickRecords((List<Contact>)Trigger.new);
        List<Account> accountsNameable = NamingUtility.NameAccount(recordLists[2]);
        PhoneRelationHandler.HandlePhonesFromContacts(recordLists[3]);
        update accountsNameable;
    }
    public override void beforeUpdate(){
        List<List<SObject>> recordLists = ContactTriggerHelper.pickRecords((List<Contact>)Trigger.new);
        ContactTriggerHelper.DeformatContactNumbers(recordLists[4]);
    }
    public override void afterUpdate(){
        List<List<SObject>> recordLists = ContactTriggerHelper.pickRecords((List<Contact>)Trigger.new);
        List<Account> accountsNameable = NamingUtility.NameAccount(recordLists[2]);
        if(recordLists[3].size()>0){
            PhoneRelationHandler.HandlePhonesFromContacts(recordLists[3]);
        }
        update accountsNameable;
    }
    public override void afterDelete(){
        List<List<SObject>> recordLists = ContactTriggerHelper.pickRecords((List<Contact>)Trigger.old);
        List<Account> accountsNameable = NamingUtility.NameAccount(recordLists[2]);
        PhoneRelationHandler.HandlePhonesFromContacts(recordLists[3]);
        update accountsNameable;
    }
}