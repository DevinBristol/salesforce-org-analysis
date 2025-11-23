/**
 * Created by noahr on 6/21/2024.
 */

public with sharing class OpportunityPageService {

    public static void ChangeStatus(String newStatus, String oppId, String reasonOne, String reasonTwo){
        Opportunity swappedOpportunity = [SELECT StageName,AccountId,Lost_Reason__c FROM Opportunity WHERE Id = :oppId];

        if(newStatus == 'Not Ready'){
            Account linkedAccount = [SELECT Stage__c FROM Account WHERE Id = :swappedOpportunity.AccountId];

            linkedAccount.Stage__c = 'Nurturing';
            update linkedAccount;
            newStatus = 'Closed Lost';
        }
        else if(newStatus == 'Lost'){
            Account linkedAccount = [SELECT Stage__c, Account_Disposition__c FROM Account WHERE Id = :swappedOpportunity.AccountId];
            if(reasonOne == 'Unqualified'){
                linkedAccount.Stage__c = 'Lost';
                linkedAccount.Account_Disposition__c = reasonOne + ': ' + reasonTwo;
                swappedOpportunity.Lost_Reason__c = reasonOne + ': ' + reasonTwo;
            }
            else if(reasonOne == 'Closed / Lost'){
                linkedAccount.Stage__c = 'Lost';
                linkedAccount.Account_Disposition__c = reasonOne + ': ' + reasonTwo;
                swappedOpportunity.Lost_Reason__c = reasonOne + ': ' + reasonTwo;
            }

            update linkedAccount;
            newStatus = 'Closed Lost';
        }
        else if(newStatus == 'No Interest'){
            Account linkedAccount = [SELECT Stage__c, Account_Disposition__c FROM Account WHERE Id = :swappedOpportunity.AccountId];
            linkedAccount.Stage__c = 'Nurturing';
            linkedAccount.Account_Disposition__c = reasonOne + ': ' + reasonTwo;
            swappedOpportunity.Lost_Reason__c = reasonOne + ': ' + reasonTwo;

            update linkedAccount;
            newStatus = 'No Interest';
        }

        if(newStatus == 'Reset'){
            newStatus = 'Confirming';
        }

        swappedOpportunity.StageName = newStatus;
        update swappedOpportunity;
    }

    public static void CreateCallback(Datetime followUpDate, String sDescription, String accountId,Id userId,Boolean isUnreachable){
        Account linkedAccount = [SELECT Name,Primary_Contact__c FROM Account WHERE Id = :accountId LIMIT 1];

        Date d = Date.newInstance(followUpDate.year(),followUpDate.month(),followUpDate.day());
        if(String.isEmpty(sDescription)){
            sDescription = ' ';
        }

        if(linkedAccount.Primary_Contact__c != null ){
            if(isUnreachable){
                Task newTask = new Task(
                        Subject = '(Unreachable)Follow Up For: ' + linkedAccount.Name,
                        ActivityDate = d,
                        IsReminderSet = true,
                        ReminderDateTime = followUpDate,
                        Description = sDescription,
                        OwnerId = userId,
                        WhatId = accountId,
                        WhoId = linkedAccount.Primary_Contact__c
                );

                insert newTask;
            } else {
                Task newTask = new Task(
                        Subject = 'Follow Up For: ' + linkedAccount.Name,
                        ActivityDate = d,
                        IsReminderSet = true,
                        ReminderDateTime = followUpDate,
                        Description = sDescription,
                        OwnerId = userId,
                        WhatId = accountId,
                        WhoId = linkedAccount.Primary_Contact__c
                );
                insert newTask;
            }
        }else {
            if(isUnreachable) {
                Task newTask = new Task(
                        Subject = '(Unreachable)Follow Up For: ' + linkedAccount.Name,
                        ActivityDate = d,
                        IsReminderSet = true,
                        ReminderDateTime = followUpDate,
                        Description = sDescription,
                        OwnerId = userId,
                        WhatId = accountId
                );

                insert newTask;
            }
            else{
                Task newTask = new Task(
                        Subject = 'Follow Up For: ' + linkedAccount.Name,
                        ActivityDate = d,
                        IsReminderSet = true,
                        ReminderDateTime = followUpDate,
                        Description = sDescription,
                        OwnerId = userId,
                        WhatId = accountId
                );

                insert newTask;
            }
        }
    }

    public static void WorkOrderCreation(Datetime workDate, String sOwnerId, String oppId, String workTypeId, String sAccountId){

        Contact con = [SELECT Id FROM Contact WHERE AccountId = :sAccountId LIMIT 1];

        WorkOrder newWorkOrder = new WorkOrder(
                Opportunity__c = oppId,
                AccountId = sAccountId,
                ContactId = con.Id,
                StartDate = workDate,
                OwnerId = sOwnerId,
                WorkTypeId = workTypeId
        );

        insert newWorkOrder;
    }
}