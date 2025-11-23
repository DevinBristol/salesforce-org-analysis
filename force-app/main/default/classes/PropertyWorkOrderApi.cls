/**
 * Created by Devin on 10/30/2025.
 */
@RestResource(UrlMapping='/external/v1/BoomWorkOrder')
global without sharing class PropertyWorkOrderApi {

    // ============================
    // ====== DTOs (Data) =========
    // ============================
    global class AddressDTO { public String street; public String city; public String stateCode; public String postalCode; public String countryCode; }
    global class LineItemDTO { public String name; public Decimal quantity; }

    global class RequestDTO {
        public String accountId;
        public String opportunityId;
        public AddressDTO address;
        public Datetime appointmentTime;              // ISO 8601 recommended
        public List<LineItemDTO> lineItems;           // Optional
        public String workTypeNameLike;               // default: "Initial"
        public String serviceTerritoryNameLike;       // default: "Greater"
    }
    global class ErrorInfo {
        public String step; public String reason; public String detail;
        public ErrorInfo(String s, String r, String d) { step=s; reason=r; detail=d; }
    }
    global class ResponseDTO {
        public Boolean success;
        public Integer statusCode;
        public String message;

        public Id propertyId;
        public Id workOrderId;
        public Id serviceAppointmentId;

        public Id quoteId;
        public List<Id> quoteLineItemIds = new List<Id>();
        public Decimal opportunityAmount;

        public List<ErrorInfo> errors = new List<ErrorInfo>();
    }
    private class QuoteResult { Id quoteId; final List<Id> qliIds = new List<Id>(); Decimal total = 0; }

    // ============================
    // auth toggles (Testing only - Live data lives on Custom Metadata Type)
    // ============================
    @TestVisible private static Boolean REQUIRE_SHARED_SECRET = false;
    @TestVisible private static String  SHARED_SECRET         = null;

    // signature-based auth (HMAC of raw body)
    @TestVisible private static Boolean REQUIRE_SIGNATURE          = false;
    @TestVisible private static String  SIGNATURE_HEADER           = 'X-Signature';
    @TestVisible private static String  SIGNATURE_PREFIX           = 'sha256=';
    @TestVisible private static String  TIMESTAMP_HEADER           = 'X-Timestamp';
    @TestVisible private static Integer TIMESTAMP_TOLERANCE_SECONDS = 300; // 5 min

    // ============================
    // ======== Endpoint ==========
    // ============================
    @HttpPost
    global static ResponseDTO createAll() {
        RestResponse res = RestContext.response;
        if (res == null) { res = new RestResponse(); RestContext.response = res; }
        res.addHeader('Content-Type', 'application/json');

        ResponseDTO out = new ResponseDTO();
        out.success = false;

        // OAuth users pass automatically; Sites/guest can use X-API-Key
        if (!isAuthorized(RestContext.request)) {
            return fail(res, out, 401, 'Unauthorized', 'auth.check', 'Missing or invalid credentials.');
        }

        // Body guard
        if (RestContext.request == null || RestContext.request.requestBody == null
                || String.isBlank(RestContext.request.requestBody.toString())) {
            return fail(res, out, 400, 'Empty request', 'request.null', 'No payload received.');
        }

        RequestDTO input;

        try {
            input = (RequestDTO) JSON.deserialize(RestContext.request.requestBody.toString(), RequestDTO.class);
        } catch (Exception e) {
            return fail(res, out, 400, 'Invalid JSON', 'request.parse', e.getMessage());
        }
        if (input == null) {
            return fail(res, out, 400, 'Empty request', 'request.null', 'No payload received.');
        }

        System.debug('Print input ' + input);

        // Defaults for LIKE lookups
        String wtLike = String.isBlank(input.workTypeNameLike) ? 'Initial Sales Visit' : input.workTypeNameLike;
        String stLike = String.isBlank(input.serviceTerritoryNameLike) ? 'Greater Nebraska' : input.serviceTerritoryNameLike;

        // Validate Account & Opportunity
        System.debug('Print acct accountId IN ' + input.accountId);
        System.debug('Print opp oppId IN' + input.opportunityId);

        Account acct = fetchAccount(input.accountId, out);
        Opportunity opp = fetchOpportunity(input.opportunityId, out);

        System.debug('Print acct FOUND ' + acct);
        System.debug('Print opp FOUND ' + opp);

        // Property: find or create by address (currently scoped to Account. Gross)
        Id propId;
        if (acct != null && input.address != null) {
            Property__c prop = getOrCreateProperty(acct.Id, input.address, out);
            if (prop != null) {
                propId = prop.Id;
                out.propertyId = propId;
            }
        } else {
            out.errors.add(new ErrorInfo('property.validate', 'MissingField', 'AccountId or address missing. Skipping property step.'));
        }

        //  Attach Property to Opportunity
        if (opp != null && propId != null) {
            if (setOpportunityPropertyLookup(opp, propId, out)) {
                safeUpdate(opp, 'opportunity.setProperty', out);
            }
        }
        System.debug('Print wtLike ' + wtLike);
        System.debug('Print stLike ' + stLike);
        // Look up WorkType & ServiceTerritory
        Id workTypeId = findWorkTypeIdByNameLike(wtLike);
        if (workTypeId == null) out.errors.add(new ErrorInfo('worktype.lookup', 'NotFound', 'No WorkType with Name LIKE ' + wtLike));

        Id territoryId = findServiceTerritoryIdByNameLike(stLike);
        if (territoryId == null) out.errors.add(new ErrorInfo('territory.lookup', 'NotFound', 'No ServiceTerritory with Name LIKE ' + stLike));

        // 5) Work Order
        Datetime apptStart = input.appointmentTime; // if null, WO.StartDate will be null
        System.debug('Print Acct ' + acct);
        System.debug('Print workTypeId ' + workTypeId);
        System.debug('Print territoryId ' + territoryId);
        System.debug('Print input address ' + input.address);
        System.debug('Print apptStart ' + apptStart);

        if (acct != null && workTypeId != null && territoryId != null) {

            WorkOrder wo = createWorkOrder(acct.Id, workTypeId, territoryId, apptStart, opp, input.address);
            System.debug('Print wo ' + wo);

            Database.SaveResult srWO = Database.insert(wo, false);
            if (srWO.isSuccess()) {
                out.workOrderId = srWO.getId();
            } else {
                out.errors.add(new ErrorInfo('workorder.insert', 'Dml', joinErrors(srWO)));
            }
        }

        // Service Appointment - Service Appointment is created on insert of Work Order - Update that one - Why must Salesforce abuse us?
        if (out.workOrderId != null && apptStart != null) {
            ServiceAppointment saFound = selectServiceAppointmentForWorkOrder(out.workOrderId, out);
            if (saFound != null) {
                ServiceAppointment saToUpdate = updateServiceAppointment(out.workOrderId, apptStart, opp, input.address, saFound);
                try {
                    update saToUpdate;
                    out.serviceAppointmentId = saToUpdate.Id;
                } catch (Exception e) {
                    out.errors.add(new ErrorInfo('serviceappointment.update', 'DmlException',
                            e.getMessage() + ' (ServiceAppointment update is optional; WorkOrder remains.)'));
                }
            }
        }

        // Quote + Quote Line Items + Update Opportunity Amount (optional if we received line items)
        if (opp != null && input.lineItems != null && !input.lineItems.isEmpty()) {
            QuoteResult qr = processQuoteAndLines(opp, input.lineItems, out);
            if (qr != null) {
                out.quoteId = qr.quoteId;
                out.quoteLineItemIds.addAll(qr.qliIds);
                if (qr.total != null) {
                    opp.SyncedQuoteId = qr.quoteId;
                    opp.Amount = qr.total;
                    safeUpdate(opp, 'opportunity.amount.update', out);
                    out.opportunityAmount = opp.Amount;
                }
            }
        }

        // Finalize HTTP code + message
        Boolean createdSomething = (out.propertyId != null) || (out.workOrderId != null) || (out.quoteId != null);
        out.success = createdSomething && out.errors.isEmpty();
        if (out.success) {
            res.statusCode = 201; out.statusCode = 201; out.message = 'Created.';
        } else if (createdSomething && !out.errors.isEmpty()) {
            res.statusCode = 207; out.statusCode = 207; out.message = 'Completed with partial errors.';
        } else {
            res.statusCode = 400; out.statusCode = 400; out.message = 'Request failed. See errors for details.';
        }
        return out;
    }

    // ============================
    // ===== Helper Methods =======
    // ============================

    // -- Accounts & Opportunities
    private static Account fetchAccount(String accountId, ResponseDTO out) {
        if (String.isBlank(accountId)) {
            out.errors.add(new ErrorInfo('account.validate', 'MissingField', 'accountId is required.'));
            return null;
        }
        try {
            List<Account> accs = [SELECT Id FROM Account WHERE Id = :accountId LIMIT 1];
            if (accs.isEmpty()) {
                out.errors.add(new ErrorInfo('account.lookup', 'NotFound', 'No Account found for Id ' + accountId));
                return null;
            }
            return accs[0];
        } catch (Exception e) {
            out.errors.add(new ErrorInfo('account.lookup', 'QueryException', e.getMessage()));
            return null;
        }
    }
    private static Opportunity fetchOpportunity(String opportunityId, ResponseDTO out) {
        if (String.isBlank(opportunityId)) {
            out.errors.add(new ErrorInfo('opportunity.validate', 'MissingField', 'opportunityId is required.'));
            return null;
        }
        try {
            List<Opportunity> opps = [SELECT Id, Amount FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
            if (opps.isEmpty()) {
                out.errors.add(new ErrorInfo('opportunity.lookup', 'NotFound', 'No Opportunity found for Id ' + opportunityId));
                return null;
            }
            return opps[0];
        } catch (Exception e) {
            out.errors.add(new ErrorInfo('opportunity.lookup', 'QueryException', e.getMessage()));
            return null;
        }
    }

// -- Property: find or create by address scoped to account
    private static Property__c getOrCreateProperty(Id accountId, AddressDTO a, ResponseDTO out) {
        //TODO Add logic to find existing properties outside of account. See PropertyRelationHandler.getProperties
        //Notes : AccountId is not the primary relationship driver. It is the Account_Property_Relationship__c Object
        //Notes : PropertyRelationHandler will trigger to handle dupe matching and merging outside of current Account for now
        Property__c existing = findPropertyByAddress(accountId, a, out);
        if (existing != null) return existing;

        try {
            Property__c p = new Property__c();
            p.AccountId__c = accountId;
            if (a != null) {
                if (!String.isBlank(a.street))      p.Address__Street__s      = a.street;
                if (!String.isBlank(a.city))        p.Address__City__s        = a.city;
                if (!String.isBlank(a.stateCode))   p.Address__StateCode__s   = a.stateCode;
                if (!String.isBlank(a.postalCode))  p.Address__PostalCode__s  = a.postalCode;
                if (!String.isBlank(a.countryCode)) p.Address__CountryCode__s = a.countryCode;

                // [NEW] Normalize/derive 2-letter state code using ZIP (primary) or full name (fallback)
                String resolved = resolveStateCode(p.Address__StateCode__s, p.Address__PostalCode__s, out);
                if (!String.isBlank(resolved)) {
                    p.Address__StateCode__s = resolved;
                }
            }
            insert p;
            return p;
        } catch (Exception e) {
            out.errors.add(new ErrorInfo('property.insert', 'DmlException', e.getMessage()));
            return null;
        }
    }
    // [NEW] Resolve a 2-letter state code from postal code and/or provided value.
// Priority: ZIP range -> 2-letter provided -> full-name provided
    private static String resolveStateCode(String providedState, String postalCode, ResponseDTO out) {
        String zipCode = extractZip5(postalCode);                 // "68001" from "68001-1234"
        String fromZip = deriveStateFromZip(zipCode);             // NE/IA/SD/KS/MO/CO/WY/MN or null

        String provided = String.isBlank(providedState) ? null : providedState.trim();
        String providedAsCode = null;

        if (provided != null) {
            if (provided.length() == 2) {
                providedAsCode = provided.toUpperCase();
            } else {
                // full name -> code (only for states you care about)
                Map<String,String> names = new Map<String,String>{
                        'NEBRASKA'      => 'NE',
                        'IOWA'          => 'IA',
                        'SOUTH DAKOTA'  => 'SD',
                        'KANSAS'        => 'KS',
                        'MISSOURI'      => 'MO',
                        'COLORADO'      => 'CO',
                        'WYOMING'       => 'WY',
                        'MINNESOTA'     => 'MN'
                };
                String key = provided.toUpperCase();
                if (names.containsKey(key)) {
                    providedAsCode = names.get(key);
                } else {
                    // Unrecognized full name: we don't fail the request; we just log it
                    out.errors.add(new ErrorInfo('address.state.resolve', 'UnknownStateName',
                            'Unrecognized state "' + provided + '". Attempting resolution from ZIP.'));
                }
            }
        }

        // If ZIP gave us a code, prefer it. If it conflicts with a provided code, log it and use ZIP.
        if (!String.isBlank(fromZip)) {
            if (!String.isBlank(providedAsCode) && fromZip != providedAsCode) {
                out.errors.add(new ErrorInfo('address.state.resolve', 'Mismatch',
                        'Provided state "' + provided + '" conflicts with ZIP ' + safePostal(zipCode) +
                        ' (derived ' + fromZip + '). Using ' + fromZip + '.'));
            }
            return fromZip;
        }

        // No ZIP match; fall back to provided value (already normalized if possible)
        if (!String.isBlank(providedAsCode)) return providedAsCode;

        // Nothing we can do
        return null;
    }

// [NEW] Extract first 5 digits from a postal string (supports ZIP+4 and noisy input)
    private static String extractZip5(String postal) {
        if (String.isBlank(postal)) return null;
        // keep digits only
        String digits = postal.replaceAll('\\D', '');
        if (String.isBlank(digits) || digits.length() < 5) return null;
        return digits.substring(0, 5);
    }

// [NEW] Map ZIP5 to a state code for your supported states
    private static String deriveStateFromZip(String zip5) {
        if (String.isBlank(zip5)) return null;
        Integer z;
        try { z = Integer.valueOf(zip5); } catch (Exception e) { return null; }

        // NE: 68001–69367
        if (z >= 68001 && z <= 69367) return 'NE';
        // IA: 50001–52809
        if (z >= 50001 && z <= 52809) return 'IA';
        // SD: 57001–57799
        if (z >= 57001 && z <= 57799) return 'SD';
        // KS: 66001–67954
        if (z >= 66001 && z <= 67954) return 'KS';
        // MO: 63001–65899
        if (z >= 63001 && z <= 65899) return 'MO';
        // CO: 80001–81658
        if (z >= 80001 && z <= 81658) return 'CO';
        // WY: 82001–83414
        if (z >= 82001 && z <= 83414) return 'WY';
        // MN: 55001–56763
        if (z >= 55001 && z <= 56763) return 'MN';

        return null;
    }

// [NEW] Format a ZIP for messages
    private static String safePostal(String zip5) {
        return String.isBlank(zip5) ? 'n/a' : zip5;
    }

    private static Property__c findPropertyByAddress(Id accountId, AddressDTO a, ResponseDTO out) {
        if (a == null || String.isBlank(a.street)) return null;
        try {
            String streetNum = a.street != null ? a.street.trim().substringBefore(' ') : null;
            if (String.isBlank(streetNum)) return null;
            List<Property__c> props = [
                    SELECT Id
                    FROM Property__c
                    WHERE AccountId__c = :accountId
                    AND Address__Street__s LIKE : (streetNum + '%')
                    ORDER BY CreatedDate ASC
                    LIMIT 1
            ];
            return props.isEmpty() ? null : props[0];
        } catch (Exception e) {
            out.errors.add(new ErrorInfo('property.lookup', 'QueryException', e.getMessage()));
            return null;
        }
    }

    // -- Attach Property to Opportunity
    private static Boolean setOpportunityPropertyLookup(Opportunity opp, Id propertyId, ResponseDTO out) {
        try {
            Schema.DescribeSObjectResult d = Opportunity.SObjectType.getDescribe();
            Map<String, Schema.SObjectField> fields = d.fields.getMap();
            if (fields.containsKey('Opportunity_Property__c')) {
                opp.put('Opportunity_Property__c', propertyId);
            } else {
                out.errors.add(new ErrorInfo('opportunity.setProperty', 'FieldMissing','Opportunity.Opportunity_Property__c doesnt exist.'));
                return false;
            }
            return true;
        } catch (Exception e) {
            out.errors.add(new ErrorInfo('opportunity.setProperty', 'Exception', e.getMessage()));
            return false;
        }
    }

    // -- Work Type & Territory
    private static Id findWorkTypeIdByNameLike(String nameLike) {
        try {
            List<WorkType> recs = [
                    SELECT Id FROM WorkType
                    WHERE Name LIKE :('%' + nameLike + '%')
                    LIMIT 1
            ];
            return recs.isEmpty() ? null : recs[0].Id;
        } catch (Exception e) {
            return null;
        }
    }
    private static Id findServiceTerritoryIdByNameLike(String nameLike) {
        try {
            List<ServiceTerritory> recs = [
                    SELECT Id FROM ServiceTerritory
                    WHERE Name LIKE :('%' + nameLike + '%')
                    ORDER BY Name
                    LIMIT 1
            ];
            return recs.isEmpty() ? null : recs[0].Id;
        } catch (Exception e) {
            return null;
        }
    }

    // -- Work Order & Service Appointment
    private static WorkOrder createWorkOrder(
            Id accountId, Id workTypeId, Id territoryId, Datetime start,
            Opportunity opp, AddressDTO addr
    ){

        WorkOrder wo = new WorkOrder(
                Subject = buildSubject('Work Order', opp, addr),
                AccountId = accountId,
                WorkTypeId = workTypeId,
                ServiceTerritoryId = territoryId,
                StartDate = start
        );

        // Please stop freaking out in my Sandbox
        if (opp != null)                    safePut(wo, 'Opportunity__c', opp.Id);
        if (addr != null) {
            if (!String.isBlank(addr.street))      safePut(wo, 'Street', addr.street);
            if (!String.isBlank(addr.city))        safePut(wo, 'City', addr.city);
            if (!String.isBlank(addr.stateCode))   safePut(wo, 'State', addr.stateCode);
            if (!String.isBlank(addr.postalCode))  safePut(wo, 'PostalCode', addr.postalCode);
            if (!String.isBlank(addr.countryCode)) safePut(wo, 'Country', addr.countryCode);
        }

        // I guess.. Make inserts robust when using apex to insert WorkOrders
        applyWOFieldDefaults(wo);

        return wo;
    }


    // choose a SA to update ... this is in case of duplicate ServiceAppointment Creation on retry... somehow
    private static ServiceAppointment selectServiceAppointmentForWorkOrder(Id workOrderId, ResponseDTO out) {
        try {
            List<ServiceAppointment> listSa = [
                    SELECT Id, Subject, CreatedDate
                    FROM ServiceAppointment
                    WHERE ParentRecordId = :workOrderId
                    ORDER BY CreatedDate ASC
                    LIMIT 1
            ];
            if (listSa.isEmpty()) {
                out.errors.add(new ErrorInfo('serviceappointment.lookup', 'NotFound', 'No ServiceAppointment found for WorkOrder ' + workOrderId));
                return null;
            }
            return listSa[0];
        } catch (Exception e) {
            out.errors.add(new ErrorInfo('serviceappointment.lookup', 'QueryException', e.getMessage()));
            return null;
        }
    }

    private static ServiceAppointment updateServiceAppointment(Id workOrderId, Datetime start, Opportunity opp, AddressDTO addr, ServiceAppointment sa) {
        sa.Subject = buildSubject('Service Appointment', opp, addr);
        sa.Appointment_Result_1__c = 'Pending';
        sa.SchedStartTime = start;
        sa.SchedEndTime = start == null ? null : start.addHours(2);
        sa.ArrivalWindowStartTime = start;
        sa.ArrivalWindowEndTime = start;
        return sa;
    }

    private static String buildSubject(String prefix, Opportunity opp, AddressDTO addr) {
        String at = (opp != null ? 'Opp ' + opp.Id + ' ' : '');
        String place = (addr != null && !String.isBlank(addr.city)) ? (' - ' + addr.city) : '';
        return prefix + ' ' + at + Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + place;
    }

    // -- Quote + Lines + Opportunity Amount
    private static QuoteResult processQuoteAndLines(Opportunity opp, List<LineItemDTO> items, ResponseDTO out) {
        QuoteResult qr = new QuoteResult();
        Pricebook2 stdPb = getStandardPricebook();
        if (stdPb == null) {
            out.errors.add(new ErrorInfo('pricebook.lookup', 'NotFound', 'Standard Price Book not found or inactive.'));
            return qr;
        }

        Quote q = new Quote(
                Name = 'Auto Quote for ' + opp.Id + ' @ ' + Date.today().format(),
                OpportunityId = opp.Id,
                Pricebook2Id = stdPb.Id
        );
        try {
            insert q;
            qr.quoteId = q.Id;
        } catch (Exception e) {
            out.errors.add(new ErrorInfo('quote.insert', 'DmlException', e.getMessage()));
            return qr;
        }

        // Normalize requested names
        Set<String> requestedNames = new Set<String>();
        for (LineItemDTO li : items) {
            if (li != null && !String.isBlank(li.name) && li.quantity != null && li.quantity > 0) {
                requestedNames.add(li.name.trim());
            } else {
                out.errors.add(new ErrorInfo('lineitem.validate', 'InvalidRow', 'Name and positive Quantity required. Row skipped.'));
            }
        }
        if (requestedNames.isEmpty()) return qr;

        Map<String, Product2> productsByName = findProductsByName(requestedNames);
        Set<Id> productIds = new Set<Id>();
        for (String n : requestedNames) {
            Product2 p = productsByName.get(n);
            if (p == null) {
                out.errors.add(new ErrorInfo('product.lookup', 'NotFound', 'No Product2 found for Name "' + n + '"'));
            } else {
                productIds.add(p.Id);
            }
        }
        if (productIds.isEmpty()) return qr;

        Map<Id, PricebookEntry> pbeByProduct = findActivePBEs(stdPb.Id, productIds);
        List<QuoteLineItem> qlis = new List<QuoteLineItem>();

        for (LineItemDTO li : items) {
            if (li == null || String.isBlank(li.name) || li.quantity == null || li.quantity <= 0) continue;

            Product2 prod = productsByName.get(li.name.trim());
            if (prod == null) continue;

            PricebookEntry pbe = pbeByProduct.get(prod.Id);
            if (pbe == null) {
                out.errors.add(new ErrorInfo('pbe.lookup', 'NotFound', 'No active PricebookEntry in Standard Price Book for Product "' + li.name + '"'));
                continue;
            }
            QuoteLineItem qli = new QuoteLineItem(
                    QuoteId = q.Id,
                    PricebookEntryId = pbe.Id,
                    Quantity = li.quantity,
                    UnitPrice = pbe.UnitPrice
            );
            qlis.add(qli);
        }

        if (qlis.isEmpty()) return qr;

        Database.SaveResult[] results = Database.insert(qlis, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                qr.qliIds.add(results[i].getId());
                QuoteLineItem qli = qlis[i];
                Decimal lineTotal = (qli.UnitPrice == null ? 0 : qli.UnitPrice) * (qli.Quantity == null ? 0 : qli.Quantity);
                qr.total += lineTotal;
            } else {
                out.errors.add(new ErrorInfo('quotelineitem.insert', 'Dml', joinErrors(results[i])));
            }
        }
        return qr;
    }
    private static Pricebook2 getStandardPricebook() {
        List<Pricebook2> pbs = [SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1];
        if (pbs.isEmpty()) return null;
        Pricebook2 pb = pbs[0];
        return pb.IsActive ? pb : null;
    }
    private static Map<String, Product2> findProductsByName(Set<String> names) {
        Map<String, Product2> out = new Map<String, Product2>();
        if (names.isEmpty()) return out;
        for (Product2 p : [SELECT Id, Name FROM Product2 WHERE Name IN :names AND IsActive = TRUE]) out.put(p.Name, p);
        return out;
    }
    private static Map<Id, PricebookEntry> findActivePBEs(Id pricebookId, Set<Id> productIds) {
        Map<Id, PricebookEntry> out = new Map<Id, PricebookEntry>();
        if (pricebookId == null || productIds.isEmpty()) return out;
        for (PricebookEntry pbe : [
                SELECT Id, Product2Id, UnitPrice, IsActive
                FROM PricebookEntry
                WHERE Pricebook2Id = :pricebookId
                AND Product2Id IN :productIds
                AND IsActive = TRUE
        ]) out.put(pbe.Product2Id, pbe);
        return out;
    }

    // -- DML wrappers
    private static void safeUpdate(SObject s, String step, ResponseDTO out) {
        try { update s; }
        catch (Exception e) { out.errors.add(new ErrorInfo(step, 'DmlException', e.getMessage())); }
    }

    // -- Utilities
    private static ResponseDTO fail(RestResponse res, ResponseDTO out, Integer code, String msg, String step, String detail) {
        res.statusCode = code;
        out.statusCode = code;
        out.message = msg;
        out.success = false;
        out.errors.add(new ErrorInfo(step, 'BadRequest', detail));
        return out;
    }
    private static String joinErrors(Database.SaveResult sr) {
        List<String> msgs = new List<String>();
        if (sr != null) for (Database.Error e : sr.getErrors()) msgs.add(e.getStatusCode() + ': ' + e.getMessage());
        return String.join(msgs, '; ');
    }

// ============================
// Auth helpers
// ============================
    private static Boolean isAuthorized(RestRequest req){
        // Test-mode shim to keep unit tests deterministic
        if (Test.isRunningTest()) {
            // If tests say no secret required, allow
            if (!REQUIRE_SHARED_SECRET) return true;

            // If tests require a shared secret, only allow when the expected header matches
            String provided = (req == null || req.headers == null) ? null : req.headers.get('X-API-Key');
            if (!String.isBlank(SHARED_SECRET) && !String.isBlank(provided)) {
                return WebhookAuthUtil.constTimeEquals(SHARED_SECRET, provided);
            }
            // Missing/invalid in tests -> unauthorized
            return false;
        }

        // Non-guest users (OAuth/session) pass in real runtime
        if (UserInfo.getUserType() != 'Guest') return true;

        // Sites/guest traffic goes through partner-driven auth
        WebhookAuthUtil.Result r = WebhookAuthUtil.authorize(req);
        return r.ok;
    }

    // Safe put
    private static void safePut(SObject s, String fieldApi, Object value) {
        try { s.put(fieldApi, value); } catch (Exception e) { /* no-op */ }
    }

// Apply default required picklists to Work Order - Why is this only an issue in apex?
    private static void applyWOFieldDefaults(WorkOrder wo) {
        Schema.DescribeSObjectResult d = WorkOrder.SObjectType.getDescribe();
        Map<String, Schema.SObjectField> f = d.fields.getMap();

        setPicklistIfRequired(wo, f, 'Status', null);
        setPicklistIfRequired(wo, f, 'Priority', null);
    }

// If a picklist field is required and empty, set the first option (or a fallback)
    private static void setPicklistIfRequired(
            SObject s, Map<String, Schema.SObjectField> fmap, String api, String fallback
    ){
        if (!fmap.containsKey(api)) return;
        Schema.DescribeFieldResult df = fmap.get(api).getDescribe();
        if (s.get(api) == null && !df.isNillable()) {
            String val = fallback;
            List<Schema.PicklistEntry> opts = df.getPicklistValues();
            if (opts != null && !opts.isEmpty()) val = opts[0].getValue();
            if (val != null) s.put(api, val);
        }
    }

}