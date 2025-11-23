/**
 * Created by Devin on 8/8/2024.
 */

public with sharing class WorkOrderTriggerHandler extends TriggerHandler{
    public override void afterUpdate(){
        this.setMaxLoopCount(4);
        WorkOrderTriggerHelper.NameWorkOrders();
    }
}