/**
 * Created by noahr on 8/12/2024.
 */

@IsTest
public with sharing class ResultAccountServiceTest {

    @IsTest
    static void GetServiceAppointmentTest(){
        Account newAcc = new Account(
                Name = 'Placeholder'
        );
        insert newAcc;

        Opportunity newOpp = new Opportunity(
                AccountId = newAcc.Id,
                StageName = 'Nurturing',
                CloseDate = Date.today()
        );
        insert newOpp;

        WorkOrder newWO = new WorkOrder(
                Opportunity__c = newOpp.Id
        );
        insert newWO;

        ServiceAppointment newSA = new ServiceAppointment(
                ParentRecordId = newWO.Id
        );
        insert newSA;

        List<ServiceAppointment> services = ResultAccountController.GetServiceAppointmentBuffer(newAcc.Id);

        System.assertEquals(1,services.size());
    }

    @IsTest
    static void UpdateServiceAppointmentBufferTest(){
        Account newAcc = new Account(
                Name = 'Placeholder'
        );
        insert newAcc;

        Opportunity newOpp = new Opportunity(
                AccountId = newAcc.Id,
                StageName = 'Nurturing',
                CloseDate = Date.today()
        );
        insert newOpp;

        WorkOrder newWO = new WorkOrder(
                Opportunity__c = newOpp.Id,
                AccountId = newAcc.Id
        );
        insert newWO;

        ServiceAppointment newSA = new ServiceAppointment(
                ParentRecordId = newWO.Id
        );
        insert newSA;

        Datetime dt = Datetime.newInstance(2025, 7, 9, 14, 30, 0);

        ResultAccountService.UpdateServiceAppointmentBuffer(newSA.Id,dt);

        ServiceAppointment returnedSA = [SELECT SchedStartTime,SchedEndTime FROM ServiceAppointment WHERE Id = :newSA.Id];
        System.debug(returnedSA);

        System.assertEquals(dt,returnedSA.SchedStartTime);
    }

}