/**
 * Created by Devin on 2/27/2025.
 */

public with sharing class ServiceAppointmentCoupler {
    private static final String GOOGLE_MAPS_API_KEY = 'AIzaSyB2IDFPiCOni-FlPrNDyX_iltzxttRk0OM';
    private static final String GOOGLE_MAPS_API_URL = 'https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix';

    /**
     * Retrieves nearby service appointments, groups them by header ("DayName MM-dd-yyyy"),
     * and adjusts times based on drive time.
     */
    public static Map<String, List<ServiceAppointmentWrapper>> getNearbyAppointments(Decimal startLat, Decimal startLon) {

        Decimal maxDriveTime = Service_Appointment_Config__mdt.getInstance('Default').MaxDriveTime__c;
        Decimal maxWeeksAhead = Service_Appointment_Config__mdt.getInstance('Default').MaxWeeksAhead__c;
        Decimal maxDistance = Service_Appointment_Config__mdt.getInstance('Default').maxDistance__c;
        Decimal maxSlots = Service_Appointment_Config__mdt.getInstance('Default').maxSlotsPerDay__c;

        Datetime now = System.now();
        Datetime futureLimit = now.addDays(Integer.valueOf(maxWeeksAhead * 7));

        List<ServiceAppointment> appointments = [
                SELECT Id, AppointmentNumber, SchedStartTime, Latitude, Longitude,
                        Street, City, State, Appointment_Result_1__c
                FROM ServiceAppointment
                WHERE Appointment_Result_1__c != 'Cancelled'
                AND SchedStartTime >= :now
                AND SchedStartTime <= :futureLimit
                AND Latitude != NULL
                AND Longitude != NULL
                AND DISTANCE(Address, GEOLOCATION(:startLat, :startLon), 'mi') < :maxDistance
                ORDER BY SchedStartTime
        ];
        Map<String, List<ServiceAppointmentWrapper>> groupedResults = new Map<String, List<ServiceAppointmentWrapper>>();
        if (appointments.isEmpty()) {
            return groupedResults;
        }

        // Build destination list and index mapping
        List<Map<String, Decimal>> destinations = new List<Map<String, Decimal>>();
        Map<Integer, ServiceAppointment> appointmentIndexMap = new Map<Integer, ServiceAppointment>();
        Integer index = 0;
        for (ServiceAppointment sa : appointments) {
            destinations.add(new Map<String, Decimal>{ 'latitude' => sa.Latitude, 'longitude' => sa.Longitude });
            appointmentIndexMap.put(index, sa);
            index++;
        }

        // Get drive times from Google API in batch
        List<Map<String, Object>> driveTimeResults = getDistanceAndDurationToMultipleLocations(startLat, startLon, destinations);

        Integer previousDaySelection = Datetime.now().day();
        Integer sameDayTracker = 0;
        // Process results and group by header (e.g. "Thursday 03-06-2025")
        System.debug(driveTimeResults);
        for (Map<String, Object> result : driveTimeResults) {

            Integer destinationIndexForCancel = Integer.valueOf(result.get('destinationIndex').toString());
            //TODO Make this a metadata query Boolean for Next Days Y/N?
//            try{ // Call some stuff early to check if its the same day or next day
//                ServiceAppointment sas = appointmentIndexMap.get(destinationIndexForCancel);
//
//                if(Datetime.now().addDays(1).day() == sas.SchedStartTime.day() || Datetime.now().day() == sas.SchedStartTime.day()){
//                    continue;
//                }
//            } catch(Exception e) {
//
//            }

            System.debug('Results: ' + result);
            Integer destinationIndex = Integer.valueOf(result.get('destinationIndex').toString());
            Integer driveTime = result.containsKey('duration')
                    ? Integer.valueOf(Decimal.valueOf(result.get('duration').toString().substringBefore('s')) / 60)
                    : -1;
            Integer isDriveShort; // 0 = false
            if(driveTime <= 30){
                isDriveShort = 1;
            } else {
                isDriveShort = 0;
            }

            if (appointmentIndexMap.containsKey(destinationIndex)) {
                ServiceAppointment sa = appointmentIndexMap.get(destinationIndex);
                if (driveTime >= 0 && driveTime <= maxDriveTime) {
                    Datetime adjustedTimeBefore = sa.SchedStartTime.addMinutes(-180 - driveTime);
                    Datetime adjustedTimeAfter  = sa.SchedStartTime.addMinutes(180 + driveTime);
                    // Create header as "DayName MM-dd-yyyy"
                    String header = sa.SchedStartTime.format('EEEE MM-dd-yyyy');

                    if (!groupedResults.containsKey(header)) {
                        groupedResults.put(header, new List<ServiceAppointmentWrapper>());
                    }
                    groupedResults.get(header).add(
                            new ServiceAppointmentWrapper(sa, driveTime, adjustedTimeBefore, adjustedTimeAfter, header, sa.Street, sa.City, sa.State,isDriveShort)
                    );
                }
            }
        }

        // Sort each group of appointments by SchedStartTime (ascending)
        for (String header : groupedResults.keySet()) {
            groupedResults.get(header).sort();
        }

        //Trim the headers if over the size
        for (String header : groupedResults.keySet()) {
            List<ServiceAppointmentWrapper> oneDayHeader = groupedResults.get(header);

            // If the size exceeds the metadata, trim it down
            if (oneDayHeader.size() > maxSlots) {
                List<ServiceAppointmentWrapper> trimmedAppointments = new List<ServiceAppointmentWrapper>();

                for (Integer i = 0; i < maxSlots; i++) {
                    trimmedAppointments.add(oneDayHeader[i]);
                }

                groupedResults.put(header, trimmedAppointments); // Update the map with the smaller list
            }
        }

        return groupedResults;
    }

    public static List<Map<String, Object>> getDistanceAndDurationToMultipleLocations(Decimal originLat, Decimal originLng, List<Map<String, Decimal>> destinations) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        try {
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(GOOGLE_MAPS_API_URL);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('X-Goog-Api-Key', GOOGLE_MAPS_API_KEY);
            request.setHeader('X-Goog-FieldMask', 'originIndex,destinationIndex,status,distanceMeters,duration');

            // Construct the request body
            Map<String, Object> requestBody = new Map<String, Object>{
                    'origins' => new List<Object>{
                            new Map<String, Object>{
                                    'waypoint' => new Map<String, Object>{
                                            'location' => new Map<String, Object>{
                                                    'latLng' => new Map<String, Object>{
                                                            'latitude' => originLat,
                                                            'longitude' => originLng
                                                    }
                                            }
                                    }
                            }
                    },
                    'destinations' => new List<Object>()
            };
            List<Object> destinationList = (List<Object>) requestBody.get('destinations');
            for (Map<String, Decimal> dest : destinations) {
                destinationList.add(new Map<String, Object>{
                        'waypoint' => new Map<String, Object>{
                                'location' => new Map<String, Object>{
                                        'latLng' => new Map<String, Object>{
                                                'latitude' => dest.get('latitude'),
                                                'longitude' => dest.get('longitude')
                                        }
                                }
                        }
                });
            }
            requestBody.put('destinations', destinationList);
            request.setBody(JSON.serialize(requestBody));

            HttpResponse response = http.send(request);
            System.debug(response);
            if (response.getStatusCode() == 200) {
                List<Object> responseBody = (List<Object>) JSON.deserializeUntyped(response.getBody());
                for (Object obj : responseBody) {
                    results.add((Map<String, Object>) obj);
                }
            } else {
                results.add(new Map<String, Object>{ 'error' => 'Google API request failed' });
            }
        } catch (Exception e) {
            results.add(new Map<String, Object>{ 'error' => e.getMessage() });
        }
        return results;
    }

    // Updated Wrapper Class with formattedAddress and Comparable implementation.
    public class ServiceAppointmentWrapper implements Comparable {
        @AuraEnabled public ServiceAppointment appointment { get; set; }
        @AuraEnabled public Integer driveTimeMinutes { get; set; }
        @AuraEnabled public Datetime adjustedTimeBefore { get; set; }
        @AuraEnabled public Datetime adjustedTimeAfter { get; set; }
        @AuraEnabled public String scheduledStartTime { get; set; }
        @AuraEnabled public String header { get; set; }
        @AuraEnabled public String Street { get; set; }
        @AuraEnabled public String City { get; set; }
        @AuraEnabled public String State { get; set; }
        @AuraEnabled public String formattedAddress { get; set; }
        //CHANGED THIS
        @AuraEnabled public Integer isShortDrive {get; set;}

        public ServiceAppointmentWrapper(ServiceAppointment sa, Integer driveTime, Datetime beforeTime, Datetime afterTime, String header, String street, String city, String state, Integer shortDriveCheck) {
            this.appointment = sa;
            this.driveTimeMinutes = driveTime;
            this.adjustedTimeBefore = beforeTime;
            this.adjustedTimeAfter = afterTime;
            this.header = header;
            this.Street = street;
            this.City = city;
            this.State = state;
            this.isShortDrive = shortDriveCheck;

            // Format scheduledStartTime in valid ISO8601 format
            this.scheduledStartTime = (sa.SchedStartTime != null) ? sa.SchedStartTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') : 'N/A';
            // Concatenate the address parts
            this.formattedAddress = street + ', ' + city + ', ' + state;
        }

        // Implement Comparable so that the appointments can be sorted by SchedStartTime
        public Integer compareTo(Object other) {
            ServiceAppointmentWrapper o = (ServiceAppointmentWrapper) other;
            // If either is null, you might choose to treat them as equal
            if(this.appointment.SchedStartTime == o.appointment.SchedStartTime) {
                return 0;
            } else if(this.appointment.SchedStartTime > o.appointment.SchedStartTime) {
                return 1;
            } else {
                return -1;
            }
        }

    }
}