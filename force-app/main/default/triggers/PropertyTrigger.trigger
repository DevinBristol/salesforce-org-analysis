/**
 * Created by Devin on 6/6/2024.
 */

trigger PropertyTrigger on Property__c(before insert, before update, after update,after insert) {
    {
        new PropertyTriggerHandler().run();
    }
}