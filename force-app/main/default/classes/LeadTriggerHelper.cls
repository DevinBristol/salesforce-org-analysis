/**
 * Created by Devin on 6/13/2024.
 */

public with sharing class LeadTriggerHelper {

//    public static Boolean IsAfterUpdate(){
//        Boolean isAfter;
//        if(Trigger.isExecuting && Trigger.isAfter){
//            isAfter = true;
//        } else {
//            isAfter = false;
//        }
//        return isAfter;
//    }

    public static Boolean LeadIsNameable(Lead l){
        Boolean isNameable;
        if((String.isNotBlank(l.FirstName) || String.isNotBlank(l.LastName) || String.isNotBlank(l.SecondaryContactFirstName__c ) || String.isNotBlank(l.Secondary_Contact_Last_Name__c ))){
            isNameable = true;
        } else {
            isNameable = false;
        }
        return isNameable;
    }
    public static Boolean PhoneIsDeformatable(Lead l){
        Boolean isDeformatable;
        if((l.MobilePhone != null && (l.MobilePhone.containsAny('[^0-9]') || l.MobilePhone.startsWith('1'))) || (l.Phone != null && (l.Phone.containsAny('[^0-9]') || l.Phone.startsWith('1')))|| (l.Secondary_Contact_Mobile__c != null && (l.Secondary_Contact_Mobile__c.containsAny('[^0-9]') || l.Secondary_Contact_Mobile__c.startsWith('1')))){
            isDeformatable = true;
        } else {
            isDeformatable = false;
        }
        return isDeformatable;
    }
    public static Boolean PhonesAreRelatable(Lead l){
        Boolean AreRelatable;
        Lead oldLead = (Lead)Trigger.oldMap.get(l.Id);
        System.debug('LeadTriggerHelper : PhonesAreRelatable PhonesCamparison ::: ' + l.MobilePhone + ' :' + oldLead.MobilePhone );

        if((l.MobilePhone != oldLead.MobilePhone) || (l.Phone != oldLead.Phone) || (l.Secondary_Contact_Mobile__c != oldLead.Secondary_Contact_Mobile__c)){
            AreRelatable = true;
        } else {
            AreRelatable = false;
        }
        System.debug('LeadTriggerHelper : PhoneRelatable? ::: ' + AreRelatable);
        return AreRelatable;
    }
    public static Boolean PropertiesAreRelatable(Lead l){
        Boolean AreRelatable;

        Lead oldLead = (Lead)Trigger.oldMap.get(l.Id);
        if((Trigger.isExecuting && Trigger.isInsert && Trigger.isAfter) || (l.Street != oldLead.Street) || (l.City != oldLead.City) || (l.State != oldLead.State)){
            AreRelatable = true;
        } else {
            AreRelatable = false;
        }
        System.debug('LeadTriggerHelper : PropertyRelatable? ::: ' + AreRelatable);
        return AreRelatable;
    }
    public static void RelateLeadProperties(Map<Id,Lead> LeadMap){
        Set<String> Streets = new Set<String>();
        List<Lead> LeadsToRelate = new List<Lead>();
        List<Property__c> propertiesCreatable = new List<Property__c>();
        Map<Id,Property__c> InputPropertyMap = new Map<Id,Property__c>();
        System.debug('LeadTriggerHelper : LeadMap' + LeadMap);

        for(Lead l :LeadMap.values()){
            if(!LeadStreetIsNull(l) && LeadPropertyIsNull(l)){
                LeadsToRelate.add(l);
                Streets.add(l.Street);
            } else if (!LeadStreetIsNull(l) && Trigger.isExecuting && Trigger.isAfter && LeadStreetIsChanged(l)){
                LeadsToRelate.add(l);
                Streets.add(l.Street);
            }
        }
        Map<String,Property__c> PropertyMap = getPropertiesByStreets(Streets);
        for(Lead l : LeadsToRelate){
            if(!PropertyMap.keySet().contains(l.Street+l.City)){
                propertiesCreatable.add(new Property__c(Address__Street__s = l.Street, Address__City__s = l.City,Address__StateCode__s = NamingUtility.StateNameToStateCode(l.State), Address__CountryCode__s = NamingUtility.CountryNameToCountryCode(l.Country), Address__PostalCode__s = l.PostalCode));
            }
        }
        System.debug('LeadTriggerHelper : PropertyMap' + PropertyMap);
        System.debug('LeadTriggerHelper : LeadsToRelate' + LeadsToRelate);
        System.debug('LeadTriggerHelper : PropertiesCreatable' + propertiesCreatable);
        insert propertiesCreatable;
        InputPropertyMap.putAll(PropertyMap.values());
        InputPropertyMap.putAll(propertiesCreatable);

        PropertyRelationHandler.HandlePropertyRelations(InputPropertyMap);
    }
    public static Map<String,Property__c> getPropertiesByStreets(Set<String> Streets){
        Map<String,Property__c> returnMap= new Map<String,Property__c>();
        List<Property__c> properties = new List<Property__c>([SELECT Id,Address__Street__s,Address__City__s,AccountId__c FROM Property__c WHERE Address__Street__s IN :Streets]);
        for(Property__c p : properties){
            returnMap.put(p.Address__Street__s + p.Address__City__s,p);
        }
        return returnMap;
    }
    public static Boolean LeadStreetIsChanged(Lead l){
        Boolean returnBoolean;
        Lead oldLead = (Lead)Trigger.oldMap.get(l.Id);
        if(l.Street != oldLead.Street){
            returnBoolean = true;
        } else {
            returnBoolean = false;
        }
        return returnBoolean;
    }
    public static Boolean LeadStreetIsNull(Lead l){
        Boolean returnBoolean;
        if(l.Street == null){
            returnBoolean = true;
        } else {
            returnBoolean = false;
        }
        return returnBoolean;
    }
    public static Boolean LeadPropertyIsNull(Lead l){
        Boolean returnBoolean;
        if(l.Property__c == null){
            returnBoolean = true;
        } else {
            returnBoolean = false;
        }
        return returnBoolean;
    }
    public static List<Lead> DeformatLeadNumbers(List<Lead> leads){
        List<Lead> returnLeads = new List<Lead>();
        for(Lead l: leads){
            if((l.MobilePhone != null && (l.MobilePhone.containsAny('[^0-9]') || l.MobilePhone.startsWith('1')))){
                l.MobilePhone = PhoneNumberService.DeformatPhone(l.MobilePhone);
            }
            if((l.Phone != null && (l.Phone.containsAny('[^0-9]') || l.Phone.startsWith('1')))){
                l.Phone = PhoneNumberService.DeformatPhone(l.Phone);
            }
            if( (l.Secondary_Contact_Mobile__c != null && (l.Secondary_Contact_Mobile__c.containsAny('[^0-9]') || l.Secondary_Contact_Mobile__c.startsWith('1')))){
                l.Secondary_Contact_Mobile__c = PhoneNumberService.DeformatPhone(l.Secondary_Contact_Mobile__c);
            }
            returnLeads.add(l);
        }
        return returnLeads;
    }
}