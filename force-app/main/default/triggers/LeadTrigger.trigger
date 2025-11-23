/**
 * Created by Devin on 6/4/2024.
 */

trigger LeadTrigger on Lead (before insert, after insert,before update, after update, after delete){
    {
        Process_Switches__c processSwitches = Process_Switches__c.getInstance(UserInfo.getProfileId());

        if(processSwitches.Lead_Process_Bypass__c){
            return;
        } else {
            new LeadTriggerHandler().run();
        }
    }
}