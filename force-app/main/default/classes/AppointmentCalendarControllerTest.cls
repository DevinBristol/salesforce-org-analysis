/**
 * Created by AdrienP on 10/28/2025.
 */

@IsTest
private class AppointmentCalendarControllerTest {

    // Utility: make a basic Account *with one Contact* so wrappers have a valid contact name
    private static Account makeAccount() {
        Account a = new Account(Name = 'Acme Co');
        insert a;

        // 👇 ensure every account has one contact
        Contact c = new Contact(
                FirstName = 'Test',
                LastName  = 'Contact',
                Email     = 'test@example.com',
                AccountId = a.Id
        );
        insert c;

        return a;
    }

    // Utility: make an Opportunity owned by a specific user
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

    // Utility: make a WorkOrder (no Opportunity__c reference)
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

    // Utility: create a ServiceAppointment; any of start/end may be null
    private static ServiceAppointment makeServiceAppt(
            Id woId,
            Datetime schedStart,
            Datetime schedEnd,
            Datetime earliestStart,
            Id accountId,
            String status,
            String subject
    ) {
        ServiceAppointment sa = new ServiceAppointment(
                ParentRecordId = woId,
                SchedStartTime = schedStart,
                SchedEndTime   = schedEnd,
                EarliestStartTime = earliestStart,
                Status = status,
                Subject = subject
        );
        insert sa;
        return sa;
    }

    // Utility: create a throwaway user (for team-member test)
    private static User makeUser(String unameSuffix) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
                Alias = 'tm' + unameSuffix.left(3),
                Email = 'tm' + unameSuffix + '@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Member' + unameSuffix,
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                TimeZoneSidKey = 'America/Chicago',
                Username = 'tm' + unameSuffix + '@example.com.' + System.currentTimeMillis(),
                ProfileId = p.Id
        );
        insert u;
        return u;
    }

    // ---- Test 1: Happy path (owned opportunity)
    /*
    @IsTest
    static void testOwnedOpp_InWindow_SchedStart() {
        Id me = UserInfo.getUserId();
        Integer year = 2025, month = 3;
        Datetime startWin = Datetime.newInstanceGmt(year, month, 1, 0, 0, 0);
        Datetime midMonth = startWin.addDays(10).addHours(14);

        Account acct = makeAccount();
        Opportunity opp = makeOpportunity(me, acct.Id);
        WorkOrder wo = makeWorkOrder(acct.Id, opp.Id);

        // In-window appointment using SchedStart/SchedEnd
        ServiceAppointment sa = makeServiceAppt(
                wo.Id,
                midMonth,
                midMonth.addHours(2),
                null,
                acct.Id,
                'Scheduled',
                'Install Router'
        );

        Test.startTest();
        List<AppointmentCalendarController.AppointmentWrapper> res =
                AppointmentCalendarController.getAppointmentsForMonth(me, year, month);
        Test.stopTest();

        System.assertEquals(1, res.size(), 'Should return one appointment');
        AppointmentCalendarController.AppointmentWrapper w = res[0];

        System.assertEquals(sa.Id, w.id);
        System.assertEquals('Install Router', w.subject);
        System.assertEquals('Scheduled', w.status);
        System.assertEquals(wo.Id, w.parentWorkOrderId);
        System.assertEquals('blue', w.statusColor, 'Scheduled → blue');
        System.assertNotEquals(null, w.startDateFormatted);
        System.assertNotEquals(null, w.dayLabel);
        System.assertNotEquals(null, w.monthLabel);
    }
     */

    // ---- Test 2: Uses EarliestStartTime when SchedStartTime is null
    @IsTest
    static void testUsesEarliestStartWhenSchedNull() {
        Id me = UserInfo.getUserId();
        Integer year = 2025, month = 4;
        Datetime winStart = Datetime.newInstanceGmt(year, month, 1, 0, 0, 0);
        Datetime earliest = winStart.addDays(5).addHours(9);

        Account acct = makeAccount();
        Opportunity opp = makeOpportunity(me, acct.Id);
        WorkOrder wo = makeWorkOrder(acct.Id, opp.Id);

        ServiceAppointment sa = makeServiceAppt(
                wo.Id, null, null, earliest, acct.Id, 'In Progress', 'Survey Site'
        );

        Test.startTest();
        List<AppointmentCalendarController.AppointmentWrapper> res =
                AppointmentCalendarController.getAppointmentsForMonth(me, year, month);
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(earliest, res[0].startDate);
        System.assertEquals('orange', res[0].statusColor);
    }

    // ---- Test 3: Excludes appointments outside the month window
    /*
    @IsTest
    static void testExcludesOutsideWindow() {
        Id me = UserInfo.getUserId();
        Integer year = 2025, month = 5;
        Datetime winStart = Datetime.newInstanceGmt(year, month, 1, 0, 0, 0);
        Datetime inWindow = winStart.addDays(1).addHours(8);
        Datetime prevMonth = winStart.addDays(-1);
        Datetime nextMonth = winStart.addMonths(1);

        Account acct = makeAccount();
        Opportunity opp = makeOpportunity(me, acct.Id);
        WorkOrder wo = makeWorkOrder(acct.Id, opp.Id);

        makeServiceAppt(wo.Id, inWindow, inWindow.addHours(1), null, acct.Id, 'Scheduled', 'In Window');
        makeServiceAppt(wo.Id, prevMonth, prevMonth.addHours(1), null, acct.Id, 'Scheduled', 'Prev Month');
        makeServiceAppt(wo.Id, nextMonth, nextMonth.addHours(1), null, acct.Id, 'Scheduled', 'Next Month');

        Test.startTest();
        List<AppointmentCalendarController.AppointmentWrapper> res =
                AppointmentCalendarController.getAppointmentsForMonth(me, year, month);
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals('In Window', res[0].subject);
    }
    */

    // ---- Test 4: Team member access via OpportunityTeamMember
    @IsTest
    static void testTeamMemberOppAccess() {
        Id me = UserInfo.getUserId();
        User owner = makeUser('owner1');

        Integer year = 2025, month = 6;
        Datetime winStart = Datetime.newInstanceGmt(year, month, 1, 0, 0, 0);
        Datetime apptTime = winStart.addDays(3).addHours(10);

        Account acct = makeAccount();
        Opportunity opp = makeOpportunity(owner.Id, acct.Id);

        OpportunityTeamMember tm = new OpportunityTeamMember(
                OpportunityId = opp.Id,
                UserId = me,
                TeamMemberRole = 'Sales'
        );
        insert tm;

        WorkOrder wo = makeWorkOrder(acct.Id, opp.Id);
        ServiceAppointment sa = makeServiceAppt(
                wo.Id, apptTime, apptTime.addHours(2), null, acct.Id, 'Scheduled', 'Team Access SA'
        );

        Test.startTest();
        List<AppointmentCalendarController.AppointmentWrapper> res =
                AppointmentCalendarController.getAppointmentsForMonth(me, year, month);
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(sa.Id, res[0].id);
    }

    // ---- Test 5: No opportunities -> empty
    @IsTest
    static void testNoOpportunitiesReturnsEmpty() {
        Id me = UserInfo.getUserId();
        Integer year = 2025, month = 7;

        Test.startTest();
        List<AppointmentCalendarController.AppointmentWrapper> res =
                AppointmentCalendarController.getAppointmentsForMonth(me, year, month);
        Test.stopTest();

        System.assertEquals(0, res.size());
    }

    // ---- Test 6: Status → statusColor mapping
    /*
    @IsTest
    static void testStatusColorMapping() {
        Id me = UserInfo.getUserId();
        Integer year = 2025, month = 8;
        Datetime winStart = Datetime.newInstanceGmt(year, month, 1, 0, 0, 0);

        Account acct = makeAccount();
        Opportunity opp = makeOpportunity(me, acct.Id);
        WorkOrder wo = makeWorkOrder(acct.Id, opp.Id);

        Datetime t1 = winStart.addDays(2).addHours(9);
        Datetime t2 = winStart.addDays(3).addHours(11);
        Datetime t3 = winStart.addDays(4).addHours(13);
        Datetime t4 = winStart.addDays(5).addHours(15);

        makeServiceAppt(wo.Id, t1, t1.addHours(1), null, acct.Id, 'Completed',   'A');
        makeServiceAppt(wo.Id, t2, t2.addHours(1), null, acct.Id, 'In Progress', 'B');
        makeServiceAppt(wo.Id, t3, t3.addHours(1), null, acct.Id, 'Scheduled',   'C');
        makeServiceAppt(wo.Id, t4, t4.addHours(1), null, acct.Id, 'FooBar',      'D');

        Test.startTest();
        List<AppointmentCalendarController.AppointmentWrapper> res =
                AppointmentCalendarController.getAppointmentsForMonth(me, year, month);
        Test.stopTest();

        Map<String,String> colorBySubject = new Map<String,String>();
        for (AppointmentCalendarController.AppointmentWrapper w : res) {
            colorBySubject.put(w.subject, w.statusColor);
        }

        System.assertEquals('green',  colorBySubject.get('A'));
        System.assertEquals('orange', colorBySubject.get('B'));
        System.assertEquals('blue',   colorBySubject.get('C'));
        System.assertEquals('neutral',colorBySubject.get('D'));
    }
    */

    @IsTest
    static void testOverdueAppointments_ReturnsPendingPastDue() {
        Id me = UserInfo.getUserId();
        Datetime now = System.now();

        Account acct = makeAccount();
        Opportunity opp = makeOpportunity(me, acct.Id);
        WorkOrder wo = makeWorkOrder(acct.Id, opp.Id);

        // Past appointment, Pending → should return
        Datetime pastStart = now.addDays(-3);
        Datetime pastEnd   = now.addDays(-2);

        makeServiceAppt(
                wo.Id,
                pastStart,
                pastEnd,
                null,
                acct.Id,
                'Scheduled',
                'Past Pending'
        );

        // Explicitly set result to Pending
        ServiceAppointment sa = [
                SELECT Id FROM ServiceAppointment WHERE ParentRecordId = :wo.Id LIMIT 1
        ];
        sa.Appointment_Result_1__c = 'Pending';
        update sa;

        Test.startTest();
        List<AppointmentCalendarController.AppointmentWrapper> res =
                AppointmentCalendarController.getOverdueAppointments(me);
        Test.stopTest();

        System.assertEquals(1, res.size(), 'Should return one overdue pending appointment');
        System.assertEquals(sa.Id, res[0].id);
    }

    @IsTest
    static void testOverdueAppointments_ExcludesNonPendingOrFuture() {
        Id me = UserInfo.getUserId();
        Datetime now = System.now();

        Account acct = makeAccount();
        Opportunity opp = makeOpportunity(me, acct.Id);
        WorkOrder wo = makeWorkOrder(acct.Id, opp.Id);

        // Past appointment but Completed → should NOT return
        Datetime oldStart = now.addDays(-4);
        Datetime oldEnd   = now.addDays(-3);

        ServiceAppointment completedAppt = makeServiceAppt(
                wo.Id,
                oldStart,
                oldEnd,
                null,
                acct.Id,
                'Completed',
                'Old Completed'
        );

        // Set result — ensure EarliestStartTime to satisfy FSL validation
        completedAppt.Appointment_Result_1__c = 'Demo / Sale';
        completedAppt.EarliestStartTime = oldStart;
        update completedAppt;

        // Future Pending appointment → should NOT return
        Datetime futureStart = now.addDays(2);
        Datetime futureEnd   = now.addDays(3);

        ServiceAppointment futureAppt = makeServiceAppt(
                wo.Id,
                futureStart,
                futureEnd,
                null,
                acct.Id,
                'Scheduled',
                'Future Pending'
        );

        // Pending but future — also set EarliestStartTime so update doesn't fail
        futureAppt.Appointment_Result_1__c = 'Pending';
        futureAppt.EarliestStartTime = futureStart;
        update futureAppt;

        Test.startTest();
        List<AppointmentCalendarController.AppointmentWrapper> res =
                AppointmentCalendarController.getOverdueAppointments(me);
        Test.stopTest();

        System.assertEquals(0, res.size(), 'Should exclude completed or future appts');
    }
}