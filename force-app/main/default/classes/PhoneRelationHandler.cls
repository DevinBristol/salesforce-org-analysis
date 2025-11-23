/**
 * Created by Devin on 6/17/2024.
 */

public with sharing class PhoneRelationHandler {

    public static void HandlePhonesFromLeads(List<Lead> leads){
        Set<String> PhoneValues = new Set<String>(PhoneRelationHelper.getPhoneValues(leads));
        List<List<SObject>> Records = new List<List<SObject>>(PhoneRelationHelper.getRecords(PhoneValues));
        PhoneRelationHelper.HandlePPRs(Records);
//        PhoneNumberTriggerHelper.PhoneNumberRunway(Records[2]);
    }

    public static void HandlePhonesFromContacts(List<Contact> contacts){
        System.debug('PhoneRelationHandler ::: ' + contacts);
        Set<String> PhoneValues = new Set<String>(PhoneRelationHelper.getPhoneValues(contacts));
        List<List<SObject>> Records = new List<List<SObject>>(PhoneRelationHelper.getRecords(PhoneValues));
        PhoneRelationHelper.HandlePPRs(Records);
//        PhoneNumberTriggerHelper.PhoneNumberRunway(Records[2]);
    }

}