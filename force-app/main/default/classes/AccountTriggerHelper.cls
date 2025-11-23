/**
 * Created by Devin on 6/13/2024.
 */

public with sharing class AccountTriggerHelper {

    public static List<List<SObject>> pickRecords(List<Account> accounts) {
        List<List<SObject>> returnLists = new List<List<SObject>>();
        Set<Id> accIds = new Set<Id>();
        Set<Id> accIdsDispoed = new Set<Id>();
        List<SObject> opportunitiesNameable = new List<SObject>();
        List<SObject> accountsNameable = new List<SObject>();
        List<SObject> ContactsDispoable = new List<SObject>();



        if(Trigger.isBefore && (Trigger.isUpdate || Trigger.isInsert)){
            for(Account a : accounts){
                if(a.Open_Opportunity_Count__c > 0){
                    a.Stage__c = 'Active';
                }
            }
        }
        if(Trigger.isInsert && Trigger.isAfter) {
            for (Account a : accounts) {
                accountsNameable.add(a);
            }
        } else if(Trigger.isUpdate && Trigger.isAfter) {
            for (Account a : accounts) {
                Account oldAcc = (Account)Trigger.oldMap.get(a.Id);
                if(a.Name != oldAcc.Name){
                    accIds.add(a.Id);
                }
                if(a.Account_Disposition__c != oldAcc.Account_Disposition__c){
                    accIdsDispoed.add(a.Id);
                }
            }
            opportunitiesNameable = [SELECT Id,AccountId,Opportunity_Property__c,CloseDate FROM Opportunity WHERE AccountId IN :accIds];
            UpdateWorkOrderAndServiceAppointmentNames(accIds);
            UpdateContactDisposOnNewAccountDispo(accIdsDispoed);
        }
        returnLists.add(accountsNameable);
        returnLists.add(opportunitiesNameable);
        return returnLists;
    }
    public static void UpdateWorkOrderAndServiceAppointmentNames(Set<Id> AccountIds){
        Map<Id,WorkOrder> WorkOrderMap = new Map<Id,WorkOrder>([SELECT Id FROM WorkOrder WHERE AccountId IN :AccountIds]);
        Map<Id,ServiceAppointment> ServiceAppointmentMap = new Map<Id,ServiceAppointment>([SELECT Id FROM ServiceAppointment WHERE AccountId IN :AccountIds]);
        Set<Id> Ids = new Set<Id>();
        Ids.addAll(WorkOrderMap.keySet());
        Ids.addAll(ServiceAppointmentMap.keySet());
        NamingUtility.NameWorkOrdersAndServiceAppointments(Ids);
    }
    public static void UpdateContactDisposOnNewAccountDispo(Set<Id> AccountIds){
        List<Account> accounts = new List<Account>([SELECT Id,Account_Disposition__c, (SELECT Id FROM Contacts) FROM Account WHERE Id IN :AccountIds]);
        List<Contact> UpdateableContacts = new List<Contact>();
        for(Account a : accounts){
            for(Contact c : a.Contacts){
                c.Account_Disposition__c = a.Account_Disposition__c;
                UpdateableContacts.add(c);
            }
        }
        update UpdateableContacts;
    }
    public static void UpdateAccountStageOnNull(){
        List<Account> accounts = (List<Account>)Trigger.new;
        for(Account ac : accounts){
            if(ac.Stage__c == null){
                ac.Stage__c = 'Nurturing';
            }
        }
    }
}