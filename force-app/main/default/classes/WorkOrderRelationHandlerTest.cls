/**
 * Created by brist on 9/18/2024.
 */
@IsTest
public with sharing class WorkOrderRelationHandlerTest {
    static void setupTestData() {
        // Create test Accounts
        Account account1 = new Account(Name = 'Test Account 1');
        Account account2 = new Account(Name = 'Test Account 2');
        insert new List<Account>{account1, account2};
    }

    @IsTest
    static void testRelateUnrelatedAppointments() {
        // Fetch Accounts created in test setup
        List<Account> accounts = [SELECT Id FROM Account];
        List<Id> accountIds = new List<Id>();
        for(Account acc : accounts) {
            accountIds.add(acc.Id);
        }

        // Mock WorkOrderRelationHelper methods, if applicable
        Test.startTest();

        // Call the method under test
        WorkOrderRelationHandler.RelateUnrelatedAppointmentsFromAccountIds(accountIds);

        Test.stopTest();

        // Add assertions to verify the behavior of your method.
        // For example, you can check if the logic inside the helper method was executed as expected.
        // Since we're not entirely sure what `WorkOrderRelationHelper` does, the assertion should check what it impacts.

        // Example:
        // Assert some expected outcome in the database
        // WorkOrder[] workOrders = [SELECT Id, AccountId FROM WorkOrder WHERE AccountId IN :accountIds];
        // System.assertEquals(expectedCount, workOrders.size(), 'Expected number of Work Orders related');
    }
    @IsTest
    static void testRelateUnrelatedAppointmentsFromAccountIds(){
        List<Account> testAccounts = [SELECT Id FROM Account WHERE Name LIKE 'Test Account _'];
        List<Id> testIds = new List<Id>();
        for (Account a : testAccounts){
            testIds.add(a.Id);
        }
        Test.startTest();
        WorkOrderRelationHandler.RelateUnrelatedAppointmentsFromAccountIds(testIds);
        Test.stopTest();
    }
}