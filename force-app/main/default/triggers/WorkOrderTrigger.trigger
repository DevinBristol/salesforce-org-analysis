/**
 * Created by Devin on 8/8/2024.
 */

trigger WorkOrderTrigger on WorkOrder (after insert, after update) {
    {
        new WorkOrderTriggerHandler().run();
    }
}