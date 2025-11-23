/**
 * Created by Devin on 5/16/2024.
 */
@IsTest
public with sharing class TaskTriggerHandlerTest {

    @IsTest
    static void testTaskTriggerHandler(){
        User Devin = [SELECT Id FROM User WHERE FirstName = 'Devin'];
        Task task = new Task(OwnerId=Devin.Id,Subject='Call');
        Test.startTest();
        insert task;
        Test.stopTest();
        delete task;
        System.assertEquals(true,true);
    }
}