/**
 * Created by Ben on 8/1/2024.
 */

@IsTest
public class DispositionHelperTest {

    //the DISCONNECTED methods

    @IsTest
    static void testLeadDisconnectedNumber() {
        Lead testLead = new Lead(
                FirstName = 'TestLead',
                LastName = 'ass',
                Company = '.',
                Status = 'Open',
                MobilePhone = '1111111111',
                Phone = '2222222222',
                Secondary_Contact_Mobile__c = '3333333333',
                Bad_Phones__c = '6956956955',
                Name_of_Lead_Source__c = 'TestShitBox'
        );
        Lead testLeadNullBadPhones = new Lead(
                FirstName = 'nullbadPhones',
                LastName = 'piss',
                Company = ',',
                Status = 'Open',
                MobilePhone = '9999999999',
                Phone = '8888888888',
                Secondary_Contact_Mobile__c = '7777777777',
                Bad_Phones__c = null,
                Name_of_Lead_Source__c = 'TestShitBox'
        );
        insert testLead;
        insert testLeadNullBadPhones;
        Lead updatedLead = new Lead();
        Lead updatedLeadNullBadPhones = new Lead();
        updatedLead = DispositionHelper.LeadDisconnectedNumber(testLead, testLead.MobilePhone);
        updatedLeadNullBadPhones = DispositionHelper.LeadDisconnectedNumber(testLeadNullBadPhones,testLeadNullBadPhones.MobilePhone);
        System.assertEquals('6956956955,1111111111', updatedLead.Bad_Phones__c);
        System.assertEquals('9999999999',updatedLeadNullBadPhones.Bad_Phones__c);
        System.assertEquals('', updatedLead.MobilePhone);

        updatedLeadNullBadPhones.Bad_Phones__c = null;
        update updatedLeadNullBadPhones;

        updatedLead = DispositionHelper.LeadDisconnectedNumber(testLead, testLead.Phone);
        updatedLeadNullBadPhones = DispositionHelper.LeadDisconnectedNumber(testLeadNullBadPhones,testLeadNullBadPhones.Phone);
        System.assertEquals('6956956955,1111111111,2222222222', updatedLead.Bad_Phones__c);
        System.assertEquals('8888888888',updatedLeadNullBadPhones.Bad_Phones__c);
        System.assertEquals('', updatedLead.Phone);

        updatedLeadNullBadPhones.Bad_Phones__c = null;
        update updatedLeadNullBadPhones;

        updatedLead = DispositionHelper.LeadDisconnectedNumber(testLead, testLead.Secondary_Contact_Mobile__c);
        updatedLeadNullBadPhones = DispositionHelper.LeadDisconnectedNumber(testLeadNullBadPhones,testLeadNullBadPhones.Secondary_Contact_Mobile__c);
        System.assertEquals('6956956955,1111111111,2222222222,3333333333', updatedLead.Bad_Phones__c);
        System.assertEquals('7777777777',updatedLeadNullBadPhones.Bad_Phones__c);
        System.assertEquals('', updatedLead.Secondary_Contact_Mobile__c);
    }
    @IsTest
    static void testContactDisconnectedNumber() {
        Contact testContact = new Contact(
                FirstName = 'sniffsack',
                LastName = 'Test Contact',
                MobilePhone = '1111111111',
                HomePhone = '2222222222',
                Phone = '3333333333',
                Bad_Phones__c = '6956956955'
        );
        Contact testContactNullBadPhones = new Contact(
                FirstName = 'ballsack',
                LastName = 'nullbadPHonesTest',
                MobilePhone = '9999999999',
                HomePhone = '8888888888',
                Phone = '7777777777',
                Bad_Phones__c = null
        );
        insert testContact;
        insert testContactNullBadPhones;
        Contact updatedContact = new Contact();
        Contact updatedContactNullBadPhones = new Contact();

        updatedContact = DispositionHelper.ContactDisconnectedNumber(testContact, testContact.MobilePhone);
        updatedContactNullBadPhones = DispositionHelper.ContactDisconnectedNumber(testContactNullBadPhones, testContactNullBadPhones.MobilePhone);
        System.assertEquals('6956956955,1111111111', updatedContact.Bad_Phones__c);
        System.assertEquals('9999999999', updatedContactNullBadPhones.Bad_Phones__c);
        System.assertEquals('', updatedContact.MobilePhone);

        updatedContactNullBadPhones.Bad_Phones__c = null;
        update updatedContactNullBadPhones;

        updatedContact = DispositionHelper.ContactDisconnectedNumber(testContact, testContact.HomePhone);
        updatedContactNullBadPhones = DispositionHelper.ContactDisconnectedNumber(testContactNullBadPhones, testContactNullBadPhones.HomePhone);
        System.assertEquals('6956956955,1111111111,2222222222', updatedContact.Bad_Phones__c);
        System.assertEquals('8888888888', updatedContactNullBadPhones.Bad_Phones__c);
        System.assertEquals('', updatedContact.HomePhone);

        updatedContactNullBadPhones.Bad_Phones__c = null;
        update updatedContactNullBadPhones;

        updatedContact = DispositionHelper.ContactDisconnectedNumber(testContact, testContact.Phone);
        updatedContactNullBadPhones = DispositionHelper.ContactDisconnectedNumber(testContactNullBadPhones, testContactNullBadPhones.Phone);
        System.assertEquals('6956956955,1111111111,2222222222,3333333333', updatedContact.Bad_Phones__c);
        System.assertEquals('7777777777', updatedContactNullBadPhones.Bad_Phones__c);
        System.assertEquals('', updatedContact.Phone);
    }

    //THE doNotCall METHODS

    @IsTest
    static void testLeadDoNotCall() {
        Lead testLead = new Lead(
                FirstName = 'Jared',
                LastName = 'Testicle',
                Company = '.',
                Status = 'Open',
                MobilePhone = '6666666666'
        );
        insert testLead;
        Lead resultLead = DispositionHelper.LeadDoNotCall(testLead);
        System.assertEquals(testLead.Id, resultLead.Id, 'DONT DELETE THE LEAD YOU RETARD!!!');
    }
    @IsTest
    static void testContactDoNotCall() {
        Contact testContact = new Contact(
                FirstName = 'Doris',
                LastName = 'Horse',
                MobilePhone = '6666666666'
        );
        insert testContact;
        Contact resultContact = DispositionHelper.ContactDoNotCall(testContact);
        System.assertEquals(testContact.Id, resultContact.Id, 'YOU WERENT SUPPOSED TO DELETE THE FUCKING CONTACT');
    }
}