/**
 * Created by Devin on 8/8/2024.
 */

public with sharing class ServiceAppointmentTriggerHandler extends TriggerHandler{

    public override void afterInsert(){
        TriggerHandler.bypass('WorkOrderTriggerHandler');
        NamingUtility.NameWorkOrdersAndServiceAppointments(ServiceAppointmentTriggerHelper.getRecordsNameable());
    }
    public override void afterUpdate(){
        TriggerHandler.bypass('WorkOrderTriggerHandler');
        NamingUtility.NameWorkOrdersAndServiceAppointments(ServiceAppointmentTriggerHelper.getRecordsNameable());
    }
}