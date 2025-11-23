/**
 * Created by AdrienP on 11/20/2025.
 */

@IsTest
private class RundownExportControllerTest {

    // -----------------------------
    // UTILITIES
    // -----------------------------

    // Basic Account
    private static Account makeAccount() {
        Account a = new Account(
                Name  = 'Test Account',
                Phone = '4025551234'
        );
        insert a;
        return a;
    }

    // Property__c used via Opportunity_Property__r in controller
    private static Property__c makeProperty() {
        Property__c prop = new Property__c(
                Name = 'Test Property',
                yearbuilt__c = 1999,
                taxassessedvaluetotal__c = 250000,
                deedlastsaledate__c = Date.today().addYears(-5)
        );
        insert prop;
        return prop;
    }

    // Product + PBE for OLIs
    private static PricebookEntry makePricebookEntry(Product2 p) {
        Id stdPbId = Test.getStandardPricebookId();

        PricebookEntry pbe = new PricebookEntry(
                Product2Id   = p.Id,
                Pricebook2Id = stdPbId,
                UnitPrice    = 199.99,
                IsActive     = true
        );
        insert pbe;
        return pbe;
    }

    // Opportunity with Campaign + Property lookup + Description
    private static Opportunity makeOpportunity(Account acct, Property__c prop) {
        Campaign camp = new Campaign(Name = 'Google Ads');
        insert camp;

        Id stdPbId = Test.getStandardPricebookId();

        Opportunity opp = new Opportunity(
                Name        = 'Test Opportunity',
                StageName   = 'Prospecting',
                CloseDate   = Date.today().addDays(7),
                AccountId   = acct.Id,
                CampaignId  = camp.Id,
                Pricebook2Id = stdPbId,
                Description = 'Test opportunity description'
        );
        insert opp;

        // Link Property to Opportunity via lookup
        opp.Opportunity_Property__c = prop.Id;
        update opp;

        return opp;
    }

    // Add one OLI so productLine path executes
    private static void addOppLineItem(Opportunity opp) {
        Product2 prod = new Product2(
                Name = 'Water Softener',
                IsActive = true
        );
        insert prod;

        PricebookEntry pbe = makePricebookEntry(prod);

        OpportunityLineItem oli = new OpportunityLineItem(
                OpportunityId   = opp.Id,
                PricebookEntryId = pbe.Id,
                Quantity        = 1,
                TotalPrice      = 199.99
        );
        insert oli;
    }

    // Add an OpportunityTeamMember for salesperson list
    private static void addOppTeamMember(Opportunity opp) {
        User me = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        OpportunityTeamMember tm = new OpportunityTeamMember(
                OpportunityId = opp.Id,
                UserId        = me.Id,
                TeamMemberRole = 'Opportunity Owner'
        );
        insert tm;
    }

    // WorkOrder (same pattern as your other test class)
    private static WorkOrder makeWorkOrder(Account acct, Opportunity opp) {
        WorkOrder wo = new WorkOrder(
                Subject     = 'Test Work Order',
                Status      = 'New',
                AccountId   = acct.Id,
                Opportunity__c = opp.Id
        );
        insert wo;
        return wo;
    }

    // ServiceAppointment: do NOT touch AccountId (not writeable)
    private static ServiceAppointment makeServiceAppt(
            Id parentWorkOrderId,
            Datetime schedStart,
            String status,
            String resultVal
    ) {
        ServiceAppointment sa = new ServiceAppointment(
                ParentRecordId     = parentWorkOrderId,
                Status             = status,
                SchedStartTime     = schedStart,
                SchedEndTime       = schedStart.addHours(1),
                Appointment_Result_1__c = resultVal,
                Subject            = 'Test SA',
                Street             = '123 Main St',
                City               = 'Lincoln',
                State              = 'NE',
                PostalCode         = '68508'
        );
        insert sa;
        return sa;
    }

    @IsTest
    static void testGenerateRundownExcel_HappyPath() {
        Account acct     = makeAccount();
        Property__c prop = makeProperty();
        Opportunity opp  = makeOpportunity(acct, prop);

        addOppLineItem(opp);
        addOppTeamMember(opp);

        // WorkOrder ties Account + Opportunity together;
        // FSL triggers should populate SA.AccountId based on this.
        WorkOrder wo = makeWorkOrder(acct, opp);

        Datetime twoPmToday = Datetime.newInstance(
                Date.today().year(),
                Date.today().month(),
                Date.today().day(),
                14, 0, 0
        );

        ServiceAppointment sa = makeServiceAppt(
                wo.Id,
                twoPmToday,
                'Scheduled',
                'Result 1'
        );

        Test.startTest();
        String encoded = RundownExportController.generateRundownExcel(
                new List<Id>{ sa.Id }
        );
        Test.stopTest();

        System.assertNotEquals(null, encoded, 'Should return a base64 string');
        System.assert(encoded.length() > 0, 'Base64 string should not be empty');

        Blob xmlBlob = EncodingUtil.base64Decode(encoded);
        String xml   = xmlBlob.toString();

        System.assert(xml.contains('<Workbook'), 'XML must contain Workbook root');
        System.assert(xml.contains('Day of Week:'), 'Should contain header row');
        // We *can* check some content but avoid assuming AccountId behavior
        System.assert(xml.contains('Notes'), 'Should include Notes header');
    }

    @IsTest
    static void testGenerateRundownExcel_NoIdsProvided() {
        Test.startTest();
        Boolean threw = false;

        try {
            RundownExportController.generateRundownExcel(new List<Id>());
        } catch (AuraHandledException e) {
            threw = true;
            // Don't assert on the message — just confirm the exception happened
        }

        Test.stopTest();

        System.assert(threw, 'Expected AuraHandledException to be thrown');
    }

    @IsTest
    static void testGetTodayAppointments_ReturnsDTO() {
        // Create an Account with a phone so the addressBlock logic runs
        Account acct = new Account(
                Name = 'Today Test Account',
                Phone = '3085551111'
        );
        insert acct;

        // Create a WorkOrder (required parent for ServiceAppointment to populate AccountId)
        WorkOrder wo = new WorkOrder(
                Subject   = 'WO for Today SA',
                Status    = 'New',
                AccountId = acct.Id
        );
        insert wo;

        // Create a ServiceAppointment scheduled TODAY and NOT cancelled
        Datetime now = Datetime.newInstance(
                Date.today().year(),
                Date.today().month(),
                Date.today().day(),
                10, 0, 0
        );

        ServiceAppointment sa = new ServiceAppointment(
                ParentRecordId        = wo.Id,
                Status                = 'Scheduled',
                SchedStartTime        = now,
                SchedEndTime          = now.addHours(1),
                Appointment_Result_1__c = 'Result X',
                Subject               = 'Today SA',
                Street                = '123 Main St',
                City                  = 'Lincoln',
                State                 = 'NE',
                PostalCode            = '68508'
        );
        insert sa;

        Test.startTest();
        List<RundownExportController.RundownAppointmentDTO> results =
                RundownExportController.getTodayAppointments();
        Test.stopTest();

        // ✅ Should return exactly one record
        System.assertEquals(1, results.size(), 'Expected 1 DTO returned');

        // ✅ Validate mapped fields to hit code paths
        RundownExportController.RundownAppointmentDTO dto = results[0];
        System.assertEquals(sa.Id, dto.id);
        System.assert(dto.accountName != null, 'Account name should not be null');
        System.assert(dto.timeStr != null, 'Time string should be populated');
        System.assertEquals('Result X', dto.result1);
        System.assert(dto.ownerName != null, 'OwnerName should be returned (may be empty string)');
        System.assert(dto.address.contains('308-555-1111'), 'Should contain formatted phone');
        System.assert(dto.address.contains('123 Main St'), 'Should contain street');
    }

}