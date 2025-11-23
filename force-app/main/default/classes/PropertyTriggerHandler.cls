/**
 * Created by Devin on 6/6/2024.
 */

public with sharing class PropertyTriggerHandler extends TriggerHandler{

    public override void beforeInsert(){
        List<List<SObject>> recordsLists = PropertyTriggerHelper.pickRecords((List<Property__c>)Trigger.new);
        NamingUtility.NameProperty((List<Property__c>)recordsLists[0]);
    }
    public override void beforeUpdate(){
        List<List<SObject>> recordsLists = PropertyTriggerHelper.pickRecords((List<Property__c>)Trigger.new);
        NamingUtility.NameProperty((List<Property__c>)recordsLists[0]);
    }
    public override void afterUpdate(){
        List<List<SObject>> recordsLists = PropertyTriggerHelper.pickRecords((List<Property__c>)Trigger.new);
        List<Opportunity> updateOpps = NamingUtility.NameOpportunity(recordsLists[1]);
        update updateOpps;
        PropertyTriggerHelper.HandlePropertyRelations((Map<Id,Property__c>)Trigger.newMap);
    }
    public override void afterInsert(){
        TriggerHandler.bypass('LeadTriggerHandler');
        PropertyTriggerHelper.HandlePropertyRelations((Map<Id,Property__c>)Trigger.newMap);
//        WorkOrderRelationHandler.RelateUnrelatedAppointmentsFromPropertyList((List<Property__c>)Trigger.new);
    }
}