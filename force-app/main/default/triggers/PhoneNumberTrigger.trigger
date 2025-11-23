/**
 * Created by Devin on 7/5/2024.
 */

trigger PhoneNumberTrigger on PhoneNumber__c (after update) {
    {
        new PhoneNumberTriggerHandler().run();
    }
}