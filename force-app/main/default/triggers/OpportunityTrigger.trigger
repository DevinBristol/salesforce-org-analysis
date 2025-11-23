/**
 * Created by Devin on 6/6/2024.
 */

trigger OpportunityTrigger on Opportunity (before insert, before update, after update) {
    {
        new OpportunityTriggerHandler().run();
    }
}