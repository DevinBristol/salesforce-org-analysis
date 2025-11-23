/**
 * Created by Devin on 2/27/2025.
 */

public with sharing class PropertyService {
    private static final String GOOGLE_MAPS_API_KEY = 'AIzaSyB2IDFPiCOni-FlPrNDyX_iltzxttRk0OM';
    private static final String GOOGLE_GEOCODE_URL = 'https://maps.googleapis.com/maps/api/geocode/json';

    /**
     * Retrieves nearby service appointments based on a property.
     * If called from a Lead, the property is auto-assigned from the Lead's Property__c field.
     * If called from an Account, a property must be selected.
     *
     * @param recordId The Id of the current record (Lead or Account).
     * @param propertyId The Id of the property to use (can be empty for Leads).
     * @param objectApiName The API name of the current object (e.g. 'Lead' or 'Account').
     * @return A map of appointment headers to lists of ServiceAppointmentWrapper.
     */
    @AuraEnabled
    public static Map<String, List<ServiceAppointmentCoupler.ServiceAppointmentWrapper>> getNearbyAppointments(
            String recordId,
            String propertyId,
            String objectApiName) {
        System.debug('Using propertyId from launcher: ' + propertyId);
        Boolean noPropFoundLead = false;
        Property__c tempProp = new Property__c();

        string addressCreated;

        // If context is Lead and propertyId is not provided, auto-assign it from the Lead record.
        if (objectApiName == 'Lead' && String.isEmpty(propertyId) && !String.isEmpty(recordId)) {
            List<Lead> leads = [SELECT Id, Property__c, City, Country, Street, State, PostalCode FROM Lead WHERE Id = :recordId LIMIT 1];
            if (!leads.isEmpty() && leads[0].Property__c != null) {
                propertyId = String.valueOf(leads[0].Property__c);
            } else {
                //try using address here from lead, it gets a bit funky
                try{

                    tempProp.Address__City__s = leads[0].City;
                    tempProp.Address__CountryCode__s = leads[0].Country;
                    tempProp.Address__StateCode__s = leads[0].State;
                    tempProp.Address__Street__s = leads[0].Street;
                    tempProp.Address__PostalCode__s = leads[0].PostalCode;
                    System.debug(tempProp);
                    noPropFoundLead = true;
                    propertyId = 'FAKEid';

                    addressCreated = leads[0].Street + ', ' + leads[0].City + ', ' + leads[0].State + ' ' + leads[0].PostalCode + ', ' + leads[0].Country;

                } catch (Exception e){

                   throw new AuraHandledException('No property or address assigned on this Lead.');
                }
            }
        }

        // If context is Account and no propertyId is provided, prompt for selection.
        if (objectApiName == 'Account' && String.isEmpty(propertyId)) {
            throw new AuraHandledException('Please select a property for this Account.');
        }

        // Query the Property__c record.
        Property__c prop;
        if(objectApiName == 'AddressOnly'){


        } else if(noPropFoundLead == false) {
            List<Property__c> props = [
                    SELECT Id, Address__c, Address__Longitude__s, Address__Latitude__s
                    FROM Property__c
                    WHERE Id = :propertyId
                    LIMIT 1
            ];
            if (props.isEmpty()) {

                throw new AuraHandledException('No property found for the given ID.');

            }
            prop = props[0];
        } else {
            prop = tempProp;
        }


        // If geolocation is missing, attempt to retrieve it using the Google Geocoding API.
        Map<String, Decimal> newGeoData = null;

        if(noPropFoundLead == true || objectApiName == 'AddressOnly'){
            newGeoData = getGeoLocationFromGoogle(addressCreated);
            if (newGeoData == null || !newGeoData.containsKey('latitude') || !newGeoData.containsKey('longitude')) {
                throw new AuraHandledException('Property location data is missing.');
            }
            prop.Address__Latitude__s = newGeoData.get('latitude');
            prop.Address__Longitude__s = newGeoData.get('longitude');
        }

        if (prop.Address__Longitude__s == null && noPropFoundLead == false || prop.Address__Latitude__s == null && noPropFoundLead == false) {

            newGeoData = getGeoLocationFromGoogle(prop.Address__c.toString());
            System.debug(newGeoData);
            if (newGeoData == null || !newGeoData.containsKey('latitude') || !newGeoData.containsKey('longitude')) {
                throw new AuraHandledException('Property location data is missing.');
            }
            prop.Address__Latitude__s = newGeoData.get('latitude');
            prop.Address__Longitude__s = newGeoData.get('longitude');
        }

        System.debug('✅ Fetching Appointments Near: Lat=' + prop.Address__Latitude__s + ', Lon=' + prop.Address__Longitude__s);

        // Retrieve nearby service appointments based on the property location.
        System.debug(prop.Address__Latitude__s);
        System.debug(prop.Address__Longitude__s);
        Map<String, List<ServiceAppointmentCoupler.ServiceAppointmentWrapper>> appointments =
                ServiceAppointmentCoupler.getNearbyAppointments(prop.Address__Latitude__s, prop.Address__Longitude__s);
        System.debug(appointments);

        return appointments;
    }

    /**
     * Returns the Account Property relationships so that a user on an Account record can choose a property.
     * The junction object is Account_Property_Relationship__c (child relationship on Account is Account_Property_Relationships__r).
     *
     * @param accountId The Id of the Account.
     * @return A list of Account_Property_Relationship__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Account_Property_Relationship__c> getAccountProperties(String accountId) {
        return [
                SELECT Id, Name, Property__c,
                        Property__r.Name,
                        Property__r.Address__Street__s,
                        Property__r.Address__City__s,
                        Property__r.Address__StateCode__s,
                        Property__r.Address__Latitude__s,
                        Property__r.Address__Longitude__s
                FROM Account_Property_Relationship__c
                WHERE Account__c = :accountId
        ];
    }

    @AuraEnabled
    public static void updateProp(Property__c prop) {
        update prop;
    }

    /**
     * Calls the Google Geocoding API to obtain latitude and longitude for a given address.
     *
     * @param address The property address.
     * @return A map containing 'latitude' and 'longitude' keys.
     */
    public static Map<String, Decimal> getGeoLocationFromGoogle(String address) {
        try {
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setMethod('GET');
            request.setEndpoint(GOOGLE_GEOCODE_URL + '?address=' + EncodingUtil.urlEncode(address, 'UTF-8') + '&key=' + GOOGLE_MAPS_API_KEY);
            System.debug('📡 Sending Geocode API Request: ' + request.getEndpoint());
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 200) {
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                if (responseBody.containsKey('status') && responseBody.get('status') == 'OK') {
                    List<Object> results = (List<Object>) responseBody.get('results');
                    if (!results.isEmpty()) {
                        Map<String, Object> geometry = (Map<String, Object>) ((Map<String, Object>) results[0]).get('geometry');
                        Map<String, Object> location = (Map<String, Object>) geometry.get('location');
                        Decimal lat = (Decimal) location.get('lat');
                        Decimal lng = (Decimal) location.get('lng');
                        System.debug('✅ Geocoded Location: Lat=' + lat + ', Lon=' + lng);
                        return new Map<String, Decimal>{ 'latitude' => lat, 'longitude' => lng };
                    }
                } else {
                    System.debug('⚠️ Geocoding API Response Error: ' + responseBody.get('status'));
                }
            } else {
                System.debug('❌ Geocoding API Request Failed. Status Code: ' + response.getStatusCode());
            }
        } catch (Exception e) {
            System.debug('❌ Error calling Google Geocoding API: ' + e.getMessage());
        }
        return null;
    }
}