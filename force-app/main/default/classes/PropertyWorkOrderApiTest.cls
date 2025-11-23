/**
 * Created by Devin on 10/30/2025.
 */

@IsTest
private class PropertyWorkOrderApiTest {

    @TestSetup
    static void data() {
        // --- Standard Price Book (safe pattern in tests) ---
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        // --- Operating Hours (REQUIRED for ServiceTerritory) ---
        OperatingHours oh;
        List<OperatingHours> existing = [SELECT Id FROM OperatingHours LIMIT 1];
        if (existing.isEmpty()) {
            // TimeZone must be a valid TZ identifier
            oh = new OperatingHours(Name = 'Test Hours', TimeZone = 'America/Chicago');
            insert oh;
        } else {
            oh = existing[0];
        }

        // --- Service Territory (must reference OperatingHoursId) ---
        ServiceTerritory st = new ServiceTerritory(
                Name = 'Greater Metro',
                OperatingHoursId = oh.Id,
                IsActive = true
        );
        insert st;

        // --- WorkType (some orgs require these fields) ---
        WorkType wt = new WorkType(
                Name = 'Initial Visit',
                EstimatedDuration = 60,
                DurationType = 'Minutes'
        );
        insert wt;

        // --- Products + Standard PBEs ---
        Product2 p1 = new Product2(Name='Starter Inspection', IsActive=true);
        Product2 p2 = new Product2(Name='Filter', IsActive=true);
        insert new List<Product2>{ p1, p2 };

        insert new List<PricebookEntry>{
                new PricebookEntry(Pricebook2Id=stdPbId, Product2Id=p1.Id, UnitPrice=199, IsActive=true, UseStandardPrice=false),
                new PricebookEntry(Pricebook2Id=stdPbId, Product2Id=p2.Id, UnitPrice=100, IsActive=true, UseStandardPrice=false)
        };

        // --- Account + Opportunity ---
        Account a = new Account(Name='API Test Account');
        insert a;

        Opportunity o = new Opportunity(
                Name='API Test Opportunity 420 Main',
                StageName='Prospecting',
                CloseDate=Date.today().addDays(30),
                AccountId=a.Id
        );
        insert o;
    }



    private static RestRequest makeReq(String body, Map<String,String> headers){
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/propertywo/v1';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type','application/json');
        if (headers != null) for (String k : headers.keySet()) req.addHeader(k, headers.get(k));
        req.requestBody = Blob.valueOf(body);
        return req;
    }

    // ---------- Tests ----------

    @IsTest
    static void test_happyPath_partialSuccess_noSA() {
        // Ensure no shared-secret is required
        PropertyWorkOrderApi.REQUIRE_SHARED_SECRET = false;

        Account a = [SELECT Id FROM Account LIMIT 1];
        Opportunity o = [SELECT Id, Amount FROM Opportunity LIMIT 1];

        // Build payload (with appointment time to exercise SA branch)
        Datetime start = Datetime.now().addDays(2);
        String payload = JSON.serialize(new Map<String, Object>{
                'accountId' => a.Id,
                'opportunityId' => o.Id,
                'appointmentTime' => start.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
                'address' => new Map<String, Object>{
                        'street' => '420 Main St',
                        'city' => 'Austin',
                        'stateCode' => 'TX',
                        'postalCode' => '78701',
                        'countryCode' => 'US'
                },
                'lineItems' => new List<Object>{
                        new Map<String, Object>{ 'name' => 'Starter Inspection', 'quantity' => 1 },
                        new Map<String, Object>{ 'name' => 'Filter', 'quantity' => 2 }
                },
                'workTypeNameLike' => 'Initial',
                'serviceTerritoryNameLike' => 'Greater'
        });
        System.debug(payload);
        RestContext.request  = makeReq(payload, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        PropertyWorkOrderApi.ResponseDTO out = PropertyWorkOrderApi.createAll();
        System.debug(out);
        Test.stopTest();

        System.assertNotEquals(null, out, 'Response should not be null');

// May be 201 (everything created) OR 207 (created with errors, e.g., no SA)
        System.assertEquals(true, out.statusCode == 201 || out.statusCode == 207,
                'Expect 201 (all good) or 207 (partial), got ' + out.statusCode);

        System.assertNotEquals(null, out.propertyId, 'Property should be created or matched');
        System.assertNotEquals(null, out.workOrderId, 'Work Order should be created');
        System.assertNotEquals(null, out.quoteId, 'Quote should be created');
        System.assertEquals(2, out.quoteLineItemIds.size(), 'Two QLIs expected');
        System.assertEquals(199 + (2*100), out.opportunityAmount, 'Opportunity amount should reflect QLIs total');

// If SA wasn’t created by org logic, we should have the “lookup not found” error
        if (out.serviceAppointmentId == null) {
            Boolean hasSaLookupError = false;
            for (PropertyWorkOrderApi.ErrorInfo e : out.errors) {
                if (e.step == 'serviceappointment.lookup' && e.reason == 'NotFound') { hasSaLookupError = true; break; }
            }
            System.assertEquals(true, hasSaLookupError,
                    'Should record SA not found error when no ServiceAppointment exists');
        }
    }

    @IsTest
    static void test_badJson_400() {
        PropertyWorkOrderApi.REQUIRE_SHARED_SECRET = false;

        RestContext.request  = makeReq('{"bad json"', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        PropertyWorkOrderApi.ResponseDTO out = PropertyWorkOrderApi.createAll();
        Test.stopTest();

        System.assertEquals(400, out.statusCode);
        System.assertEquals(false, out.success);
    }

    @IsTest
    static void test_unauthorized_401_when_secret_required() {
        // Require secret but omit header
        PropertyWorkOrderApi.REQUIRE_SHARED_SECRET = true;
        PropertyWorkOrderApi.SHARED_SECRET = 'topsecret';

        RestContext.request  = makeReq('{"anything":"ok"}', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        PropertyWorkOrderApi.ResponseDTO out = PropertyWorkOrderApi.createAll();
        Test.stopTest();

        System.assertEquals(401, out.statusCode);
        System.assertEquals(false, out.success);
    }

    @IsTest
    static void test_nothingCreated_400_missingIds_and_address() {
        PropertyWorkOrderApi.REQUIRE_SHARED_SECRET = false;

        // Missing account/opportunity AND no address -> nothing can be created
        String payload = JSON.serialize(new Map<String, Object>{
                'appointmentTime' => Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
                'lineItems' => new List<Object>()
        });

        RestContext.request  = makeReq(payload, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        PropertyWorkOrderApi.ResponseDTO out = PropertyWorkOrderApi.createAll();
        Test.stopTest();

        System.assertEquals(400, out.statusCode, 'Should fail when nothing created');
        System.assertEquals(false, out.success);
    }
    @IsTest
    static void test_stateResolution_zip_overrides_providedName() {
        // No shared-secret required in tests
        PropertyWorkOrderApi.REQUIRE_SHARED_SECRET = false;

        // Use the Account/Opportunity from @TestSetup
        Account a = [SELECT Id FROM Account LIMIT 1];
        Opportunity o = [SELECT Id FROM Opportunity LIMIT 1];

        // Provide a mismatched full state name ("Iowa") with a Nebraska ZIP+4 (68102-1234).
        // Expect result: Property.Address__StateCode__s == 'NE' and a logged 'Mismatch' warning.
        String payload = JSON.serialize(new Map<String, Object>{
                'accountId' => a.Id,
                'opportunityId' => o.Id,
                'address' => new Map<String, Object>{
                        'street' => '999 Coverage Way',
                        'city' => 'Omaha',
                        'stateCode' => 'Iowa',            // full name, will be normalized to IA
                        'postalCode' => '68102-1234',     // NE (ZIP wins over provided name)
                        'countryCode' => 'US'
                }
                // No line items, no appt time needed; we only need the Property insert
        });

        RestContext.request  = makeReq(payload, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        PropertyWorkOrderApi.ResponseDTO out = PropertyWorkOrderApi.createAll();
        Test.stopTest();

        System.assertNotEquals(null, out, 'Response should not be null');
        System.assertNotEquals(null, out.propertyId, 'Property should have been created');

        // Verify the normalization chose NE (from ZIP), not IA (from name)
        Property__c p = [SELECT Id, Address__StateCode__s, Address__PostalCode__s
        FROM Property__c WHERE Id = :out.propertyId];
        System.assertEquals('NE', String.valueOf(p.Address__StateCode__s),
                'ZIP-derived state should override mismatched provided name');

        // Confirm we logged the mismatch message
        Boolean sawMismatch = false;
        for (PropertyWorkOrderApi.ErrorInfo e : out.errors) {
            if (e.step == 'address.state.resolve' && e.reason == 'Mismatch') {
                sawMismatch = true; break;
            }
        }
        System.assertEquals(true, sawMismatch,
                'Expected a mismatch warning when provided state conflicts with ZIP');
    }

    @IsTest
    static void test_stateResolution_uses_provided_code_when_no_zip() {
        PropertyWorkOrderApi.REQUIRE_SHARED_SECRET = false;

        Account a = [SELECT Id FROM Account LIMIT 1];
        Opportunity o = [SELECT Id FROM Opportunity LIMIT 1];

        // No postalCode -> should fall back to provided 2-letter state code "MN"
        String payload = JSON.serialize(new Map<String, Object>{
                'accountId' => a.Id,
                'opportunityId' => o.Id,
                'address' => new Map<String, Object>{
                        'street' => '1000 Fallback Ave',
                        'city' => 'St Paul',
                        'stateCode' => 'MN',          // already a 2-letter code
                        // 'postalCode' omitted intentionally
                        'countryCode' => 'US'
                }
        });

        RestContext.request  = makeReq(payload, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        PropertyWorkOrderApi.ResponseDTO out = PropertyWorkOrderApi.createAll();
        Test.stopTest();

        System.assertNotEquals(null, out.propertyId, 'Property should have been created');

        Property__c p = [SELECT Id, Address__StateCode__s
        FROM Property__c WHERE Id = :out.propertyId];
        System.assertEquals('MN', String.valueOf(p.Address__StateCode__s),
                'When ZIP is absent, we should use the provided 2-letter state code');
    }


}