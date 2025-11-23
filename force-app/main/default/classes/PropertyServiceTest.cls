/**
 * Created by Devin on 3/4/2025.
 */

@isTest(SeeAllData=true)
public class PropertyServiceTest {

    // Test for Account context when property has null lat/lon so geocoding is triggered,
    // and then appointments are returned.
    @isTest
    static void testGetNearbyAppointmentsWithGeocoding_Account() {
        // Create a test Property__c with a valid address but with null lat/lon
        Property__c prop = new Property__c(
                Address__Street__s = '123 Test Property',
                Address__City__s = 'Lincoln',
                Address__StateCode__s = 'NE'
        );
        insert prop;

        // Create a test WorkOrder record (required by ServiceAppointment)
        WorkOrder wo = new WorkOrder(
                Subject = 'Test Work Order',
                Status = 'New'
        );
        insert wo;

        // Create a test ServiceAppointment record positioned at the expected geocoded location.
        ServiceAppointment sa = new ServiceAppointment();
        sa.ParentRecordId = wo.Id;
        sa.SchedStartTime = System.now().addDays(3);
        sa.SchedEndTime = sa.SchedStartTime.addHours(2);
        sa.Latitude = 40.1;
        sa.Longitude = -75.1;
        sa.Street = '123 Test St';
        sa.City = 'Lincoln';
        sa.State = 'NE';
        sa.Appointment_Result_1__c = 'Pending';

        insert sa;

        // Set up a callout mock that returns a successful geocode response and a distance matrix response.
        Test.setMock(HttpCalloutMock.class, new TestMockResponse());

        Test.startTest();
        Map<String, List<ServiceAppointmentCoupler.ServiceAppointmentWrapper>> results =
                PropertyService.getNearbyAppointments(null, prop.Id, 'Account');
        Test.stopTest();

        System.debug('Grouped Results: ' + results);
        System.assertNotEquals(0, results.size(), 'Expected at least one group of appointments.');

        Boolean found = false;
        for (List<ServiceAppointmentCoupler.ServiceAppointmentWrapper> grouping : results.values()) {
            for (ServiceAppointmentCoupler.ServiceAppointmentWrapper wrapper : grouping) {
                if(wrapper.appointment.Id == sa.Id) {
                    found = true;
                    break;
                }
            }
        }
        System.assert(found, 'The test appointment should be included in the grouped results.');
    }

    // Test for Lead context: auto-assign property when propertyId is empty.
    @isTest
    static void testGetNearbyAppointmentsForLeadAutoAssign() {
        // Create a test Property__c
        Property__c prop = new Property__c(
                Address__Street__s = '123 Test Property',
                Address__City__s = 'Lincoln',
                Address__StateCode__s = 'NE'
        );
        insert prop;

        // Create a Lead with the Property__c populated.
        Lead testLead = new Lead(
                LastName = 'Tester',
                Company = 'Test Co',
                Property__c = prop.Id
        );
        insert testLead;

        // Create a test WorkOrder record
        WorkOrder wo = new WorkOrder(
                Subject = 'Test Work Order',
                Status = 'New'
        );
        insert wo;

        // Create a test ServiceAppointment record
        ServiceAppointment sa = new ServiceAppointment();
        sa.ParentRecordId = wo.Id;
        sa.SchedStartTime = System.now().addDays(3);
        sa.SchedEndTime = sa.SchedStartTime.addHours(2);
        sa.Latitude = 40.1;
        sa.Longitude = -75.1;
        sa.Street = '123 Test St';
        sa.City = 'Lincoln';
        sa.State = 'NE';
        sa.Appointment_Result_1__c = 'Pending';
        insert sa;

        // Set up the callout mock for both geocoding and distance matrix.
        Test.setMock(HttpCalloutMock.class, new TestMockResponse());

        Test.startTest();
        Map<String, List<ServiceAppointmentCoupler.ServiceAppointmentWrapper>> results =
                PropertyService.getNearbyAppointments(testLead.Id, '', 'Lead');
        Test.stopTest();

        System.assertNotEquals(0, results.size(), 'Expected at least one group for Lead context.');
    }

    // Test for Account context when no propertyId is provided; should throw an exception.


    // Test when no Property__c record is found for the given propertyId.


    // Test getGeoLocationFromGoogle when the API returns a failure (simulate ZERO_RESULTS).
    @isTest
    static void testGetGeoLocationFromGoogleFailure() {
        Test.setMock(HttpCalloutMock.class, new TestMockGeocodeFailure());
        Map<String, Decimal> geoData = PropertyService.getGeoLocationFromGoogle('invalid address');
        System.assertEquals(null, geoData, 'Geo data should be null for a failed geocode response.');
    }

    // Test the updateProp method.

    // HttpCalloutMock implementation that handles both geocode and distanceMatrix responses.
    private class TestMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            String endpoint = req.getEndpoint();
            if(endpoint.contains('geocode')) {
                // Simulate a successful geocoding response.
                Map<String, Object> location = new Map<String, Object>{
                        'lat' => 40.1,
                        'lng' => -75.1
                };
                Map<String, Object> geometry = new Map<String, Object>{
                        'location' => location
                };
                Map<String, Object> result = new Map<String, Object>{
                        'geometry' => geometry
                };
                List<Object> resultsList = new List<Object>{ result };
                Map<String, Object> responseBody = new Map<String, Object>{
                        'status' => 'OK',
                        'results' => resultsList
                };
                res.setBody(JSON.serialize(responseBody));
            } else if(endpoint.contains('distanceMatrix')) {
                // Simulate a distance matrix response as a JSON array.
                List<Object> responseList = new List<Object>();
                Map<String, Object> dmResult = new Map<String, Object>{
                        'destinationIndex' => '0',
                        'duration' => '3600s'
                };
                responseList.add(dmResult);
                res.setBody(JSON.serialize(responseList));
            }
            return res;
        }
    }

    // HttpCalloutMock implementation for geocode failure.
    private class TestMockGeocodeFailure implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            Map<String, Object> responseBody = new Map<String, Object>{
                    'status' => 'ZERO_RESULTS',
                    'results' => new List<Object>()
            };
            res.setBody(JSON.serialize(responseBody));
            return res;
        }
    }
}