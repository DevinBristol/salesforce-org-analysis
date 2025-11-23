/**
 * Created by Devin on 6/6/2024.
 */

public with sharing class OpportunityTriggerHandler extends TriggerHandler{

    public override void beforeInsert(){
        List<List<SObject>> recordsLists = OpportunityTriggerHelper.pickRecords((List<Opportunity>)Trigger.new);
        NamingUtility.NameOpportunity(recordsLists[0]);
    }
    public override void beforeUpdate(){
        List<List<SObject>> recordsLists = OpportunityTriggerHelper.pickRecords((List<Opportunity>)Trigger.new);
        NamingUtility.NameOpportunity(recordsLists[0]);
    }
//    public override void afterUpdate(){
//        List<Opportunity> opportunitiesNotifyCloseDateChange = new List<Opportunity>();
//        List<Opportunity> opportunitiesNotifyCompanyCamChange = new List<Opportunity>();
//        for(Opportunity op : (List<Opportunity>)Trigger.new){
//            if(OpportunityTriggerHelper.OpportunityCloseDateIsChanged(op)) {
//                opportunitiesNotifyCloseDateChange.add(op);
//            }
//            if(OpportunityTriggerHelper.OpportunityCompanyCamHistoryIsChanged(op)){
//                opportunitiesNotifyCompanyCamChange.add(op);
//            }
//        }
//        if(!opportunitiesNotifyCloseDateChange.isEmpty()) {
//            System.debug(opportunitiesNotifyCloseDateChange);
//            CustomNotifications.sendCloseDateChangeNotification(opportunitiesNotifyCloseDateChange);
//        }
//        if(!opportunitiesNotifyCompanyCamChange.isEmpty()) {
//            System.debug(opportunitiesNotifyCompanyCamChange);
//            CustomNotifications.sendCompanyCamHistoryChangeNotification(opportunitiesNotifyCompanyCamChange);
//        }
//    }
}