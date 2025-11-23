/**
 * Created by Devin on 8/12/2024.
 */

public with sharing class WorkOrderRelationHandler {


    @InvocableMethod(Label = 'Check Unrelated Appointments' Category = 'Account')
    public static void RelateUnrelatedAppointmentsFromAccountIds(List<Id> ids){
        for(Id id : ids){ Set<Id> idSet = new Set<Id>{id}; Map<Id,Account> accountMap = WorkOrderRelationHelper.getAccountMap(idSet);
            for(Account a : accountMap.values()){
                WorkOrderRelationHelper.RelatedUnrelatedAppointments(a);
            }
        }
    }
    public static void RelateUnrelatedAppointmentsFromPropertyList(List<Property__c> properties){
        for(Property__c p : properties){
            Set<Id> Ids = new Set<Id>{p.AccountId__c};
            Map<Id,Account> accountMap = WorkOrderRelationHelper.getAccountMap(Ids);
            System.debug(accountMap);
            for(Account a : accountMap.values()){
                WorkOrderRelationHelper.RelatedUnrelatedAppointments(a);
            }
        }
    }

}