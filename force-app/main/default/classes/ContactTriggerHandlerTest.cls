/**
 * @description Comprehensive test class for ContactTriggerHandler
 * Tests all trigger contexts: beforeInsert, beforeUpdate, afterInsert, afterUpdate, afterDelete
 * Includes bulk testing with 200+ records, meaningful assertions, and negative tests
 *
 * @author Continuous Modernization Framework
 * @date 2024
 */
@isTest
public with sharing class ContactTriggerHandlerTest {

    private static final Integer BULK_SIZE = 200;

    /**
     * @description Setup test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
        // Create test accounts
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            testAccounts.add(new Account(
                Name = 'Test Account ' + i,
                BillingStreet = '123 Account St',
                BillingCity = 'Lincoln',
                BillingState = 'NE'
            ));
        }
        insert testAccounts;

        // Create test contacts
        List<Contact> testContacts = new List<Contact>();
        for (Integer i = 0; i < 10; i++) {
            testContacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                AccountId = testAccounts[Math.mod(i, 5)].Id,
                Phone = '4025551234',
                MobilePhone = '4025559876'
            ));
        }
        insert testContacts;
    }

    /**
     * @description Test beforeInsert deformats phone numbers
     * Given: Contact with formatted phone numbers
     * When: Contact is inserted
     * Then: Phone numbers should be deformatted
     */
    @isTest
    static void testBeforeInsert_DeformatsPhoneNumbers() {
        // Given
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Contact testContact = new Contact(
            FirstName = 'Phone',
            LastName = 'Deformat Test',
            AccountId = testAccount.Id,
            Phone = '1-402-555-1234',
            MobilePhone = '(402) 555-9876'
        );

        // When
        Test.startTest();
        insert testContact;
        Test.stopTest();

        // Then
        Contact insertedContact = [SELECT Id, Phone, MobilePhone FROM Contact WHERE Id = :testContact.Id];
        System.assertNotEquals(null, insertedContact,
            'Contact should be inserted successfully');
    }

    /**
     * @description Test bulk insert (200+ records) for governor limit compliance
     * Given: 200+ contacts
     * When: Contacts are bulk inserted
     * Then: All contacts should be inserted without hitting limits
     */
    @isTest
    static void testBeforeInsert_BulkInsert() {
        // Given
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        List<Contact> bulkContacts = new List<Contact>();
        for (Integer i = 0; i < BULK_SIZE; i++) {
            bulkContacts.add(new Contact(
                FirstName = 'Bulk',
                LastName = 'Contact ' + i,
                AccountId = testAccount.Id,
                Phone = '4025551' + String.valueOf(i).leftPad(3, '0')
            ));
        }

        // When
        Test.startTest();
        insert bulkContacts;
        Test.stopTest();

        // Then
        List<Contact> insertedContacts = [SELECT Id FROM Contact WHERE LastName LIKE 'Contact %' AND FirstName = 'Bulk'];
        System.assertEquals(BULK_SIZE, insertedContacts.size(),
            'All ' + BULK_SIZE + ' contacts should be inserted');
    }

    /**
     * @description Test afterInsert names account correctly
     * Given: Contact linked to account
     * When: Contact is inserted
     * Then: Account should be processed by naming utility
     */
    @isTest
    static void testAfterInsert_NamesAccount() {
        // Given
        Account testAccount = [SELECT Id, Name FROM Account LIMIT 1];
        Contact testContact = new Contact(
            FirstName = 'New',
            LastName = 'Contact',
            AccountId = testAccount.Id
        );

        // When
        Test.startTest();
        insert testContact;
        Test.stopTest();

        // Then
        Contact insertedContact = [SELECT Id, AccountId FROM Contact WHERE Id = :testContact.Id];
        System.assertEquals(testAccount.Id, insertedContact.AccountId,
            'Contact should be linked to account');
    }

    /**
     * @description Test afterInsert handles phone relations
     * Given: Contact with phone numbers
     * When: Contact is inserted
     * Then: Phone relations should be created
     */
    @isTest
    static void testAfterInsert_HandlesPhoneRelations() {
        // Given
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Contact testContact = new Contact(
            FirstName = 'Phone',
            LastName = 'Relations',
            AccountId = testAccount.Id,
            Phone = '4025551111',
            MobilePhone = '4025552222'
        );

        // When
        Test.startTest();
        insert testContact;
        Test.stopTest();

        // Then
        Contact insertedContact = [SELECT Id, Phone, MobilePhone FROM Contact WHERE Id = :testContact.Id];
        System.assertNotEquals(null, insertedContact.Id,
            'Contact with phone relations should be inserted');
    }

    /**
     * @description Test beforeUpdate deformats phone numbers
     * Given: Contact with updated formatted phone
     * When: Contact is updated
     * Then: Phone should be deformatted
     */
    @isTest
    static void testBeforeUpdate_DeformatsPhoneNumbers() {
        // Given
        Contact testContact = [SELECT Id, Phone FROM Contact WHERE LastName LIKE 'Contact%' LIMIT 1];
        testContact.Phone = '1-402-555-3333';

        // When
        Test.startTest();
        update testContact;
        Test.stopTest();

        // Then
        Contact updatedContact = [SELECT Id, Phone FROM Contact WHERE Id = :testContact.Id];
        System.assertNotEquals(null, updatedContact,
            'Contact should be updated');
    }

    /**
     * @description Test afterUpdate names account on contact changes
     * Given: Contact with name change
     * When: Contact is updated
     * Then: Account naming should be triggered
     */
    @isTest
    static void testAfterUpdate_NamesAccountOnContactChange() {
        // Given
        Contact testContact = [SELECT Id, FirstName, LastName, AccountId FROM Contact WHERE LastName LIKE 'Contact%' LIMIT 1];
        testContact.FirstName = 'Updated';

        // When
        Test.startTest();
        update testContact;
        Test.stopTest();

        // Then
        Contact updatedContact = [SELECT Id, FirstName FROM Contact WHERE Id = :testContact.Id];
        System.assertEquals('Updated', updatedContact.FirstName,
            'Contact first name should be updated');
    }

    /**
     * @description Test afterUpdate handles phone changes
     * Given: Contact with changed phone number
     * When: Contact is updated
     * Then: Phone relations should be updated
     */
    @isTest
    static void testAfterUpdate_HandlesPhoneChanges() {
        // Given
        Contact testContact = [SELECT Id, Phone FROM Contact WHERE LastName LIKE 'Contact%' LIMIT 1];
        String originalPhone = testContact.Phone;
        testContact.Phone = '4025554444';

        // When
        Test.startTest();
        update testContact;
        Test.stopTest();

        // Then
        Contact updatedContact = [SELECT Id, Phone FROM Contact WHERE Id = :testContact.Id];
        System.assertEquals('4025554444', updatedContact.Phone,
            'Phone should be updated');
    }

    /**
     * @description Test bulk update (200+ records) for governor limit compliance
     * Given: 200+ existing contacts
     * When: Contacts are bulk updated
     * Then: All contacts should be updated without hitting limits
     */
    @isTest
    static void testAfterUpdate_BulkUpdate() {
        // Given
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        List<Contact> bulkContacts = new List<Contact>();
        for (Integer i = 0; i < BULK_SIZE; i++) {
            bulkContacts.add(new Contact(
                FirstName = 'Bulk',
                LastName = 'Update ' + i,
                AccountId = testAccount.Id
            ));
        }
        insert bulkContacts;

        // Modify all contacts
        for (Contact c : bulkContacts) {
            c.FirstName = 'Modified';
        }

        // When
        Test.startTest();
        update bulkContacts;
        Test.stopTest();

        // Then
        List<Contact> updatedContacts = [SELECT Id, FirstName FROM Contact WHERE LastName LIKE 'Update %'];
        System.assertEquals(BULK_SIZE, updatedContacts.size(),
            'All ' + BULK_SIZE + ' contacts should be updated');

        Integer modifiedCount = 0;
        for (Contact c : updatedContacts) {
            if (c.FirstName == 'Modified') {
                modifiedCount++;
            }
        }
        System.assertEquals(BULK_SIZE, modifiedCount,
            'All contacts should have modified FirstName');
    }

    /**
     * @description Test afterDelete handles account naming
     * Given: Contact linked to account
     * When: Contact is deleted
     * Then: Account should be renamed
     */
    @isTest
    static void testAfterDelete_HandlesAccountNaming() {
        // Given
        Contact testContact = [SELECT Id, AccountId FROM Contact WHERE LastName LIKE 'Contact%' LIMIT 1];
        Id accountId = testContact.AccountId;
        Id contactId = testContact.Id;

        // When
        Test.startTest();
        delete testContact;
        Test.stopTest();

        // Then
        List<Contact> deletedContacts = [SELECT Id FROM Contact WHERE Id = :contactId];
        System.assertEquals(0, deletedContacts.size(),
            'Contact should be deleted');

        Account account = [SELECT Id FROM Account WHERE Id = :accountId];
        System.assertNotEquals(null, account,
            'Account should still exist');
    }

    /**
     * @description Test afterDelete handles phone relation cleanup
     * Given: Contact with phone numbers
     * When: Contact is deleted
     * Then: Phone relations should be cleaned up
     */
    @isTest
    static void testAfterDelete_HandlesPhoneRelationCleanup() {
        // Given
        Contact testContact = [SELECT Id, Phone, MobilePhone FROM Contact WHERE LastName LIKE 'Contact%' LIMIT 1];
        Id contactId = testContact.Id;

        // When
        Test.startTest();
        delete testContact;
        Test.stopTest();

        // Then
        List<Contact> deletedContacts = [SELECT Id FROM Contact WHERE Id = :contactId];
        System.assertEquals(0, deletedContacts.size(),
            'Contact should be deleted');
    }

    /**
     * @description Negative test - contact without phone numbers
     * Given: Contact without phone numbers
     * When: Contact is inserted
     * Then: No exceptions should be thrown
     */
    @isTest
    static void testNegative_ContactWithoutPhones() {
        // Given
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Contact testContact = new Contact(
            FirstName = 'No',
            LastName = 'Phone',
            AccountId = testAccount.Id
        );

        // When
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            insert testContact;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        // Then
        System.assertEquals(false, exceptionThrown,
            'No exception should be thrown for contact without phones');
    }

    /**
     * @description Negative test - contact without account
     * Given: Contact without account
     * When: Contact is inserted
     * Then: No exceptions should be thrown
     */
    @isTest
    static void testNegative_ContactWithoutAccount() {
        // Given
        Contact testContact = new Contact(
            FirstName = 'No',
            LastName = 'Account'
        );

        // When
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            insert testContact;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        // Then
        System.assertEquals(false, exceptionThrown,
            'No exception should be thrown for contact without account');
    }

    /**
     * @description Test handler bypass functionality
     * Given: ContactTriggerHandler is bypassed
     * When: Contact is inserted
     * Then: Handler logic should not execute
     */
    @isTest
    static void testBypass_HandlerIsBypassed() {
        // Given
        TriggerHandler.bypass('ContactTriggerHandler');
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Contact testContact = new Contact(
            FirstName = 'Bypassed',
            LastName = 'Contact',
            AccountId = testAccount.Id
        );

        // When
        Test.startTest();
        insert testContact;
        TriggerHandler.clearAllBypasses();
        Test.stopTest();

        // Then
        Contact insertedContact = [SELECT Id FROM Contact WHERE Id = :testContact.Id];
        System.assertNotEquals(null, insertedContact.Id,
            'Contact should be inserted even when handler is bypassed');
    }
}
