/**
 * Created by Devin on 3/6/2025.
 */
@IsTest
public with sharing class ServiceAppointmentCouplerTest {

    @isTest
    static void testGetNearbyAppointments() {
        // Create a test WorkOrder record with minimal required fields.
        WorkOrder wo = new WorkOrder(
                Subject = 'Test Work Order',
                Status = 'New'
        );
        insert wo;

        // Create a test ServiceAppointment record.
        ServiceAppointment sa = new ServiceAppointment();
        // Set the parent relationship. Depending on your org, use WorkOrderId or ParentRecordId as needed.
        sa.ParentRecordId = wo.Id;
        // Set SchedStartTime to tomorrow.
        sa.SchedStartTime = System.now().addDays(3);
        // Set SchedEndTime to one hour after SchedStartTime.
        sa.SchedEndTime = sa.SchedStartTime.addHours(2);
        sa.Latitude = 40.0;
        sa.Longitude = -75.0;
        sa.Street = '123 Test St';
        sa.City = 'Test City';
        sa.State = 'TS';
        sa.Appointment_Result_1__c = 'Pending';

        insert sa;

        // Set up the callout mock for the Google Maps API.
        Test.setMock(HttpCalloutMock.class, new MockDistanceMatrixResponse());

        Test.startTest();
        // Call the method under test with a center point close to our test appointment.
        Map<String, List<ServiceAppointmentCoupler.ServiceAppointmentWrapper>> results =
                ServiceAppointmentCoupler.getNearbyAppointments(40.0, -75.0);
        Test.stopTest();

        System.debug('Grouped Results: ' + results);
        // Assert that at least one group exists.
        System.assertNotEquals(0, results.size(), 'There should be at least one group of appointments');

        // Verify that our test appointment is included in one of the groups.
        Boolean found = false;
        for (List<ServiceAppointmentCoupler.ServiceAppointmentWrapper> group1 : results.values()) {
            for (ServiceAppointmentCoupler.ServiceAppointmentWrapper wrapper : group1) {
                if(wrapper.appointment.Id == sa.Id) {
                    found = true;
                    break;
                }
            }
        }
        System.assert(found, 'The test appointment should be included in the grouped results');
    }

    // HttpCalloutMock implementation to simulate a Google Maps Distance Matrix API response.
    private class MockDistanceMatrixResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            // Simulate one result for the single appointment with a duration of 3600 seconds (i.e., 60 minutes).
            List<Object> responseList = new List<Object>();
            Map<String, Object> result = new Map<String, Object>{
                    'destinationIndex' => '0',
                    'duration' => '3600s'
            };
            responseList.add(result);

            res.setBody(JSON.serialize(responseList));
            return res;
        }
    }
}