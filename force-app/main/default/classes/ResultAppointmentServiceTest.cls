/**
 * Created by noahr on 8/12/2024.
 */
@IsTest
public with sharing class ResultAppointmentServiceTest {

    @IsTest
    static void ResultSoldTest(){
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

        //region Test Cash Sold
        resultAppointmentBuffer.UpdateVisitResultSoldBuffer(newSA.Id,'test','Cash','test',5.00,' ',Date.today(),'005R70000031PSUIA2');
        Account returnedAcc = [SELECT Account_Disposition__c,isCurrent_Customer__c,Stage__c,Type FROM Account WHERE Id = :newAcc.Id];
        Opportunity returnedOpp = [SELECT Amount,StageName,Description FROM Opportunity WHERE Id = :newOpp.Id];
        ServiceAppointment returnedSA = [SELECT Appointment_Result_1__c,Appointment_Result_2__c,Appointment_Result_3__c FROM ServiceAppointment WHERE Id = :newSA.Id];

        System.assertEquals('Closed Won',returnedOpp.StageName);
        System.assertEquals(null,returnedOpp.Description);
        System.assertEquals('Cash: test',returnedAcc.Account_Disposition__c);
        System.assertEquals(true,returnedAcc.isCurrent_Customer__c);
        System.assertEquals('Customer',returnedAcc.Stage__c);
        System.assertEquals('Customer',returnedAcc.Type);

        System.assertEquals('test',returnedSA.Appointment_Result_1__c);
        System.assertEquals('Cash',returnedSA.Appointment_Result_2__c);
        System.assertEquals('test',returnedSA.Appointment_Result_3__c);
        //endregion

        //region Test Finance
        resultAppointmentBuffer.UpdateVisitResultSoldBuffer(newSA.Id,'test','Finance','Other Financing',5.00,'hehe',Date.today(),'005R70000031PSUIA2');
        Account returnedAcc2 = [SELECT Account_Disposition__c,isCurrent_Customer__c,Stage__c,Type FROM Account WHERE Id = :newAcc.Id];
        Opportunity returnedOpp2 = [SELECT Amount,StageName,Description,Finance_Type__c,Finance_Stage__c FROM Opportunity WHERE Id = :newOpp.Id];
        ServiceAppointment returnedSA2 = [SELECT Appointment_Result_1__c,Appointment_Result_2__c,Appointment_Result_3__c FROM ServiceAppointment WHERE Id = :newSA.Id];

        System.assertEquals('Financing',returnedOpp2.StageName);
        System.assertEquals('hehe',returnedOpp2.Description);
        System.assertEquals('Other Financing',returnedOpp2.Finance_Type__c);
        System.assertEquals('Financing',returnedOpp2.Finance_Stage__c);
        System.assertEquals('Finance: Other Financing',returnedAcc2.Account_Disposition__c);
        System.assertEquals(true,returnedAcc2.isCurrent_Customer__c);
        System.assertEquals('Customer',returnedAcc2.Stage__c);
        System.assertEquals('Customer',returnedAcc2.Type);

        System.assertEquals('test',returnedSA2.Appointment_Result_1__c);
        System.assertEquals('Finance',returnedSA2.Appointment_Result_2__c);
        System.assertEquals('Other Financing',returnedSA2.Appointment_Result_3__c);
        //endregion
    }

    @IsTest
    static void UpdateFollowUpTest(){
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

        Property__c newProp = new Property__c();
        newProp.Address__City__s = 'h';
        newProp.Address__Street__s = 'h';
        newProp.Address__CountryCode__s = 'US';
        newProp.Address__StateCode__s = 'NE';
        newProp.Address__PostalCode__s = '68526';
        newProp.AccountId__c = newAcc.Id;
        insert newProp;

        //region Test Not Ready
        resultAppointmentBuffer.UpdateFollowUpVisitResultBuffer(newSA.Id,'test','test','Not Ready',' ',
                Date.today(),'005R70000031PSUIA2',newProp.Id,'08qHs000000kgPPIAY');

        Account returnedAcc = [SELECT Account_Disposition__c,Stage__c FROM Account WHERE Id = :newAcc.Id];
        Opportunity returnedOpp = [SELECT StageName,Description,Lost_Reason__c FROM Opportunity WHERE Id = :newOpp.Id];
        ServiceAppointment returnedSA = [SELECT Appointment_Result_1__c,Appointment_Result_2__c,Appointment_Result_3__c FROM ServiceAppointment WHERE Id = :newSA.Id];

        System.assertEquals('Closed Lost',returnedOpp.StageName);
        System.assertEquals('Not Ready',returnedOpp.Lost_Reason__c);
        System.assertEquals(null,returnedOpp.Description);

        System.assertEquals('test: Not Ready',returnedAcc.Account_Disposition__c);
        System.assertEquals('Nurturing',returnedAcc.Stage__c);

        System.assertEquals('test',returnedSA.Appointment_Result_1__c);
        System.assertEquals('test',returnedSA.Appointment_Result_2__c);
        System.assertEquals('Not Ready',returnedSA.Appointment_Result_3__c);
        //endregion

        //region Test Call To Reset
        resultAppointmentBuffer.UpdateFollowUpVisitResultBuffer(newSA.Id,'test','test','Call To Reset',' ',
                Date.today(),'005R70000031PSUIA2',newProp.Id,'08qHs000000kgPPIAY');

        Account returnedAcc2 = [SELECT Account_Disposition__c,Stage__c FROM Account WHERE Id = :newAcc.Id];
        Opportunity returnedOpp2 = [SELECT StageName,Description,Lost_Reason__c FROM Opportunity WHERE Id = :newOpp.Id];

        System.assertEquals('Closed Lost',returnedOpp2.StageName);
        System.assertEquals(null,returnedOpp2.Description);

        System.assertEquals('test: Not Ready',returnedAcc2.Account_Disposition__c);

        //endregion

        //region Test Appointment Set

        //endregion
    }

    @IsTest
    static void UpdateFollowUpTestAgain(){
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

        Property__c newProp = new Property__c();
        newProp.Address__City__s = 'h';
        newProp.Address__Street__s = 'h';
        newProp.Address__CountryCode__s = 'US';
        newProp.Address__StateCode__s = 'NE';
        newProp.Address__PostalCode__s = '68526';
        newProp.AccountId__c = newAcc.Id;
        insert newProp;

        //region Test Not Ready
        resultAppointmentBuffer.UpdateFollowUpVisitResultBuffer(newSA.Id,'Demo / No Sale','test','Appointment Set',' ',
                Date.today(),'005R70000031PSUIA2',newProp.Id,'08qHs000000kgPPIAY');

        Opportunity returnedOpp3 = [SELECT StageName FROM Opportunity WHERE Id = :newOpp.Id];

        System.assertEquals('Rep Working',returnedOpp3.StageName);

        resultAppointmentBuffer.UpdateFollowUpVisitResultBuffer(newSA.Id,'No Demo','test','Appointment Set',' ',
                Date.today(),'005R70000031PSUIA2',newProp.Id,'08qHs000000kgPPIAY');

        Account returnedAcc3 = [SELECT Account_Disposition__c,Stage__c FROM Account WHERE Id = :newAcc.Id];
        Opportunity returnedOpp4 = [SELECT StageName,Description,Lost_Reason__c FROM Opportunity WHERE Id = :newOpp.Id];
        ServiceAppointment returnedSA3 = [SELECT Appointment_Result_1__c,Appointment_Result_2__c,Appointment_Result_3__c FROM ServiceAppointment WHERE Id = :newSA.Id];

        System.assertEquals(null,returnedOpp4.Description);
        System.assertEquals('Pending',returnedOpp4.StageName);

        System.assertEquals('test: Appointment Set',returnedAcc3.Account_Disposition__c);

        System.assertEquals('No Demo',returnedSA3.Appointment_Result_1__c);
        System.assertEquals('test',returnedSA3.Appointment_Result_2__c);
        System.assertEquals('Appointment Set',returnedSA3.Appointment_Result_3__c);
    }

    @IsTest
    static void UpdateNoDemoOrCancelledTest(){
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

        Property__c newProp = new Property__c();
        newProp.Address__City__s = 'h';
        newProp.Address__Street__s = 'h';
        newProp.Address__CountryCode__s = 'US';
        newProp.Address__StateCode__s = 'NE';
        newProp.Address__PostalCode__s = '68526';
        newProp.AccountId__c = newAcc.Id;
        insert newProp;

        resultAppointmentBuffer.UpdateNoDemoOrCancelledBuffer(newSA.Id,'test','Unreachable','test',
                ' ',Date.today(),'005R70000031PSUIA2');
        Account returnedAcc = [SELECT Account_Disposition__c,Stage__c FROM Account WHERE Id = :newAcc.Id];
        Opportunity returnedOpp = [SELECT StageName,Description,Lost_Reason__c FROM Opportunity WHERE Id = :newOpp.Id];
        ServiceAppointment returnedSA = [SELECT Appointment_Result_1__c,Appointment_Result_2__c,Appointment_Result_3__c FROM ServiceAppointment WHERE Id = :newSA.Id];

        System.assertEquals('(Re)Setting',returnedOpp.StageName);
        System.assertEquals('test',returnedSA.Appointment_Result_1__c);
        System.assertEquals('Unreachable',returnedSA.Appointment_Result_2__c);
        System.assertEquals('test',returnedSA.Appointment_Result_3__c);
        System.assertEquals('Unreachable: test',returnedAcc.Account_Disposition__c);


        resultAppointmentBuffer.UpdateNoDemoOrCancelledBuffer(newSA.Id,'test','No Interest','test',
                ' ',Date.today(),'005R70000031PSUIA2');
        Account returnedAcc2 = [SELECT Account_Disposition__c,Stage__c FROM Account WHERE Id = :newAcc.Id];
        Opportunity returnedOpp2 = [SELECT StageName,Description,Lost_Reason__c FROM Opportunity WHERE Id = :newOpp.Id];
        ServiceAppointment returnedSA2 = [SELECT Appointment_Result_1__c,Appointment_Result_2__c,Appointment_Result_3__c FROM ServiceAppointment WHERE Id = :newSA.Id];

        System.assertEquals('Closed Lost',returnedOpp2.StageName);
        System.assertEquals('No Interest',returnedOpp2.Lost_Reason__c);
        System.assertEquals('test',returnedSA2.Appointment_Result_1__c);
        System.assertEquals('No Interest',returnedSA2.Appointment_Result_2__c);
        System.assertEquals('test',returnedSA2.Appointment_Result_3__c);
        System.assertEquals('No Interest: test',returnedAcc2.Account_Disposition__c);

        resultAppointmentBuffer.UpdateNoDemoOrCancelledBuffer(newSA.Id,'test','Unqualified','test',
                ' ',Date.today(),'005R70000031PSUIA2');
        Account returnedAcc3 = [SELECT Account_Disposition__c,Stage__c FROM Account WHERE Id = :newAcc.Id];
        Opportunity returnedOpp3 = [SELECT StageName,Description,Lost_Reason__c FROM Opportunity WHERE Id = :newOpp.Id];
        ServiceAppointment returnedSA3= [SELECT Appointment_Result_1__c,Appointment_Result_2__c,Appointment_Result_3__c FROM ServiceAppointment WHERE Id = :newSA.Id];

        System.assertEquals('Closed Lost',returnedOpp3.StageName);
        System.assertEquals('Unqualified',returnedOpp3.Lost_Reason__c);
        System.assertEquals('test',returnedSA3.Appointment_Result_1__c);
        System.assertEquals('Unqualified',returnedSA3.Appointment_Result_2__c);
        System.assertEquals('test',returnedSA3.Appointment_Result_3__c);
        System.assertEquals('Unqualified: test',returnedAcc3.Account_Disposition__c);

        resultAppointmentBuffer.UpdateNoDemoOrCancelledBuffer(newSA.Id,'test','Closed / Lost','test',
                ' ',Date.today(),'005R70000031PSUIA2');
        Account returnedAcc4 = [SELECT Account_Disposition__c,Stage__c FROM Account WHERE Id = :newAcc.Id];
        Opportunity returnedOpp4 = [SELECT StageName,Description,Lost_Reason__c FROM Opportunity WHERE Id = :newOpp.Id];
        ServiceAppointment returnedSA4= [SELECT Appointment_Result_1__c,Appointment_Result_2__c,Appointment_Result_3__c FROM ServiceAppointment WHERE Id = :newSA.Id];

        System.assertEquals('Closed Lost',returnedOpp4.StageName);
        System.assertEquals('test',returnedOpp4.Lost_Reason__c);
        System.assertEquals('test',returnedSA4.Appointment_Result_1__c);
        System.assertEquals('Closed / Lost',returnedSA4.Appointment_Result_2__c);
        System.assertEquals('test',returnedSA4.Appointment_Result_3__c);
        System.assertEquals('Closed / Lost: test',returnedAcc4.Account_Disposition__c);

    }
}