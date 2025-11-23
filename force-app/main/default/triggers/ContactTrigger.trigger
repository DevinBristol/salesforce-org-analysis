/**
 * Created by Devin on 6/6/2024.
 */

trigger ContactTrigger on Contact (before insert , after insert, before update, after update, after delete){
    {
        new ContactTriggerHandler().run();
    }
}