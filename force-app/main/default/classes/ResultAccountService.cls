/**
 * Created by noahr on 7/2/2024.
 */

public with sharing class ResultAccountService {

    public static List<ServiceAppointment> GetServiceAppointment(String accId){
        List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE AccountId = :accId];
        List<String> oppIds = new List<String>();
        for(Opportunity op : opps){
            oppIds.add(op.Id);
        }
        System.debug(oppIds);

        List<WorkOrder> wo = [SELECT Id FROM WorkOrder WHERE Opportunity__c IN :oppIds];
        List<String> workOrderIds = new List<String>();
        for(WorkOrder wk : wo){
            workOrderIds.add(wk.Id);
        }
        System.debug(workOrderIds);

        List<ServiceAppointment> sa = [SELECT Id,Subject FROM ServiceAppointment WHERE ParentRecordId IN :workOrderIds];
        List<String> ids = new List<String>();
        for(ServiceAppointment app : sa){
            ids.add(app.Id);
        }

        System.debug(ids);

        return sa;
    }

    @AuraEnabled(Cacheable=false)
    public static void UpdateServiceAppointmentBuffer(String SserviceAppointmentId, Datetime DTnewDate){
        UpdateServiceAppointment(SserviceAppointmentId, DTnewDate);
    }


    private static void UpdateServiceAppointment(String serviceAppointmentID, Datetime newDate){
        ServiceAppointment sa = [SELECT Id, ParentRecordId, Subject FROM ServiceAppointment WHERE Id = :serviceAppointmentID];
        WorkOrder workOrder = [SELECT StartDate,EndDate, Opportunity__c,AccountId FROM WorkOrder WHERE Id = :sa.ParentRecordId];

        //Make temp Opportunity and Account
        Opportunity op = new Opportunity(Id = workOrder.Opportunity__c);
        Account acc = new Account(Id=workOrder.AccountId);

        acc.Account_Disposition__c = 'Appointment Rescheduled';
        acc.Stage__c = 'Active';
        acc.Type = 'Prospect';
        acc.Call_Back_Date__c = null;

        op.CloseDate = newDate.date();
        op.StageName = 'Pending';

        sa.SchedStartTime = newDate;
        sa.SchedEndTime = newDate.addHours(2);
        sa.EarliestStartTime = newDate;
        sa.DueDate = newDate;
        sa.ArrivalWindowStartTime = newDate;
        sa.ArrivalWindowEndTime = newDate;
        sa.Appointment_Result_1__c = 'Pending';
        sa.Appointment_Result_2__c = 'Pending';
        sa.Appointment_Result_3__c = 'Pending';

        workOrder.StartDate = newDate;
        workOrder.EndDate = newDate.addHours(2);

        update workOrder;

        String timeSet = '';
        if(newDate.hour() > 12){
            timeSet = (newDate.hour() - 12).toString() + ':' + newDate.minute() + ' PM';
        } else{
            timeSet = (newDate.hour()).toString() + ':' + newDate.minute() + ' AM';
        }

        List<String> firstLast = sa.Subject.split(' ');
        System.debug(firstLast);
        sa.Subject = firstLast[0] + ' ' + firstLast[1] + '  : Initial Sales Visit - ' + newDate.month() + '/' + newDate.day() + '/' +
                newDate.year() + ', ' + timeSet;

        update sa;
        update op;
        update acc;
    }

}