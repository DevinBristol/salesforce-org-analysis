/**
 * Created by noahr on 5/6/2024.
 */

trigger TaskTrigger on Task (before insert, after insert, after update) {
    {
        new TaskTriggerHandler().run();
    }
}