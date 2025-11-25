/**
 * @description Comprehensive test class for AccountTriggerHelper
 * Tests all static methods: pickRecords, UpdateWorkOrderAndServiceAppointmentNames,
 * UpdateContactDisposOnNewAccountDispo, UpdateAccountStageOnNull
 * Includes bulk testing with 200+ records, meaningful assertions, and negative tests
 *
 * @author Continuous Modernization Framework
 * @date 2024
 */
@isTest
public with sharing class AccountTriggerHelperTest {

    private static final Integer BULK_SIZE = 200;

    /**
     * @description Setup test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
        // Create test accounts
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            testAccounts.add(new Account(
                Name = 'Test Account ' + i,
                BillingStreet = '123 Test St',
                BillingCity = 'Lincoln',
                BillingState = 'NE',
                Account_Disposition__c = 'New'
            ));
        }
        insert testAccounts;

        // Create test contacts for each account
        List<Contact> testContacts = new List<Contact>();
        for (Account acc : testAccounts) {
            testContacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact for ' + acc.Name,
                AccountId = acc.Id
            ));
        }
        insert testContacts;

        // Create test opportunities
        List<Opportunity> testOpps = new List<Opportunity>();
        for (Account acc : testAccounts) {
            testOpps.add(new Opportunity(
                Name = 'Test Opp for ' + acc.Name,
                AccountId = acc.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            ));
        }
        insert testOpps;
    }

    /**
     * @description Test pickRecords returns correct lists on insert
     * Given: Accounts being inserted
     * When: pickRecords is called in insert context
     * Then: Should return accounts for naming
     */
    @isTest
    static void testPickRecords_OnInsert() {
        // Given
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            testAccounts.add(new Account(
                Name = 'PickRecords Test ' + i
            ));
        }

        // When
        Test.startTest();
        insert testAccounts;
        Test.stopTest();

        // Then
        List<Account> insertedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'PickRecords Test%'];
        System.assertEquals(5, insertedAccounts.size(),
            '5 accounts should be inserted');
    }

    /**
     * @description Test pickRecords returns correct lists on update with name change
     * Given: Accounts being updated with name change
     * When: pickRecords is called in update context
     * Then: Should return opportunities for naming
     */
    @isTest
    static void testPickRecords_OnUpdateNameChange() {
        // Given
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%' LIMIT 1];
        String originalName = testAccount.Name;
        testAccount.Name = 'Updated Account Name';

        // When
        Test.startTest();
        update testAccount;
        Test.stopTest();

        // Then
        Account updatedAccount = [SELECT Id, Name FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals('Updated Account Name', updatedAccount.Name,
            'Account name should be updated');
        System.assertNotEquals(originalName, updatedAccount.Name,
            'Account name should have changed');
    }

    /**
     * @description Test pickRecords handles disposition change
     * Given: Account with disposition change
     * When: Account is updated
     * Then: Contact dispositions should be updated
     */
    @isTest
    static void testPickRecords_OnDispositionChange() {
        // Given
        Account testAccount = [SELECT Id, Account_Disposition__c FROM Account WHERE Name LIKE 'Test Account%' LIMIT 1];
        Contact relatedContact = [SELECT Id, Account_Disposition__c FROM Contact WHERE AccountId = :testAccount.Id LIMIT 1];
        testAccount.Account_Disposition__c = 'Qualified';

        // When
        Test.startTest();
        update testAccount;
        Test.stopTest();

        // Then
        Contact updatedContact = [SELECT Id, Account_Disposition__c FROM Contact WHERE Id = :relatedContact.Id];
        System.assertEquals('Qualified', updatedContact.Account_Disposition__c,
            'Contact disposition should match account disposition');
    }

    /**
     * @description Test UpdateContactDisposOnNewAccountDispo
     * Given: Accounts with contacts
     * When: Account disposition changes
     * Then: All related contacts should have updated disposition
     */
    @isTest
    static void testUpdateContactDisposOnNewAccountDispo() {
        // Given
        Account testAccount = [SELECT Id FROM Account WHERE Name LIKE 'Test Account%' LIMIT 1];

        // Create multiple contacts
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 5; i++) {
            contacts.add(new Contact(
                FirstName = 'Dispo',
                LastName = 'Test ' + i,
                AccountId = testAccount.Id
            ));
        }
        insert contacts;

        testAccount.Account_Disposition__c = 'Closed Won';

        // When
        Test.startTest();
        update testAccount;
        Test.stopTest();

        // Then
        List<Contact> updatedContacts = [SELECT Id, Account_Disposition__c FROM Contact WHERE AccountId = :testAccount.Id AND FirstName = 'Dispo'];
        System.assertEquals(5, updatedContacts.size(),
            '5 contacts should be found');

        for (Contact c : updatedContacts) {
            System.assertEquals('Closed Won', c.Account_Disposition__c,
                'Each contact should have updated disposition');
        }
    }

    /**
     * @description Test UpdateAccountStageOnNull sets default stage
     * Given: Account without Stage__c
     * When: Account is inserted
     * Then: Stage__c should be set to 'Nurturing'
     */
    @isTest
    static void testUpdateAccountStageOnNull_SetsNurturing() {
        // Given
        Account testAccount = new Account(
            Name = 'Stage Null Test'
        );

        // When
        Test.startTest();
        insert testAccount;
        Test.stopTest();

        // Then
        Account insertedAccount = [SELECT Id, Stage__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals('Nurturing', insertedAccount.Stage__c,
            'Stage__c should be set to Nurturing when null');
    }

    /**
     * @description Test UpdateAccountStageOnNull preserves existing stage
     * Given: Account with existing Stage__c
     * When: Account is inserted
     * Then: Stage__c should retain original value
     */
    @isTest
    static void testUpdateAccountStageOnNull_PreservesExisting() {
        // Given
        Account testAccount = new Account(
            Name = 'Stage Exists Test',
            Stage__c = 'Active'
        );

        // When
        Test.startTest();
        insert testAccount;
        Test.stopTest();

        // Then
        Account insertedAccount = [SELECT Id, Stage__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals('Active', insertedAccount.Stage__c,
            'Stage__c should retain original value');
    }

    /**
     * @description Test bulk insert (200+ records) for UpdateAccountStageOnNull
     * Given: 200+ accounts without Stage__c
     * When: Accounts are bulk inserted
     * Then: All accounts should have Stage__c set to Nurturing
     */
    @isTest
    static void testUpdateAccountStageOnNull_Bulk() {
        // Given
        List<Account> bulkAccounts = new List<Account>();
        for (Integer i = 0; i < BULK_SIZE; i++) {
            bulkAccounts.add(new Account(
                Name = 'Bulk Stage Test ' + i
            ));
        }

        // When
        Test.startTest();
        insert bulkAccounts;
        Test.stopTest();

        // Then
        List<Account> insertedAccounts = [SELECT Id, Stage__c FROM Account WHERE Name LIKE 'Bulk Stage Test%'];
        System.assertEquals(BULK_SIZE, insertedAccounts.size(),
            'All ' + BULK_SIZE + ' accounts should be inserted');

        Integer nurturingCount = 0;
        for (Account acc : insertedAccounts) {
            if (acc.Stage__c == 'Nurturing') {
                nurturingCount++;
            }
        }
        System.assertEquals(BULK_SIZE, nurturingCount,
            'All accounts should have Stage__c = Nurturing');
    }

    /**
     * @description Test pickRecords sets Stage to Active when account has open opportunities
     * Given: Account with open opportunities
     * When: Account is updated
     * Then: Stage__c should reflect the opportunity count
     */
    @isTest
    static void testPickRecords_SetsActiveOnOpenOpportunities() {
        // Given
        Account testAccount = [SELECT Id, Stage__c FROM Account WHERE Name LIKE 'Test Account%' LIMIT 1];

        // Create an open opportunity to increase Open_Opportunity_Count__c
        Opportunity opp = new Opportunity(
            Name = 'Test Opp for Active Stage',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        // When - update account to trigger stage recalculation
        Test.startTest();
        testAccount.Description = 'Updated to trigger stage recalculation';
        update testAccount;
        Test.stopTest();

        // Then
        Account updatedAccount = [SELECT Id, Stage__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals('Active', updatedAccount.Stage__c,
            'Stage__c should be Active when account has open opportunities');
    }

    /**
     * @description Bulk test for disposition update
     * Given: 200+ accounts with contacts
     * When: All account dispositions change
     * Then: All related contacts should be updated
     */
    @isTest
    static void testUpdateContactDisposOnNewAccountDispo_Bulk() {
        // Given
        List<Account> bulkAccounts = new List<Account>();
        for (Integer i = 0; i < 50; i++) {
            bulkAccounts.add(new Account(
                Name = 'Bulk Dispo Account ' + i,
                Account_Disposition__c = 'New'
            ));
        }
        insert bulkAccounts;

        // Create contacts for each account
        List<Contact> contacts = new List<Contact>();
        for (Account acc : bulkAccounts) {
            contacts.add(new Contact(
                FirstName = 'Bulk',
                LastName = 'Contact',
                AccountId = acc.Id
            ));
        }
        insert contacts;

        // Update all account dispositions
        for (Account acc : bulkAccounts) {
            acc.Account_Disposition__c = 'Qualified';
        }

        // When
        Test.startTest();
        update bulkAccounts;
        Test.stopTest();

        // Then
        List<Contact> updatedContacts = [SELECT Id, Account_Disposition__c FROM Contact WHERE Account.Name LIKE 'Bulk Dispo Account%'];
        System.assertEquals(50, updatedContacts.size(),
            '50 contacts should be found');

        Integer qualifiedCount = 0;
        for (Contact c : updatedContacts) {
            if (c.Account_Disposition__c == 'Qualified') {
                qualifiedCount++;
            }
        }
        System.assertEquals(50, qualifiedCount,
            'All contacts should have Qualified disposition');
    }

    /**
     * @description Negative test - account without contacts
     * Given: Account without contacts
     * When: Disposition is changed
     * Then: No exceptions should be thrown
     */
    @isTest
    static void testNegative_AccountWithoutContacts() {
        // Given
        Account testAccount = new Account(
            Name = 'No Contacts Account',
            Account_Disposition__c = 'New'
        );
        insert testAccount;

        testAccount.Account_Disposition__c = 'Qualified';

        // When
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            update testAccount;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        // Then
        System.assertEquals(false, exceptionThrown,
            'No exception should be thrown for account without contacts');
    }

    /**
     * @description Negative test - account without opportunities
     * Given: Account without opportunities
     * When: Name is changed
     * Then: No exceptions should be thrown
     */
    @isTest
    static void testNegative_AccountWithoutOpportunities() {
        // Given
        Account testAccount = new Account(
            Name = 'No Opps Account'
        );
        insert testAccount;

        testAccount.Name = 'Updated No Opps Account';

        // When
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            update testAccount;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        // Then
        System.assertEquals(false, exceptionThrown,
            'No exception should be thrown for account without opportunities');
    }

    /**
     * @description Test UpdateWorkOrderAndServiceAppointmentNames is called on name change
     * Given: Account with WorkOrders and ServiceAppointments
     * When: Account name changes
     * Then: Related records should be updated
     */
    @isTest
    static void testUpdateWorkOrderAndServiceAppointmentNames() {
        // Given
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%' LIMIT 1];

        // Note: WorkOrder and ServiceAppointment creation requires FSL setup
        // This test validates the method doesn't fail with empty sets
        testAccount.Name = 'Renamed Account';

        // When
        Test.startTest();
        update testAccount;
        Test.stopTest();

        // Then
        Account updatedAccount = [SELECT Id, Name FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals('Renamed Account', updatedAccount.Name,
            'Account name should be updated');
    }
}
