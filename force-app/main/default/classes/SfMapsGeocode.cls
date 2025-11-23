/**
 * Created by brist on 1/14/2025.
 */

public with sharing class SfMapsGeocode {
    public static Map<String,Property__c> propMap = new Map<String,Property__c>();
    public static Map<String,Object> getBatchGeocodes(List<Property__c> props){
        Map<String,Map<String,String>> addresses = new Map<String,Map<String,String>>();
        for(Property__c prop : props){
            Map<String,String> address = new Map<String,String>{
                    'address'=>
                            prop.Address__c.getStreet().substringBefore(' ')+' '+prop.Address__c.getStreet().substringAfter(' ')+', '+prop.Address__c.getCity()+', '+
                                    prop.Address__c.getState()+' '+prop.Address__c.getPostalCode()+' '+prop.Address__c.getCountry()
            };
            String idStr = Id.valueOf(prop.Id);
            addresses.put(idStr,address);
            propMap.put(idStr.toLowerCase(),prop);
        }
        System.debug(JSON.serializePretty(addresses));
        Map<String,Object> response;
        try{
            response = maps.API.BatchGeocode(new Map<String,Object>{
                    'version'=>'2','address_info'=>JSON.serialize(addresses)});
        }
        catch(Exception ex){ System.debug(ex);
        }
        return response;
    }
    public static List<Property__c> assignResponseToProperties(Map<String,Object> resMap){
        List<Property__c> returnProps = new List<Property__c>();
        System.debug('geocode response: '+'\n'+JSON.serializePretty(resMap));
        List<Property__c> propsWithBadData = new List<Property__c>();
        System.debug(resMap);
        Boolean callSuccess=(Boolean)resMap.get('success');
        if(callSuccess!=null){
            Map<String,Object> results = (Map<String,Object>)resMap.get('results');
            for(String propId : results.keySet()){
                Property__c prop = propMap.get(propId);
                System.debug(propMap);
                System.debug(propMap.get(propId));
                Map<String,Object> record = (Map<String,Object>)results.get(propId);
                if((Boolean)record.get('success')){
                    Map<String,Object> data = (Map<String,Object>)record.get('data');
                    Map<String, Object> position = (Map<String,Object>) data.get('position');
                    if((Decimal)position.get('lat')==null||(Decimal)position.get('lng')==null){
                        System.debug('!!![[THIS STREET—–>('+prop.Address__Street__s+')<–— IS FAKE!!!]]');
                        propsWithBadData.add(prop);
                    } else {
                        System.debug((Decimal)position.get('lat'));
                        Decimal lat = (Decimal)position.get('lat');
                        Decimal lng = (Decimal)position.get('lng');
                        prop.Address__Latitude__s = lat;
                        System.debug('post assigned coords = '+prop.Address__Latitude__s+','+prop.Address__Longitude__s);
                        prop.Address__Longitude__s = lng;
                        returnProps.add(prop);
                    }
                    if((Integer)data.get('score')<50) {
                        propsWithBadData.add(prop);// Low confidence in address match. Marking the props needed for review.
                    }
                } else {
                    propsWithBadData.add(prop); //no match with provided address!!!!!
                }
            }
        }
//        else {
//            String errorCode=(String)response.get('error_Code');
//            if(errorCode == 'GC-0500'||errorCode == 'GC-0429'||errorCode!=null&&errorCode.startsWith('GC-1')){
//                System.debug('errorCode!!!!'+errorCode+'...'+response);
//            }
//        }
        return returnProps;
    }
}