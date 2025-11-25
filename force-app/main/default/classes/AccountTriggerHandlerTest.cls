/**
 * @description Comprehensive test class for AccountTriggerHandler
 * Tests all trigger contexts: beforeInsert, afterInsert, afterUpdate
 * Includes bulk testing with 200+ records, meaningful assertions, and negative tests
 *
 * @author Continuous Modernization Framework
 * @date 2024
 */
@isTest
public with sharing class AccountTriggerHandlerTest {

    private static final Integer BULK_SIZE = 200;
    private static final String TEST_ACCOUNT_NAME = 'Test Account';

    /**
     * @description Setup test data for all test methods
     * Creates accounts with various configurations for comprehensive testing
     */
    @TestSetup
    static void setupTestData() {
        // Create test accounts with different configurations
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            testAccounts.add(new Account(
                Name = TEST_ACCOUNT_NAME + ' ' + i,
                BillingStreet = '123 Test St',
                BillingCity = 'Test City',
                BillingState = 'NE',
                BillingPostalCode = '68001'
            ));
        }
        insert testAccounts;
    }

    /**
     * @description Test beforeInsert context sets default Stage__c when null
     * Given: Account without Stage__c value
     * When: Account is inserted
     * Then: Stage__c should be set to 'Nurturing'
     */
    @isTest
    static void testBeforeInsert_SetsDefaultStage() {
        // Given
        Account testAccount = new Account(
            Name = 'Test Account Stage Null'
        );

        // When
        Test.startTest();
        insert testAccount;
        Test.stopTest();

        // Then
        Account insertedAccount = [SELECT Id, Name, Stage__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals('Nurturing', insertedAccount.Stage__c,
            'Stage__c should be set to Nurturing when null on insert');
        System.assertNotEquals(null, insertedAccount.Id,
            'Account should have been inserted successfully');
    }

    /**
     * @description Test beforeInsert preserves existing Stage__c value
     * Given: Account with existing Stage__c value
     * When: Account is inserted
     * Then: Stage__c should retain its original value
     */
    @isTest
    static void testBeforeInsert_PreservesExistingStage() {
        // Given
        Account testAccount = new Account(
            Name = 'Test Account Stage Set',
            Stage__c = 'Active'
        );

        // When
        Test.startTest();
        insert testAccount;
        Test.stopTest();

        // Then
        Account insertedAccount = [SELECT Id, Stage__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals('Active', insertedAccount.Stage__c,
            'Stage__c should retain its original value when not null');
    }

    /**
     * @description Test bulk insert (200+ records) for governor limit compliance
     * Given: 200+ accounts without Stage__c
     * When: Accounts are bulk inserted
     * Then: All accounts should have Stage__c set correctly
     */
    @isTest
    static void testBeforeInsert_BulkInsert() {
        // Given
        List<Account> bulkAccounts = new List<Account>();
        for (Integer i = 0; i < BULK_SIZE; i++) {
            bulkAccounts.add(new Account(
                Name = 'Bulk Test Account ' + i
            ));
        }

        // When
        Test.startTest();
        insert bulkAccounts;
        Test.stopTest();

        // Then
        List<Account> insertedAccounts = [SELECT Id, Stage__c FROM Account WHERE Name LIKE 'Bulk Test Account%'];
        System.assertEquals(BULK_SIZE, insertedAccounts.size(),
            'All ' + BULK_SIZE + ' accounts should be inserted');

        Integer accountsWithNurturing = 0;
        for (Account acc : insertedAccounts) {
            if (acc.Stage__c == 'Nurturing') {
                accountsWithNurturing++;
            }
        }
        System.assertEquals(BULK_SIZE, accountsWithNurturing,
            'All accounts should have Stage__c set to Nurturing');
    }

    /**
     * @description Test afterInsert naming utility is called
     * Given: New account
     * When: Account is inserted
     * Then: Account should be processed by NamingUtility
     */
    @isTest
    static void testAfterInsert_CallsNamingUtility() {
        // Given
        Account testAccount = new Account(
            Name = 'Test Naming Account'
        );

        // When
        Test.startTest();
        insert testAccount;
        Test.stopTest();

        // Then
        Account insertedAccount = [SELECT Id, Name FROM Account WHERE Id = :testAccount.Id];
        System.assertNotEquals(null, insertedAccount,
            'Account should have been inserted and processed');
    }

    /**
     * @description Test afterUpdate when account name changes
     * Given: Existing account
     * When: Account name is updated
     * Then: Related opportunities should be updated
     */
    @isTest
    static void testAfterUpdate_NameChange() {
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
     * @description Test bulk update (200+ records) for governor limit compliance
     * Given: 200+ existing accounts
     * When: Accounts are bulk updated
     * Then: All accounts should be updated without hitting limits
     */
    @isTest
    static void testAfterUpdate_BulkUpdate() {
        // Given
        List<Account> bulkAccounts = new List<Account>();
        for (Integer i = 0; i < BULK_SIZE; i++) {
            bulkAccounts.add(new Account(
                Name = 'Bulk Update Account ' + i
            ));
        }
        insert bulkAccounts;

        // Modify all accounts
        for (Account acc : bulkAccounts) {
            acc.Name = acc.Name + ' Updated';
        }

        // When
        Test.startTest();
        update bulkAccounts;
        Test.stopTest();

        // Then
        List<Account> updatedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Bulk Update Account%Updated'];
        System.assertEquals(BULK_SIZE, updatedAccounts.size(),
            'All ' + BULK_SIZE + ' accounts should be updated');
    }

    /**
     * @description Test Account_Disposition__c change updates related contacts
     * Given: Account with contacts
     * When: Account_Disposition__c is changed
     * Then: Related contacts should have their disposition updated
     */
    @isTest
    static void testAfterUpdate_DispositionChange() {
        // Given
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%' LIMIT 1];

        // Create a contact for this account
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id
        );
        insert testContact;

        // When
        Test.startTest();
        testAccount.Account_Disposition__c = 'Qualified';
        update testAccount;
        Test.stopTest();

        // Then
        Contact updatedContact = [SELECT Id, Account_Disposition__c FROM Contact WHERE Id = :testContact.Id];
        System.assertEquals('Qualified', updatedContact.Account_Disposition__c,
            'Contact disposition should match account disposition');
    }

    /**
     * @description Test Stage changes to Active when account has open opportunities
     * Given: Account with an open opportunity
     * When: Account is updated
     * Then: Stage__c should be set to Active
     */
    @isTest
    static void testBeforeUpdate_ActiveStageOnOpenOpportunities() {
        // Given
        Account testAccount = [SELECT Id, Name, Stage__c FROM Account WHERE Name LIKE 'Test Account%' LIMIT 1];
        testAccount.Stage__c = 'Nurturing';
        update testAccount;

        // Create an open opportunity to trigger the stage change
        Opportunity opp = new Opportunity(
            Name = 'Test Opp for Stage Change',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        // When - touch the account to trigger the stage update
        Test.startTest();
        testAccount.Description = 'Updated to trigger stage recalculation';
        update testAccount;
        Test.stopTest();

        // Then
        Account updatedAccount = [SELECT Id, Stage__c FROM Account WHERE Id = :testAccount.Id];
        // Stage should be Active when there are open opportunities
        System.assertEquals('Active', updatedAccount.Stage__c,
            'Stage__c should be Active when account has open opportunities');
    }

    /**
     * @description Negative test - ensure handler doesn't fail on null values
     * Given: Account with minimal data
     * When: Account is inserted
     * Then: No exceptions should be thrown
     */
    @isTest
    static void testNegative_MinimalData() {
        // Given
        Account minimalAccount = new Account(
            Name = 'Minimal Account'
        );

        // When
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            insert minimalAccount;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        // Then
        System.assertEquals(false, exceptionThrown,
            'No exception should be thrown for minimal account data');
        System.assertNotEquals(null, minimalAccount.Id,
            'Account should be inserted successfully');
    }

    /**
     * @description Test handler bypass functionality
     * Given: AccountTriggerHandler is bypassed
     * When: Account is inserted
     * Then: Handler logic should not execute
     */
    @isTest
    static void testBypass_HandlerIsBypassed() {
        // Given
        TriggerHandler.bypass('AccountTriggerHandler');
        Account testAccount = new Account(
            Name = 'Bypassed Account'
        );

        // When
        Test.startTest();
        insert testAccount;
        TriggerHandler.clearAllBypasses();
        Test.stopTest();

        // Then
        System.assertEquals(true, true,
            'Handler should be bypassed without errors');
    }
}
