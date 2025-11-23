/**
 * Created by NoahR on 6/6/2025.
 */

public with sharing class GetNearbyAppointmentsFromAddress {

    @AuraEnabled
    public static Map<String, List<ServiceAppointmentCoupler.ServiceAppointmentWrapper>> getApps(String address){
        Map<String, Decimal> newGeoData = null;
        Property__c prop = new Property__c();

        newGeoData = PropertyService.getGeoLocationFromGoogle(address);
        if (newGeoData == null || !newGeoData.containsKey('latitude') || !newGeoData.containsKey('longitude')) {
            throw new AuraHandledException('Property location data is missing.');
        }
        prop.Address__Latitude__s = newGeoData.get('latitude');
        prop.Address__Longitude__s = newGeoData.get('longitude');

        Map<String, List<ServiceAppointmentCoupler.ServiceAppointmentWrapper>> appointments =
                ServiceAppointmentCoupler.getNearbyAppointments(prop.Address__Latitude__s, prop.Address__Longitude__s);
        System.debug(appointments);

        return appointments;
    }






}