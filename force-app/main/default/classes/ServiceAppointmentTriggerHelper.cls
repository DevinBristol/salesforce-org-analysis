/**
 * Created by Devin on 8/8/2024.
 */

public with sharing class ServiceAppointmentTriggerHelper {
    public static Set<Id> getRecordsNameable(){
        Set<Id> RecordsNameable= new Set<Id>();
        if(Trigger.isExecuting && Trigger.isInsert){
            for(ServiceAppointment sa : (List<ServiceAppointment>)Trigger.newMap.values()){
                RecordsNameable.add(sa.ParentRecordId);
                RecordsNameable.add(sa.Id);
            }
        } else if (Trigger.isExecuting && Trigger.isAfter && Trigger.isUpdate){
            for(ServiceAppointment sa : (List<ServiceAppointment>)Trigger.newMap.values()){
                ServiceAppointment oldServiceAppointment = (ServiceAppointment)Trigger.oldMap.get(sa.Id);
                if(sa.SchedStartTime != oldServiceAppointment.SchedStartTime || sa.WorkType != oldServiceAppointment.WorkType || sa.AccountId != oldServiceAppointment.AccountId || sa.Appointment_Result_1__c != oldServiceAppointment.Appointment_Result_1__c){
                    RecordsNameable.add(sa.ParentRecordId);
                    RecordsNameable.add(sa.Id);
                }
            }
        }
        return RecordsNameable;
    }

}