/**
 * Created by AdrienP on 10/31/2025.
 */

@IsTest
private class AppointmentCalendarUpdaterTest {

    // --- Test Utilities ---

    private static Account makeAccount() {
        Account a = new Account(Name = 'Acme Co');
        insert a;

        Contact c = new Contact(
                FirstName = 'Test',
                LastName = 'Contact',
                Email = 'test@example.com',
                AccountId = a.Id
        );
        insert c;

        return a;
    }

    private static Opportunity makeOpportunity(Id ownerId, Id accountId) {
        Opportunity o = new Opportunity(
                Name = 'Test Opp',
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                OwnerId = ownerId,
                AccountId = accountId
        );
        insert o;
        return o;
    }

    private static WorkOrder makeWorkOrder(Id acctId, Id oppId) {
        WorkOrder wo = new WorkOrder(
                Subject = 'Test Work Order',
                Status  = 'New',
                AccountId = acctId,
                Opportunity__c = oppId
        );
        insert wo;
        return wo;
    }

    private static ServiceAppointment makeServiceAppt(Id woId, Datetime startTime, Datetime endTime, Id acctId) {
        ServiceAppointment sa = new ServiceAppointment(
                ParentRecordId = woId,
                SchedStartTime = startTime,
                SchedEndTime = endTime,
                EarliestStartTime = startTime, // Avoid FSL validation errors
                Status = 'Scheduled',
                Subject = 'Test Appointment'
        );
        insert sa;
        return sa;
    }

    // --- Test Case ---
    @IsTest
    static void testRescheduleAppointment() {
        Id me = UserInfo.getUserId();

        Account acct = makeAccount();
        Opportunity opp = makeOpportunity(me, acct.Id);
        WorkOrder wo = makeWorkOrder(acct.Id, opp.Id);

        Datetime originalStart = System.now().addDays(1);
        Datetime originalEnd = originalStart.addHours(1);

        ServiceAppointment sa = makeServiceAppt(wo.Id, originalStart, originalEnd, acct.Id);

        // New datetime to reschedule to
        Datetime newTime = System.now().addDays(3).addHours(10);

        Test.startTest();
        AppointmentCalendarUpdater.rescheduleAppointment(sa.Id, newTime);
        Test.stopTest();

        // Query updated values
        ServiceAppointment updated = [
                SELECT Id, SchedStartTime, SchedEndTime
                FROM ServiceAppointment
                WHERE Id = :sa.Id
                LIMIT 1
        ];

        System.assertEquals(newTime.date(), updated.SchedStartTime.date(), 'Start time should be updated');
        System.assertEquals(newTime.addHours(1).date(), updated.SchedEndTime.date(), 'End time should be +1 hour');
    }
}