/**
 * Created by Devin on 8/8/2024.
 */

public with sharing class WorkOrderTriggerHelper {
    public static void NameWorkOrders(){
        Set<Id> NameableWorkOrderIds = CheckForNameChanges();
        NamingUtility.NameWorkOrdersAndServiceAppointments(NameableWorkOrderIds);
    }
    private static Set<Id> CheckForNameChanges(){
        Set<Id> WorkOrderIds = new Set<Id>();
            for(WorkOrder wo : (List<WorkOrder>)Trigger.newMap.values()){
                WorkOrder oldWorkOrder = (WorkOrder)Trigger.oldMap.get(wo.Id);
                if(wo.AccountId != oldWorkOrder.AccountId || wo.WorkType != oldWorkOrder.WorkType){
                    WorkOrderIds.add(wo.Id);
                }
            }
        return WorkOrderIds;
    }
}