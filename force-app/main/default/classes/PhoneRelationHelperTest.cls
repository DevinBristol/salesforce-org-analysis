/**
 * Created by brist on 8/7/2024.
 */
@IsTest
public with sharing class PhoneRelationHelperTest {
    @TestSetup
    static void makeTestData() {
        List<PhoneNumber__c> phnmbs = new List<PhoneNumber__c>(); // doing the [c/l]Ph99 ones only : testing the existing phoneNumber list
//        for(Integer i = 0; i > 9; i++){
//            PhoneNumber__c lPh = new PhoneNumber__c(Name='100000000'+i);
//            PhoneNumber__c cPh = new PhoneNumber__c(Name='200000000'+i);
//            phnmbs.add(lPh);
//            phnmbs.add(cPh);
//        }

        PhoneNumber__c lPh99 = new PhoneNumber__c(Name = '9870000099');
        phnmbs.add(lPh99);
        PhoneNumber__c cPh99 = new PhoneNumber__c(Name = '2340000099');
        phnmbs.add(cPh99);

        insert phnmbs;

        List<PhonePersonRelationship__c> pprs = new List<PhonePersonRelationship__c>();

        Lead l1 = new Lead(FirstName = 'l1', LastName = '1l', Company = '1l, l1', Status = 'Open', MobilePhone = '9870000000', Phone = '9870000001', Secondary_Contact_Mobile__c = '9870000002'); //full record
        Lead l2 = new Lead(FirstName = 'l2', LastName = '2l', Company = '2l, l2', Status = 'Open', MobilePhone = '9870000003', Phone = '9870000004'); //null 2ndaryContactMobile
        Lead l3 = new Lead(FirstName = 'l3', LastName = '3l', Company = '3l, l3', Status = 'Open', MobilePhone = '9870000005', Secondary_Contact_Mobile__c = '9870000006'); //null Phone
        Lead l4 = new Lead(FirstName = 'l4', LastName = '4l', Company = '4l, l4', Status = 'Open', Phone = '9870000007',Secondary_Contact_Mobile__c='9870000008'); //null MobilePhone
        Lead l5 = new Lead(FirstName = 'l5', LastName = '5l', Company = '5l, l5', Status = 'Open', MobilePhone = '9870000000'); //match within object lead
        Lead l6 = new Lead(FirstName = 'l6', LastName = '6l', Company = '6l, l6', Status = 'Open'); //no numbers
        Lead l7 = new Lead(FirstName = 'l7', LastName = '7l', Company = '7l, l7', Status = 'Open', MobilePhone = '9870000010', Phone = '9870000010'); //match within record
        Lead l8 = new Lead(FirstName = 'l8', LastName = '8l', Company = '8l, l8', Status = 'Open', MobilePhone = '9870000099'); //match w/ existing phoneNumber record
        insert new List<Lead>{ l1, l2, l3, l4, l5, l6, l7, l8 };
        insert new PhonePersonRelationship__c(Phonenumber__c = lPh99.Id, Lead__c = l8.Id);

        Contact c1 = new Contact(FirstName = 'c1', LastName = '1c', MobilePhone = '2340000000', HomePhone = '2340000001', Phone = '2340000002');//full record
        Contact c2 = new Contact(FirstName = 'c2', LastName = '2c', MobilePhone = '2340000003', HomePhone = '2340000004'); //null Phone
        Contact c3 = new Contact(FirstName = 'c3', LastName = '3c', MobilePhone = '2340000005', Phone = '2340000006'); //null HomePhone
        Contact c4 = new Contact(FirstName = 'c4', LastName = '4c', HomePhone = '2340000007', Phone = '2340000008'); //null MobilePhone
        Contact c5 = new Contact(FirstName = 'c5', LastName = '5c', MobilePhone = '2340000000'); //match within object Contact
        Contact c6 = new Contact(FirstName = 'c6', LastName = '6c'); //no numbers
        Contact c7 = new Contact(FirstName = 'c7', LastName = '7c', MobilePhone = '2340000010', HomePhone = '2340000010'); //match within record
        Contact c8 = new Contact(FirstName = 'c8', LastName = '8c', MobilePhone = '2340000099'); //match w/ existing phoneNumber record
        insert new List<Contact>{ c1, c2, c3, c4, c5, c6, c7, c8};
        insert new PhonePersonRelationship__c(Phonenumber__c = cPh99.Id, Contact__c = c8.Id);
    }
    @IsTest
    static void testGetRecords() {
        // Prepare the set of phone values
        Set<String> phoneValues = new Set<String>();
        Set<String> lPhoneValues = new Set<String>{'9870000000','9870000001','9870000002','9870000003','9870000004','9870000005','9870000006','9870000007','9870000008','9870000010','9870000099'};
        Set<String> cPhoneValues = new Set<String>{'2340000000','2340000001','2340000002','2340000003','2340000004','2340000005','2340000006','2340000007','2340000008','2340000010','2340000099'};
        phoneValues.addAll(lPhoneValues);
        phoneValues.addAll(cPhoneValues);

        Set<String> phoneValsEval = new Set<String>();
        //// do the getRecords Method
        List<Lead> leads = [SELECT Id, Name, MobilePhone, Phone, Secondary_Contact_Mobile__c FROM Lead WHERE FirstName LIKE 'l_'];
        List<Contact> contacts = [SELECT Id, Name, MobilePhone, HomePhone, Phone FROM Contact WHERE FirstName LIKE 'c_'];
        for(Integer i = 0; i>leads.size(); i++){
            if(leads[i].MobilePhone != null){
                phoneValsEval.add(leads[i].MobilePhone);
            }
            if(leads[i].Phone != null){
                phoneValsEval.add(leads[i].Phone);
            }
            if(leads[i].Secondary_Contact_Mobile__c != null){
                phoneValsEval.add(leads[i].Secondary_Contact_Mobile__c);
            }
            if(contacts[i].MobilePhone != null){
                phoneValsEval.add(contacts[i].MobilePhone);
            }
            if(contacts[i].HomePhone != null){
                phoneValsEval.add(contacts[i].HomePhone);
            }
            if(contacts[i].Phone != null){
                phoneValsEval.add(contacts[i].Phone);
            }
            System.debug('phoneValsEval String Set for Iteration '+ i +'::: '+ phoneValsEval);
        }
//        System.assertEquals(phoneValsEval,phoneValues);
        List<PhoneNumber__c> phoneNumbers = [SELECT Id, Name FROM PhoneNumber__c WHERE Name IN :phoneValues];
        System.debug('returned phonenumbers from Setup::: '+phoneNumbers);
        System.debug('returned leads from Setup::: '+leads);
        List<Lead> qLeads = [SELECT Id, Name, MobilePhone, Phone, Secondary_Contact_Mobile__c FROM Lead WHERE FirstName LIKE 'l_'];
        List<Contact> qContacts = [SELECT Id, Name, MobilePhone, HomePhone, Phone FROM Contact WHERE FirstName LIKE 'c_'];
        System.debug('l1 phonefields::: '+qLeads[0]);
        System.debug('l2 phonefields::: '+qLeads[1]);
        System.debug('l3 phonefields::: '+qLeads[2]);
        System.debug('l4 phonefields::: '+qLeads[3]);
        System.debug('l5 phonefields::: '+qLeads[4]);
        System.debug('l6 phonefields::: '+qLeads[5]);
        System.debug('l7 phonefields::: '+qLeads[6]);
        System.debug('l8 phonefields::: '+qLeads[7]);
        System.debug('returned contacts from Setup::: '+contacts);
        System.debug('c1 phonefields::: '+ qContacts[0]);
        System.debug('c2 phonefields::: '+ qContacts[1]);
        System.debug('c3 phonefields::: '+ qContacts[2]);
        System.debug('c4 phonefields::: '+ qContacts[3]);
        System.debug('c5 phonefields::: '+ qContacts[4]);
        System.debug('c6 phonefields::: '+ qContacts[5]);
        System.debug('c7 phonefields::: '+ qContacts[6]);
        System.debug('c8 phonefields::: '+ qContacts[7]);

        List<List<SObject>> records = PhoneRelationHelper.getRecords(phoneValues);

        System.debug('records list number 0' + records[0]);
        System.debug('records list number 1' + records[1]);
        System.debug('records list number 2' + records[2]);
        System.debug('List of returnLeads Size::: '+records[0].size());
        System.debug('List of returnContacts Size::: '+records[1].size());
        System.debug('List of returnPhoneNumber Size::: '+records[2].size());
        System.assertEquals(7, ((List<Lead>)records[0]).size(), 'the number of leads returned is WRONG');
        System.assertNotEquals(qLeads.size(),records[0].size(),'We should be returning 7 of 8 Leads');
        System.assertNotEquals(qContacts.size(),records[0].size(),'We should be returning 7 of 8 Contacts');
        System.assertEquals(7, ((List<Contact>)records[1]).size(), 'the count of contacts returned is INCORRECT');
        System.assertEquals(phoneValues.size(), ((List<PhoneNumber__c>)records[2]).size(), 'the count of phone numbers returned is NOT RIGHT');
        System.assertEquals(22,((List<PhoneNumber__c>)records[2]).size());


        //do some deleting

        Lead l1 = [SELECT Id FROM Lead WHERE FirstName = 'l1' LIMIT 1];
        Contact c1 = [SELECT Id FROM Contact WHERE FirstName = 'c1' LIMIT 1];
        List<SObject> whosDeletable = new List<SObject>{ l1, c1 };
        delete whosDeletable;

    }
/* ;

        // Get existing phone numbers


        // Create non-existing phone numbers using PhoneRelationHelper


        System.assertEquals(2, newPhones.size() - existingPhones.size(), 'Incorrect number of phone numbers created');
        // Assertions to verify the creation of new phone numbers */
//    @IsTest
//    static void testHandlePPRs(){
//        Set<String> phoneValues = new Set<String>{ '9870000002', '9870000003' };
//        List<PhoneNumber__c> existingPhones = [SELECT Id, Name FROM PhoneNumber__c WHERE Name IN :phoneValues];
//        Test.startTest();
//        List<PhoneNumber__c> newPhones = PhoneRelationHelper.HandlePPRs(phoneValues, existingPhones);
//        Test.stopTest();
//    }
    @IsTest
    static void testHandlePPRs() {
        // Prepare the set of phone values
        Set<String> phoneValues = new Set<String>();
        Set<String> lPhoneValues = new Set<String>{'9870000000','9870000001','9870000002','9870000003','9870000004','9870000005','9870000006','9870000007','9870000008','9870000010','9870000099'};
        Set<String> cPhoneValues = new Set<String>{'2340000000','2340000001','2340000002','2340000003','2340000004','2340000005','2340000006','2340000007','2340000008','2340000010','2340000099'};
        phoneValues.addAll(lPhoneValues);
        phoneValues.addAll(cPhoneValues);

        // Get records using that method
        List<List<SObject>> records = PhoneRelationHelper.getRecords(phoneValues);

        // run this test --> give the list<List<sobject>> 0 is leads 1 is contacts
        Test.startTest();
        PhoneRelationHelper.HandlePPRs(records);
        Test.stopTest();

        // We gotta query PPRs we updated
        List<PhonePersonRelationship__c> pprs = [SELECT Id, Lead__c, Contact__c, Phonenumber__c FROM PhonePersonRelationship__c];
        System.assert(pprs.size() > 0, 'PPRs were not handled correctly');

        // check for changes on...1
    }

    @IsTest
    static void testContactLooper(){

    }
}