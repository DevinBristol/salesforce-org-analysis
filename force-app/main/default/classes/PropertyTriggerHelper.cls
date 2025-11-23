/**
 * Created by Devin on 6/13/2024.
 */

public with sharing class PropertyTriggerHelper {

    public static List<List<SObject>> pickRecords(List<Property__c> properties){
        List<List<SObject>> returnLists = new List<List<SObject>>();
        List<SObject> propertiesNameable = new List<SObject>();
        Set<Id> propIds = new Set<Id>();
        List<SObject> opportunitiesNameable = new List<SObject>();

        if(Trigger.isInsert & Trigger.isBefore){
            for(Property__c p : properties){
                propertiesNameable.add(p);
            }
        }else if(Trigger.isUpdate && Trigger.isBefore){
            for(Property__c p : properties){
                Property__c oldProperty = (Property__c)Trigger.oldMap.get(p.Id);
                if( (p.Address__Street__s != oldProperty.Address__Street__s) || (p.Address__City__s != oldProperty.Address__City__s) || (p.Address__StateCode__s != oldProperty.Address__StateCode__s)){
                    propertiesNameable.add(p);
                }
            }
        }else if(Trigger.isUpdate && Trigger.isAfter){
            for(Property__c p : properties){
                Property__c oldProperty = (Property__c)Trigger.oldMap.get(p.Id);
                if(p.Name != oldProperty.Name){
                    propIds.add(p.Id);
                }
            }
            opportunitiesNameable = ([SELECT Id,AccountId,Opportunity_Property__c,CloseDate FROM Opportunity WHERE Opportunity_Property__c IN :propIds]);
        }
        returnLists.add(propertiesNameable);
        returnLists.add(opportunitiesNameable);
        return returnLists;
    }

    public static Boolean PropertyAccountIdIsChanged(Property__c p){
        Boolean returnBoolean;
        Property__c oldProperty = (Property__c)Trigger.oldMap.get(p.Id);
        if(p.AccountId__c != null && (oldProperty.AccountId__c == null || (p.AccountId__c != oldProperty.AccountId__c))){
            returnBoolean = true;
        } else {
            returnBoolean = false;
        }
        return returnBoolean;
    }
    public static Boolean PropertyNameIsChanged(Property__c p){
        Boolean returnBoolean;
        Property__c oldProperty = (Property__c)Trigger.oldMap.get(p.Id);
        if(p.Name != null && (oldProperty.Name == null || (p.Name != oldProperty.Name))){
            returnBoolean = true;
        } else {
            returnBoolean = false;
        }
        return returnBoolean;
    }
    public static Boolean TriggerIsAfterInsert(){
        Boolean returnBoolean;
        if(Trigger.isAfter && Trigger.isInsert){
            returnBoolean = true;
        } else {
            returnBoolean = false;
        }
        return returnBoolean;
    }
    public static Boolean TriggerIsAfterUpdate(){
        Boolean returnBoolean;
        if(Trigger.isExecuting && Trigger.isAfter && Trigger.isUpdate){
            returnBoolean = true;
        } else {
            returnBoolean = false;
        }
        return returnBoolean;
    }

    public static void HandlePropertyRelations(Map<Id,Property__c> propertyMap){
        Map<Id,Property__c> InputPropertyMap;
        if(TriggerIsAfterInsert()){
            InputPropertyMap = propertyMap;
        } else if (TriggerIsAfterUpdate()){
            InputPropertyMap = MakeInputPropertyMapAfterUpdate(propertyMap);
        }
        PropertyRelationHandler.HandlePropertyRelations(InputPropertyMap);
    }
    public static Map<Id,Property__c> MakeInputPropertyMapAfterUpdate(Map<Id,Property__c> propertyMap){
        Map<Id,Property__c> InputPropertyMap = new Map<Id,Property__c>();
        for(Property__c p : propertyMap.values()){
            if(PropertyAccountIdIsChanged(p)){
                InputPropertyMap.put(p.Id,p);
            } else if(PropertyNameIsChanged(p)){
                InputPropertyMap.put(p.Id,p);
            }
        }
        return InputPropertyMap;
    }


}