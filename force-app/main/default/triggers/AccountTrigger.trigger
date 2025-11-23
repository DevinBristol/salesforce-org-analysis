/**
 * Created by Devin on 6/5/2024.
 */

trigger AccountTrigger on Account (before insert, after insert, after update) {
    {
        new AccountTriggerHandler().run();
    }
}