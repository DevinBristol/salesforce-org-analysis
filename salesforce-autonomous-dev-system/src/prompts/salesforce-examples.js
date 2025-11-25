// src/prompts/salesforce-examples.js - Few-Shot Examples for Salesforce Code Generation
// Based on Anthropic's recommendation to include "parameter clarity, example invocations,
// and usage constraints—analogous to quality docstrings for junior developers"

/**
 * Few-Shot Examples for Apex Code Improvements
 *
 * These examples teach the model the exact transformations we expect.
 * Each example shows:
 * 1. The problematic pattern
 * 2. The improved pattern
 * 3. Explanation of why
 */

export const APEX_IMPROVEMENT_EXAMPLES = `
## Few-Shot Examples for Apex Improvements

### Example 1: Adding Empty Checks Before DML

**Before (problematic):**
\`\`\`apex
public void updateAccounts(List<Account> accounts) {
    update accounts;
}
\`\`\`

**After (improved):**
\`\`\`apex
public void updateAccounts(List<Account> accounts) {
    if (accounts == null || accounts.isEmpty()) {
        return;
    }
    update accounts;
}
\`\`\`

**Why:** DML on empty/null lists wastes a DML statement and can cause unexpected errors.

---

### Example 2: Replacing Magic Numbers with Constants

**Before (problematic):**
\`\`\`apex
List<Account> accountsNameable = NamingUtility.NameAccount(recordLists[2]);
PhoneRelationHandler.HandlePhonesFromContacts(recordLists[3]);
ContactTriggerHelper.DeformatContactNumbers(recordLists[4]);
\`\`\`

**After (improved):**
\`\`\`apex
// Constants at class level
private static final Integer ACCOUNTS_NAMEABLE_INDEX = 2;
private static final Integer PHONE_RECORDS_INDEX = 3;
private static final Integer DEFORMAT_RECORDS_INDEX = 4;

// In method
List<Account> accountsNameable = NamingUtility.NameAccount(recordLists[ACCOUNTS_NAMEABLE_INDEX]);
PhoneRelationHandler.HandlePhonesFromContacts(recordLists[PHONE_RECORDS_INDEX]);
ContactTriggerHelper.DeformatContactNumbers(recordLists[DEFORMAT_RECORDS_INDEX]);
\`\`\`

**Why:** Magic numbers are unclear and error-prone. Constants are self-documenting.

---

### Example 3: Moving DML Out of Trigger Handler

**Before (problematic):**
\`\`\`apex
public override void afterInsert() {
    List<Account> accountsNameable = NamingUtility.NameAccount(recordLists[2]);
    update accountsNameable;  // DML directly in handler!
}
\`\`\`

**After (improved):**
\`\`\`apex
// Handler delegates to service
public override void afterInsert() {
    List<Account> accountsNameable = NamingUtility.NameAccount(recordLists[ACCOUNTS_NAMEABLE_INDEX]);
    dmlService.updateAccountsSafely(accountsNameable);
}

// Separate DML service class
public class ContactDMLService {
    public void updateAccountsSafely(List<Account> accounts) {
        if (accounts == null || accounts.isEmpty()) {
            return;
        }
        try {
            update accounts;
        } catch (DmlException e) {
            // Log error, don't swallow silently
            Logger.error('Account update failed', e);
            throw e;
        }
    }
}
\`\`\`

**Why:** Separates concerns, enables testing, centralizes DML logic.

---

### Example 4: Adding Try-Catch Error Handling

**Before (problematic):**
\`\`\`apex
public void processContacts(List<Contact> contacts) {
    for (Contact c : contacts) {
        c.Email = validateEmail(c.Email);
    }
    update contacts;
}
\`\`\`

**After (improved):**
\`\`\`apex
public void processContacts(List<Contact> contacts) {
    if (contacts == null || contacts.isEmpty()) {
        return;
    }

    try {
        for (Contact c : contacts) {
            c.Email = validateEmail(c.Email);
        }

        Database.SaveResult[] results = Database.update(contacts, false);
        handleDmlResults(results, contacts);

    } catch (Exception e) {
        Logger.error('Contact processing failed', e);
        throw new ContactProcessingException('Failed to process contacts: ' + e.getMessage(), e);
    }
}

private void handleDmlResults(Database.SaveResult[] results, List<Contact> contacts) {
    for (Integer i = 0; i < results.size(); i++) {
        if (!results[i].isSuccess()) {
            for (Database.Error err : results[i].getErrors()) {
                Logger.error('Failed to update contact ' + contacts[i].Id + ': ' + err.getMessage());
            }
        }
    }
}
\`\`\`

**Why:** Graceful error handling, detailed logging, no silent failures.

---

### Example 5: Bulkification Pattern

**Before (problematic):**
\`\`\`apex
for (Contact c : contacts) {
    Account acc = [SELECT Id, Name FROM Account WHERE Id = :c.AccountId];
    c.Description = 'Account: ' + acc.Name;
}
update contacts;
\`\`\`

**After (improved):**
\`\`\`apex
// Collect all Account IDs first
Set<Id> accountIds = new Set<Id>();
for (Contact c : contacts) {
    if (c.AccountId != null) {
        accountIds.add(c.AccountId);
    }
}

// Single query for all accounts
Map<Id, Account> accountMap = new Map<Id, Account>(
    [SELECT Id, Name FROM Account WHERE Id IN :accountIds]
);

// Update contacts using the map
for (Contact c : contacts) {
    if (c.AccountId != null && accountMap.containsKey(c.AccountId)) {
        c.Description = 'Account: ' + accountMap.get(c.AccountId).Name;
    }
}

if (!contacts.isEmpty()) {
    update contacts;
}
\`\`\`

**Why:** SOQL in loops hits governor limits. Bulk pattern scales to any volume.
`;

export const APEX_TEST_EXAMPLES = `
## Few-Shot Examples for Apex Test Generation

### Example 1: Basic Test Structure

**For this class:**
\`\`\`apex
public class AccountService {
    public void updateAccountNames(List<Account> accounts) {
        if (accounts == null || accounts.isEmpty()) return;
        for (Account a : accounts) {
            a.Name = a.Name.toUpperCase();
        }
        update accounts;
    }
}
\`\`\`

**Generate this test:**
\`\`\`apex
@isTest
private class AccountServiceTest {

    @TestSetup
    static void setupTestData() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        insert accounts;
    }

    @isTest
    static void testUpdateAccountNames_WithValidAccounts_UpdatesNames() {
        // Arrange
        List<Account> accounts = [SELECT Id, Name FROM Account LIMIT 50];
        AccountService service = new AccountService();

        // Act
        Test.startTest();
        service.updateAccountNames(accounts);
        Test.stopTest();

        // Assert
        List<Account> updatedAccounts = [SELECT Name FROM Account WHERE Id IN :accounts];
        for (Account a : updatedAccounts) {
            System.assert(a.Name == a.Name.toUpperCase(), 'Name should be uppercase');
        }
    }

    @isTest
    static void testUpdateAccountNames_WithNullList_DoesNothing() {
        // Arrange
        AccountService service = new AccountService();

        // Act
        Test.startTest();
        service.updateAccountNames(null);
        Test.stopTest();

        // Assert - no exception thrown
        System.assert(true, 'Should handle null gracefully');
    }

    @isTest
    static void testUpdateAccountNames_WithEmptyList_DoesNothing() {
        // Arrange
        AccountService service = new AccountService();
        List<Account> emptyList = new List<Account>();

        // Act
        Test.startTest();
        service.updateAccountNames(emptyList);
        Test.stopTest();

        // Assert - no exception thrown
        System.assert(true, 'Should handle empty list gracefully');
    }

    @isTest
    static void testUpdateAccountNames_BulkOperation_HandlesLargeVolume() {
        // Arrange
        List<Account> accounts = [SELECT Id, Name FROM Account];
        System.assertEquals(200, accounts.size(), 'Should have 200 test accounts');
        AccountService service = new AccountService();

        // Act
        Test.startTest();
        service.updateAccountNames(accounts);
        Test.stopTest();

        // Assert
        List<Account> updatedAccounts = [SELECT Name FROM Account];
        for (Account a : updatedAccounts) {
            System.assert(a.Name == a.Name.toUpperCase(), 'All names should be uppercase');
        }
    }
}
\`\`\`

**Why this test is comprehensive:**
1. Uses @TestSetup for efficiency
2. Tests positive case (valid input)
3. Tests null handling
4. Tests empty list handling
5. Tests bulk operations (200 records)
6. Uses Test.startTest()/stopTest() for governor limits
7. Uses meaningful test method names
8. Follows Arrange/Act/Assert pattern

---

### Example 2: Testing Trigger Handlers

**For this trigger handler:**
\`\`\`apex
public class ContactTriggerHandler extends TriggerHandler {
    public override void beforeInsert() {
        validateContacts((List<Contact>)Trigger.new);
    }

    private void validateContacts(List<Contact> contacts) {
        for (Contact c : contacts) {
            if (String.isBlank(c.Email)) {
                c.addError('Email is required');
            }
        }
    }
}
\`\`\`

**Generate this test:**
\`\`\`apex
@isTest
private class ContactTriggerHandlerTest {

    @isTest
    static void testBeforeInsert_WithValidEmail_InsertsSuccessfully() {
        // Arrange
        Contact c = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test@example.com'
        );

        // Act
        Test.startTest();
        Database.SaveResult result = Database.insert(c, false);
        Test.stopTest();

        // Assert
        System.assert(result.isSuccess(), 'Contact should insert successfully');

        Contact inserted = [SELECT Email FROM Contact WHERE Id = :c.Id];
        System.assertEquals('test@example.com', inserted.Email);
    }

    @isTest
    static void testBeforeInsert_WithMissingEmail_ReturnsError() {
        // Arrange
        Contact c = new Contact(
            FirstName = 'Test',
            LastName = 'Contact'
            // Email intentionally missing
        );

        // Act
        Test.startTest();
        Database.SaveResult result = Database.insert(c, false);
        Test.stopTest();

        // Assert
        System.assert(!result.isSuccess(), 'Insert should fail');
        System.assert(
            result.getErrors()[0].getMessage().contains('Email is required'),
            'Error message should mention email'
        );
    }

    @isTest
    static void testBeforeInsert_BulkWithMixedValidity_PartialSuccess() {
        // Arrange
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 100; i++) {
            contacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                Email = (Math.mod(i, 2) == 0) ? 'test' + i + '@example.com' : null
            ));
        }

        // Act
        Test.startTest();
        Database.SaveResult[] results = Database.insert(contacts, false);
        Test.stopTest();

        // Assert
        Integer successCount = 0;
        Integer failureCount = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                successCount++;
            } else {
                failureCount++;
            }
        }

        System.assertEquals(50, successCount, '50 contacts should succeed');
        System.assertEquals(50, failureCount, '50 contacts should fail');
    }
}
\`\`\`
`;

export const REFACTOR_SYSTEM_PROMPT = `You are an expert Salesforce developer performing TARGETED REFACTORING.

## CRITICAL RULES - YOU MUST FOLLOW THESE

1. **PRESERVE ALL EXISTING BUSINESS LOGIC**
   - Do NOT remove or change functionality
   - Keep all existing method signatures
   - Maintain all helper class calls

2. **PRESERVE CLASS INHERITANCE**
   - If class extends TriggerHandler, keep that
   - Do NOT change parent classes

3. **MINIMAL CHANGES ONLY**
   - Make ONLY the requested improvements
   - Do NOT refactor unrelated code
   - Do NOT add features not requested

4. **NO COMPLETE REWRITES**
   - Edit existing code, don't replace it
   - Show diff-style changes when possible

${APEX_IMPROVEMENT_EXAMPLES}

## Output Format

Return JSON with ONLY the files that changed:
{
    "apex": {
        "ClassName.cls": "// Full improved code"
    },
    "changesDescription": "Brief description of each change made",
    "preservedLogic": ["list of business logic that was preserved"],
    "warnings": ["any concerns about the changes"]
}
`;

export const GREENFIELD_SYSTEM_PROMPT = `You are an expert Salesforce developer creating NEW code from scratch.

## Guidelines for New Code

1. **Follow Best Practices**
   - All code must be bulkified
   - Include proper error handling
   - Add comprehensive comments

2. **Testability**
   - Use dependency injection
   - Avoid static methods where possible
   - Create mockable interfaces

3. **Security**
   - Use "with sharing" by default
   - Avoid hardcoded IDs
   - Sanitize all inputs

${APEX_IMPROVEMENT_EXAMPLES}

${APEX_TEST_EXAMPLES}

## Output Format

Return JSON:
{
    "apex": {
        "MainClass.cls": "code",
        "ServiceClass.cls": "code"
    },
    "tests": {
        "MainClassTest.cls": "test code"
    },
    "metadata": {
        "CustomField.field-meta.xml": "metadata xml"
    },
    "instructions": "Deployment instructions"
}
`;

export const TEST_GENERATION_PROMPT = `You are an expert at writing Salesforce Apex test classes.

## Requirements

1. **Coverage Target: 90%+**
   - Test all public methods
   - Test all code paths
   - Test exception handling

2. **Test Categories Required**
   - Positive tests (happy path)
   - Negative tests (error cases)
   - Boundary tests (edge cases)
   - Bulk tests (200+ records)

3. **Test Structure**
   - Use @TestSetup for data creation
   - Use Test.startTest()/stopTest()
   - Follow Arrange/Act/Assert pattern
   - Use meaningful method names

${APEX_TEST_EXAMPLES}

## Output Format

Return JSON:
{
    "tests": {
        "ClassNameTest.cls": "// Complete test class"
    },
    "coverageEstimate": 95,
    "testMethods": [
        {
            "name": "testMethodName",
            "covers": ["ClassName.methodA", "ClassName.methodB"],
            "scenario": "description"
        }
    ]
}
`;

export default {
    APEX_IMPROVEMENT_EXAMPLES,
    APEX_TEST_EXAMPLES,
    REFACTOR_SYSTEM_PROMPT,
    GREENFIELD_SYSTEM_PROMPT,
    TEST_GENERATION_PROMPT
};
