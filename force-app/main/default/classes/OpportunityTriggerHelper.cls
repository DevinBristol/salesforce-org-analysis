/**
 * Created by Devin on 6/13/2024.
 */

public with sharing class OpportunityTriggerHelper {
    public static List<List<SObject>> pickRecords(List<Opportunity> opportunities) {
        List<List<SObject>> returnLists = new List<List<SObject>>();
        List<SObject> opportunitiesNameable = new List<SObject>();

        if(Trigger.isInsert & Trigger.isBefore) {
            for (Opportunity o : opportunities) {
                opportunitiesNameable.add(o);
            }
        } else if(Trigger.isUpdate && Trigger.isBefore) {
            for (Opportunity o : opportunities) {
                Opportunity oldOpp = (Opportunity) Trigger.oldMap.get(o.Id);
                if((o.CloseDate != oldOpp.CloseDate) || (o.Opportunity_Property__c != oldOpp.Opportunity_Property__c)) {
                    opportunitiesNameable.add(o);
                }
            }
        }
        returnLists.add(opportunitiesNameable);
        return returnLists;
    }
    public static Boolean OpportunityCloseDateIsChanged(Opportunity op){
        Boolean OpportunityCloseDateIsChanged;
        Opportunity oldOP = (Opportunity)Trigger.oldMap.get(op.Id);
        System.debug(oldOP.CloseDate);
        System.debug(op.CloseDate);
        if((Trigger.isExecuting && Trigger.isUpdate && Trigger.isAfter) && (op.CloseDate != oldOP.CloseDate)){
            OpportunityCloseDateIsChanged = true;
        } else {
            OpportunityCloseDateIsChanged = false;
        }
        return OpportunityCloseDateIsChanged;
    }
    public static Boolean OpportunityCompanyCamHistoryIsChanged(Opportunity op){
        Boolean OpportunityCompanyCamHistoryIsChanged;
        Opportunity oldOP = (Opportunity)Trigger.oldMap.get(op.Id);
        System.debug(oldOP.CompanyCam_Chat_History__c);
        System.debug(op.CompanyCam_Chat_History__c);
        if((Trigger.isExecuting && Trigger.isUpdate && Trigger.isAfter) && (op.CompanyCam_Chat_History__c != oldOP.CompanyCam_Chat_History__c)){
            OpportunityCompanyCamHistoryIsChanged = true;
        } else {
            OpportunityCompanyCamHistoryIsChanged = false;
        }
        return OpportunityCompanyCamHistoryIsChanged;
    }
}