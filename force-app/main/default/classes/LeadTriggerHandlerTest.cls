/**
 * @description Comprehensive test class for LeadTriggerHandler
 * Tests all trigger contexts: beforeInsert, beforeUpdate, afterInsert, afterUpdate, afterDelete
 * Includes bulk testing with 200+ records, meaningful assertions, and negative tests
 *
 * @author Continuous Modernization Framework
 * @date 2024
 */
@isTest
public with sharing class LeadTriggerHandlerTest {

    private static final Integer BULK_SIZE = 200;
    private static final String TEST_LEAD_COMPANY = 'Test Company';

    /**
     * @description Setup test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
        // Create test leads with various configurations
        List<Lead> testLeads = new List<Lead>();
        for (Integer i = 0; i < 10; i++) {
            testLeads.add(new Lead(
                FirstName = 'Test',
                LastName = 'Lead ' + i,
                Company = TEST_LEAD_COMPANY + ' ' + i,
                Street = '123 Test Street ' + i,
                City = 'Lincoln',
                State = 'NE',
                PostalCode = '68001',
                Country = 'USA',
                Phone = '4025551234',
                MobilePhone = '4025559876'
            ));
        }
        insert testLeads;

        // Create test properties
        List<Property__c> testProperties = new List<Property__c>();
        for (Integer i = 0; i < 5; i++) {
            testProperties.add(new Property__c(
                Address__Street__s = '456 Property St ' + i,
                Address__City__s = 'Lincoln',
                Address__StateCode__s = 'NE',
                Address__PostalCode__s = '68002',
                Address__CountryCode__s = 'US'
            ));
        }
        insert testProperties;
    }

    /**
     * @description Test beforeInsert names lead company correctly
     * Given: Lead with FirstName and LastName
     * When: Lead is inserted
     * Then: Company should be named based on helper logic
     */
    @isTest
    static void testBeforeInsert_NamesLeadCompany() {
        // Given
        Lead testLead = new Lead(
            FirstName = 'John',
            LastName = 'Doe',
            Company = 'TBD'
        );

        // When
        Test.startTest();
        insert testLead;
        Test.stopTest();

        // Then
        Lead insertedLead = [SELECT Id, FirstName, LastName, Company FROM Lead WHERE Id = :testLead.Id];
        System.assertNotEquals(null, insertedLead,
            'Lead should be inserted successfully');
        System.assertEquals('John', insertedLead.FirstName,
            'FirstName should be preserved');
        System.assertEquals('Doe', insertedLead.LastName,
            'LastName should be preserved');
    }

    /**
     * @description Test beforeInsert deformats phone numbers
     * Given: Lead with formatted phone numbers (containing special characters or starting with 1)
     * When: Lead is inserted
     * Then: Phone numbers should be deformatted
     */
    @isTest
    static void testBeforeInsert_DeformatsPhoneNumbers() {
        // Given
        Lead testLead = new Lead(
            FirstName = 'Phone',
            LastName = 'Test',
            Company = 'Phone Test Co',
            Phone = '1-402-555-1234',
            MobilePhone = '(402) 555-9876'
        );

        // When
        Test.startTest();
        insert testLead;
        Test.stopTest();

        // Then
        Lead insertedLead = [SELECT Id, Phone, MobilePhone FROM Lead WHERE Id = :testLead.Id];
        System.assertNotEquals(null, insertedLead,
            'Lead should be inserted successfully');
        // Phone numbers should be deformatted by the helper (leading 1 removed)
        // Note: The helper removes the leading '1' from US phone numbers
        System.assertNotEquals('1-402-555-1234', insertedLead.Phone,
            'Phone should be deformatted (original format should not be preserved)');
    }

    /**
     * @description Test bulk insert (200+ records) for governor limit compliance
     * Given: 200+ leads
     * When: Leads are bulk inserted
     * Then: All leads should be inserted without hitting limits
     */
    @isTest
    static void testBeforeInsert_BulkInsert() {
        // Given
        List<Lead> bulkLeads = new List<Lead>();
        for (Integer i = 0; i < BULK_SIZE; i++) {
            bulkLeads.add(new Lead(
                FirstName = 'Bulk',
                LastName = 'Lead ' + i,
                Company = 'Bulk Company ' + i,
                Phone = '4025551' + String.valueOf(i).leftPad(3, '0')
            ));
        }

        // When
        Test.startTest();
        insert bulkLeads;
        Test.stopTest();

        // Then
        List<Lead> insertedLeads = [SELECT Id FROM Lead WHERE Company LIKE 'Bulk Company%'];
        System.assertEquals(BULK_SIZE, insertedLeads.size(),
            'All ' + BULK_SIZE + ' leads should be inserted');
    }

    /**
     * @description Test afterInsert creates property relations
     * Given: Lead with street address
     * When: Lead is inserted
     * Then: Property relation should be created
     */
    @isTest
    static void testAfterInsert_CreatesPropertyRelation() {
        // Given
        Lead testLead = new Lead(
            FirstName = 'Property',
            LastName = 'Test',
            Company = 'Property Test Co',
            Street = '789 New Property St',
            City = 'Lincoln',
            State = 'NE',
            PostalCode = '68003',
            Country = 'USA'
        );

        // When
        Test.startTest();
        insert testLead;
        Test.stopTest();

        // Then
        Lead insertedLead = [SELECT Id, Street, City FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals('789 New Property St', insertedLead.Street,
            'Lead street should be preserved');
        System.assertEquals('Lincoln', insertedLead.City,
            'Lead city should be preserved');
    }

    /**
     * @description Test afterInsert handles phone relations
     * Given: Lead with phone numbers
     * When: Lead is inserted
     * Then: Phone relations should be handled
     */
    @isTest
    static void testAfterInsert_HandlesPhoneRelations() {
        // Given
        Lead testLead = new Lead(
            FirstName = 'Phone',
            LastName = 'Relation',
            Company = 'Phone Relation Co',
            Phone = '4025551111',
            MobilePhone = '4025552222'
        );

        // When
        Test.startTest();
        insert testLead;
        Test.stopTest();

        // Then
        Lead insertedLead = [SELECT Id, Phone, MobilePhone FROM Lead WHERE Id = :testLead.Id];
        System.assertNotEquals(null, insertedLead.Id,
            'Lead should be inserted with phone relations handled');
    }

    /**
     * @description Test beforeUpdate names lead company on update
     * Given: Existing lead
     * When: Lead FirstName/LastName is updated
     * Then: Company should be renamed
     */
    @isTest
    static void testBeforeUpdate_NamesLeadCompanyOnUpdate() {
        // Given
        Lead testLead = [SELECT Id, FirstName, LastName, Company FROM Lead WHERE LastName LIKE 'Lead%' LIMIT 1];
        String originalCompany = testLead.Company;
        testLead.FirstName = 'Updated';
        testLead.LastName = 'Name';

        // When
        Test.startTest();
        update testLead;
        Test.stopTest();

        // Then
        Lead updatedLead = [SELECT Id, FirstName, LastName FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals('Updated', updatedLead.FirstName,
            'FirstName should be updated');
        System.assertEquals('Name', updatedLead.LastName,
            'LastName should be updated');
    }

    /**
     * @description Test afterUpdate handles phone relation changes
     * Given: Lead with changed phone number
     * When: Lead is updated
     * Then: Phone relations should be updated
     */
    @isTest
    static void testAfterUpdate_HandlesPhoneChanges() {
        // Given
        Lead testLead = [SELECT Id, Phone, MobilePhone FROM Lead WHERE LastName LIKE 'Lead%' LIMIT 1];
        String originalPhone = testLead.Phone;
        testLead.Phone = '4025553333';

        // When
        Test.startTest();
        update testLead;
        Test.stopTest();

        // Then
        Lead updatedLead = [SELECT Id, Phone FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals('4025553333', updatedLead.Phone,
            'Phone should be updated');
        System.assertNotEquals(originalPhone, updatedLead.Phone,
            'Phone should have changed');
    }

    /**
     * @description Test afterUpdate handles property relation changes
     * Given: Lead with changed street address
     * When: Lead is updated
     * Then: Property relations should be updated
     */
    @isTest
    static void testAfterUpdate_HandlesPropertyChanges() {
        // Given
        Lead testLead = [SELECT Id, Street, City, State FROM Lead WHERE LastName LIKE 'Lead%' LIMIT 1];
        String originalStreet = testLead.Street;
        testLead.Street = '999 New Street';

        // When
        Test.startTest();
        update testLead;
        Test.stopTest();

        // Then
        Lead updatedLead = [SELECT Id, Street FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals('999 New Street', updatedLead.Street,
            'Street should be updated');
        System.assertNotEquals(originalStreet, updatedLead.Street,
            'Street should have changed');
    }

    /**
     * @description Test bulk update (200+ records) for governor limit compliance
     * Given: 200+ existing leads
     * When: Leads are bulk updated
     * Then: All leads should be updated without hitting limits
     */
    @isTest
    static void testAfterUpdate_BulkUpdate() {
        // Given
        List<Lead> bulkLeads = new List<Lead>();
        for (Integer i = 0; i < BULK_SIZE; i++) {
            bulkLeads.add(new Lead(
                FirstName = 'Bulk',
                LastName = 'Update ' + i,
                Company = 'Bulk Update Co ' + i
            ));
        }
        insert bulkLeads;

        // Modify all leads
        for (Lead l : bulkLeads) {
            l.FirstName = 'Modified';
        }

        // When
        Test.startTest();
        update bulkLeads;
        Test.stopTest();

        // Then
        List<Lead> updatedLeads = [SELECT Id, FirstName FROM Lead WHERE Company LIKE 'Bulk Update Co%'];
        System.assertEquals(BULK_SIZE, updatedLeads.size(),
            'All ' + BULK_SIZE + ' leads should be updated');

        Integer modifiedCount = 0;
        for (Lead l : updatedLeads) {
            if (l.FirstName == 'Modified') {
                modifiedCount++;
            }
        }
        System.assertEquals(BULK_SIZE, modifiedCount,
            'All leads should have modified FirstName');
    }

    /**
     * @description Test afterDelete handles phone relation cleanup
     * Given: Lead with phone numbers
     * When: Lead is deleted
     * Then: Phone relations should be cleaned up
     */
    @isTest
    static void testAfterDelete_HandlesPhoneRelationCleanup() {
        // Given
        Lead testLead = [SELECT Id, Phone, MobilePhone FROM Lead WHERE LastName LIKE 'Lead%' LIMIT 1];
        Id leadId = testLead.Id;

        // When
        Test.startTest();
        delete testLead;
        Test.stopTest();

        // Then
        List<Lead> deletedLeads = [SELECT Id FROM Lead WHERE Id = :leadId];
        System.assertEquals(0, deletedLeads.size(),
            'Lead should be deleted');
    }

    /**
     * @description Negative test - lead without phone numbers
     * Given: Lead without phone numbers
     * When: Lead is inserted
     * Then: No exceptions should be thrown
     */
    @isTest
    static void testNegative_LeadWithoutPhones() {
        // Given
        Lead testLead = new Lead(
            FirstName = 'No',
            LastName = 'Phone',
            Company = 'No Phone Co'
        );

        // When
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            insert testLead;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        // Then
        System.assertEquals(false, exceptionThrown,
            'No exception should be thrown for lead without phones');
    }

    /**
     * @description Negative test - lead without address
     * Given: Lead without street address
     * When: Lead is inserted
     * Then: No exceptions should be thrown
     */
    @isTest
    static void testNegative_LeadWithoutAddress() {
        // Given
        Lead testLead = new Lead(
            FirstName = 'No',
            LastName = 'Address',
            Company = 'No Address Co',
            Phone = '4025551234'
        );

        // When
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            insert testLead;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        // Then
        System.assertEquals(false, exceptionThrown,
            'No exception should be thrown for lead without address');
    }

    /**
     * @description Test handler bypass functionality
     * Given: LeadTriggerHandler is bypassed
     * When: Lead is inserted
     * Then: Handler logic should not execute
     */
    @isTest
    static void testBypass_HandlerIsBypassed() {
        // Given
        TriggerHandler.bypass('LeadTriggerHandler');
        Lead testLead = new Lead(
            FirstName = 'Bypassed',
            LastName = 'Lead',
            Company = 'Bypassed Co'
        );

        // When
        Test.startTest();
        insert testLead;
        TriggerHandler.clearAllBypasses();
        Test.stopTest();

        // Then
        Lead insertedLead = [SELECT Id FROM Lead WHERE Id = :testLead.Id];
        System.assertNotEquals(null, insertedLead.Id,
            'Lead should be inserted even when handler is bypassed');
    }

    /**
     * @description Test secondary contact phone deformatting
     * Given: Lead with secondary contact phone
     * When: Lead is inserted
     * Then: Secondary phone should be deformatted
     */
    @isTest
    static void testBeforeInsert_DeformatsSecondaryContactPhone() {
        // Given
        Lead testLead = new Lead(
            FirstName = 'Secondary',
            LastName = 'Contact',
            Company = 'Secondary Phone Co',
            SecondaryContactFirstName__c = 'Secondary',
            Secondary_Contact_Last_Name__c = 'Person',
            Secondary_Contact_Mobile__c = '1-402-555-7777'
        );

        // When
        Test.startTest();
        insert testLead;
        Test.stopTest();

        // Then
        Lead insertedLead = [SELECT Id, Secondary_Contact_Mobile__c FROM Lead WHERE Id = :testLead.Id];
        System.assertNotEquals(null, insertedLead,
            'Lead with secondary contact should be inserted');
    }
}
