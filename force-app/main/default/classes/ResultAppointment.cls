/**
 * Created by noahr on 6/27/2024.
 */

public with sharing class ResultAppointment {
    public static void UpdateVisitResultSold(String appointmentId, String reasonOne, String reasonTwo, String reasonThree, Decimal amount,
                                             String closingNotes,Date closedDate,String assignedUserId){
        ServiceAppointment serviceApp = [SELECT ParentRecordId, Status, Appointment_Result_1__c, Appointment_Result_2__c,Appointment_Result_3__c FROM ServiceAppointment WHERE Id = :appointmentId];
        WorkOrder wrk = [SELECT Opportunity__c, Opportunity__r.Id, Opportunity__r.AccountId,Opportunity__r.Amount FROM WorkOrder WHERE Id = :serviceApp.ParentRecordId];

        Opportunity linkedOpp = new Opportunity(Id = wrk.Opportunity__r.Id,Amount = wrk.Opportunity__r.Amount);
        Account linkedAcc = new Account(Id = wrk.Opportunity__r.AccountId);

        if(reasonTwo == 'Cash'){
            linkedOpp.Description = closingNotes;
            linkedOpp.StageName = 'Closed Won';

            linkedAcc.Account_Disposition__c = reasonTwo + ': ' + reasonThree;
            linkedAcc.Stage__c = 'Customer';
            linkedAcc.Type = 'Customer';
            linkedAcc.isCurrent_Customer__c = true;

            serviceApp.Appointment_Result_1__c = reasonOne;
            serviceApp.Appointment_Result_2__c = reasonTwo;
            serviceApp.Appointment_Result_3__c = reasonThree;
        }
        else if(reasonTwo == 'Finance'){
            linkedOpp.CloseDate = closedDate;
            linkedOpp.Finance_Stage__c = 'Financing';
            linkedOpp.Finance_Type__c = reasonThree;
            linkedOpp.StageName = 'Financing';
            linkedOpp.Description = closingNotes;

            User FinanceManager = [SELECT Id FROM User WHERE FirstName = 'Jeanne' LIMIT 1];
            OpportunityTeamMember oppMember = new OpportunityTeamMember(
                    OpportunityAccessLevel = 'Edit',
                    OpportunityId = wrk.Opportunity__r.Id,
                    TeamMemberRole = 'Finance Manager',
//                    UserId = assignedUserId //This worked
                    UserId = FinanceManager.Id
            );

            insert oppMember;

            linkedAcc.Account_Disposition__c = reasonTwo + ': ' + reasonThree;

            serviceApp.Appointment_Result_1__c = reasonOne;
            serviceApp.Appointment_Result_2__c = reasonTwo;
            serviceApp.Appointment_Result_3__c = reasonThree;
        }

        update serviceApp;
        update linkedOpp;
        update linkedAcc;

        List<OpportunityLineItem> lineItems = HandleOpportunityAmount(linkedOpp,amount);

        update lineItems;
    }

    public static void UpdateFollowUpVisitResult(String appointmentId, String reasonOne, String reasonTwo, String reasonThree,String sDescription,
                                                 Datetime followUpDate, String ownedUserId, String propId, String workType){
        ServiceAppointment serviceApp = [SELECT ParentRecordId, Status, Appointment_Result_1__c, Appointment_Result_2__c,Appointment_Result_3__c FROM ServiceAppointment WHERE Id = :appointmentId];
        WorkOrder wrk = [SELECT Opportunity__c, Opportunity__r.Id, Opportunity__r.AccountId,Opportunity__r.Amount FROM WorkOrder WHERE Id = :serviceApp.ParentRecordId];

        Opportunity linkedOpp = new Opportunity(Id = wrk.Opportunity__r.Id,Amount = wrk.Opportunity__r.Amount);
        Account linkedAcc = new Account(Id = wrk.Opportunity__r.AccountId);

        Date setDate = Date.newInstance(followUpDate.year(),followUpDate.month(),followUpDate.day());
        if(reasonThree == 'Not Ready'){
            Account linkedAccount = [SELECT Name,OwnerId FROM Account WHERE Id = :wrk.Opportunity__r.AccountId];
            //Create Task On FollowUp - Not Ready
            Task newTask = new Task(
                    ActivityDate = setDate,
                    Description = sDescription,
                    OwnerId = linkedAccount.OwnerId,
                    Subject = '(Not Ready) Follow Up For: ' + linkedAccount.Name,
                    Task_Result__c = 'Pending',
                    WhatId = linkedAccount.Id
            );

            insert newTask;

            //Update Opp To Not Ready
            linkedOpp.Description = sDescription;
            linkedOpp.Lost_Reason__c = reasonThree;
            linkedOpp.StageName = 'Closed Lost';
            linkedOpp.Next_Step_Date__c = null;

            //Update Service Appointment - Not Ready
            serviceApp.Appointment_Result_1__c = reasonOne;
            serviceApp.Appointment_Result_2__c = reasonTwo;
            serviceApp.Appointment_Result_3__c = reasonThree;

            //Update Account - Not Ready
            linkedAcc.Stage__c = 'Nurturing';
            linkedAcc.Account_Disposition__c = reasonTwo + ': ' + reasonThree;
            linkedAcc.Call_Back_Date__c = followUpDate;
        }
        else if(reasonThree == 'Rep Working'){
            //Create Task On FollowUp - Re/Set
            Account linkedAccount = [SELECT Name FROM Account WHERE Id = :wrk.Opportunity__r.AccountId];
//            Task newTask = new Task(
//                    ActivityDate = Date.today().addDays(2),
//                    Description = sDescription,
//                    OwnerId = ownedUserId,
//                    Subject = '2 Day Follow Up For: ' + linkedAccount.Name,
//                    Task_Result__c = 'Pending',
//                    WhatId = linkedAccount.Id
//            );
//
//            Task anotherNewTask = new Task(
//                    ActivityDate = setDate,
//                    Description = sDescription,
//                    OwnerId = ownedUserId,
//                    Subject = '(Rep Working) Set Date Follow Up For: ' + linkedAccount.Name,
//                    Task_Result__c = 'Pending',
//                    WhatId = linkedAccount.Id);
//
//            insert newTask;
//            insert anotherNewTask;

            linkedOpp.Description = sDescription;
            linkedOpp.CloseDate = setDate;
            linkedOpp.StageName = 'Rep Working';

            //Update Service Appointment - Re/Set
            serviceApp.Appointment_Result_1__c = reasonOne;
            serviceApp.Appointment_Result_2__c = reasonTwo;
            serviceApp.Appointment_Result_3__c = reasonThree;

            //Update Account - Re/Set
            linkedAcc.Account_Disposition__c = reasonTwo + ': ' + reasonThree;
            linkedAcc.Call_Back_Date__c = followUpDate;

        }
        else if(reasonThree == 'ReHash'){
            Account linkedAccount = [SELECT Name,OwnerId FROM Account WHERE Id = :wrk.Opportunity__r.AccountId];
            Task newTask = new Task(
                    ActivityDate = setDate,
                    Description = sDescription,
                    OwnerId = linkedAccount.OwnerId,
                    Subject = '(ReHash) Follow Up For: ' + linkedAccount.Name,
                    Task_Result__c = 'Pending',
                    WhatId = linkedAccount.Id
            );
            insert newTask;

            linkedOpp.Description = sDescription;
            linkedOpp.CloseDate = setDate;
            linkedOpp.StageName = 'Closed Lost';
            linkedOpp.Next_Step_Date__c = null;


            //Update Service Appointment - Re/Set
            serviceApp.Appointment_Result_1__c = reasonOne;
            serviceApp.Appointment_Result_2__c = reasonTwo;
            serviceApp.Appointment_Result_3__c = reasonThree;

            //Update Account - Re/Set
            linkedAcc.Account_Disposition__c = reasonTwo + ': ' + reasonThree;
            linkedAcc.Call_Back_Date__c = followUpDate;
            linkedAcc.Type = 'Prospect';
            linkedAcc.Stage__c = 'Working';

        }
        else if(reasonThree == 'Appointment Set'){
            //So if its demo / no sale it is abandoned && is its cancelled its rep working

            //Create Task On FollowUp - Appointment Set
            Account linkedAccount = [SELECT Name,OwnerId FROM Account WHERE Id = :wrk.Opportunity__r.AccountId];
            Task newTask = new Task(
                    ActivityDate = setDate,
                    Description = sDescription,
                    OwnerId = linkedAccount.OwnerId,
                    Subject = '(Appointment Set) Follow Up For: ' + linkedAccount.Name,
                    Task_Result__c = 'Pending',
                    WhatId = linkedAccount.Id
            );

            insert newTask;

            //Update Opp To Appointment Set
            linkedOpp.Description = sDescription;
            if(reasonOne == 'No Demo'){
                linkedOpp.StageName = 'Pending';
            }
            else if(reasonOne == 'Demo / No Sale'){
                linkedOpp.StageName = 'Rep Working';
            }

//            Opportunity newOpp = new Opportunity(
//                    AccountId = linkedAccount.Id,
//                    Opportunity_Property__c = propId,
//                    CloseDate = setDate,
//                    Name = 'placeholder',
//                    StageName = 'Confirming'
//            );
//
//            insert newOpp;

            //Create New Service Appointment cuz this one is done
            WorkOrder newWrk = new WorkOrder(
                    Opportunity__c = linkedOpp.Id,
                    AccountId = linkedAccount.Id,
                    StartDate = followUpDate,
                    OwnerId = linkedAccount.OwnerId,
                    WorkTypeId = workType
            );

            insert newWrk;

            //Update Service Appointment - Appointment Set
            serviceApp.Appointment_Result_1__c = reasonOne;
            serviceApp.Appointment_Result_2__c = reasonTwo;
            serviceApp.Appointment_Result_3__c = reasonThree;

            //Update Account - Appointment Set
            linkedAcc.Account_Disposition__c = reasonTwo + ': ' + reasonThree;
        }
        else if(reasonThree == 'Call to Set'){
            Account linkedAccount = [SELECT Name,OwnerId FROM Account WHERE Id = :wrk.Opportunity__r.AccountId];
            //Create Task On FollowUp - Call to Set
            Task newTask = new Task(
                    ActivityDate = setDate,
                    Description = sDescription,
                    OwnerId = linkedAccount.OwnerId,
                    Subject = '(Call to Set) Follow Up For: ' + linkedAccount.Name,
                    Task_Result__c = 'Pending',
                    WhatId = linkedAccount.Id
            );

            insert newTask;

            //Update Opp To Not Ready
            linkedOpp.StageName = '(Re)Setting'; //Resetting
            linkedOpp.Next_Step_Date__c = followUpDate; //Follow up date
            linkedOpp.CloseDate = followUpDate.date();
            //SET OPPORTUNITY CLOSE DATE TO setDate.... this will not have the correct date type for date. Convert to correct

            //Update Service Appointment - Not Ready
            serviceApp.Appointment_Result_1__c = reasonOne;
            serviceApp.Appointment_Result_2__c = reasonTwo;
            serviceApp.Appointment_Result_3__c = reasonThree;

            //Update Account - Not Ready
            linkedAcc.Stage__c = 'Active'; //Active
            linkedAcc.Account_Disposition__c = reasonTwo + ': ' + reasonThree;
            linkedAcc.Call_Back_Date__c = followUpDate;
        }
        //call to set vs follow up

        update serviceApp;
        update linkedOpp;
        update linkedAcc;
    }

    public static void UpdateNoDemoOrCancelled(String appointmentId, String reasonOne, String reasonTwo, String reasonThree,String sDescription,
                                               Datetime followUpDate, String ownedUserId){
        ServiceAppointment serviceApp = [SELECT ParentRecordId, Status, Appointment_Result_1__c, Appointment_Result_2__c,Appointment_Result_3__c FROM ServiceAppointment WHERE Id = :appointmentId];
        WorkOrder wrk = [SELECT Opportunity__c, Opportunity__r.Id, Opportunity__r.AccountId  FROM WorkOrder WHERE Id = :serviceApp.ParentRecordId];

        Opportunity linkedOpp = new Opportunity(Id = wrk.Opportunity__r.Id);
        Account linkedAcc = new Account(Id = wrk.Opportunity__r.AccountId);

        if(reasonTwo == 'Unreachable'){
            Account linkedAccount = [SELECT Name,OwnerId FROM Account WHERE Id = :wrk.Opportunity__r.AccountId];
            Date setDate = Date.newInstance(followUpDate.year(),followUpDate.month(),followUpDate.day());
            Task newTask = new Task(
                    ActivityDate = setDate,
                    Description = sDescription,
                    OwnerId = linkedAccount.OwnerId,
                    Subject = '(Unreachable) Follow Up For: ' + linkedAccount.Name,
                    Task_Result__c = 'Pending',
                    WhatId = linkedAccount.Id
            );

            insert newTask;

            linkedOpp.CloseDate = setDate;
            linkedOpp.Description = sDescription;
            linkedOpp.StageName = '(Re)Setting';

            serviceApp.Appointment_Result_1__c = reasonOne;
            serviceApp.Appointment_Result_2__c = reasonTwo;
            serviceApp.Appointment_Result_3__c = reasonThree;

            linkedAcc.Account_Disposition__c = reasonTwo + ': ' + reasonThree;
            linkedAcc.Call_Back_Date__c = followUpDate;

        }
        else if(reasonTwo == 'No Interest'){
            linkedOpp.Description = sDescription;
            linkedOpp.Lost_Reason__c = reasonTwo;
            linkedOpp.StageName = 'Closed Lost';
            linkedOpp.Next_Step_Date__c = null;

            serviceApp.Appointment_Result_1__c = reasonOne;
            serviceApp.Appointment_Result_2__c = reasonTwo;
            serviceApp.Appointment_Result_3__c = reasonThree;

            linkedAcc.Account_Disposition__c = reasonTwo + ': ' + reasonThree;

            linkedAcc.Stage__c = 'Nurturing';
            linkedAcc.Call_Back_Date__c = null;

        }
        else if(reasonTwo == 'Unqualified'){
            linkedOpp.Description = sDescription;
            linkedOpp.Lost_Reason__c = reasonTwo;
            linkedOpp.StageName = 'Closed Lost';
            linkedOpp.Next_Step_Date__c = null;

            serviceApp.Appointment_Result_1__c = reasonOne;
            serviceApp.Appointment_Result_2__c = reasonTwo;
            serviceApp.Appointment_Result_3__c = reasonThree;

            linkedAcc.Account_Disposition__c = reasonTwo + ': ' + reasonThree;

            linkedAcc.Stage__c = 'Lost';
            linkedAcc.Call_Back_Date__c = null;
        }

        if(reasonTwo == 'Closed / Lost'){
            serviceApp.Appointment_Result_1__c = reasonOne;
            serviceApp.Appointment_Result_2__c = reasonTwo;
            serviceApp.Appointment_Result_3__c = reasonThree;

            linkedOpp.StageName = 'Closed Lost';
            linkedOpp.Lost_Reason__c = reasonThree;
            linkedOpp.Next_Step_Date__c = null;

            linkedAcc.Account_Disposition__c = reasonTwo + ': ' + reasonThree;
            linkedAcc.Stage__c = 'Lost';
            linkedAcc.Type = 'Avoid';
            linkedAcc.Call_Back_Date__c = null;

            if(reasonThree == 'DNC'){
                linkedAcc.isDo_Not_Call__c = true;
            }
        }

        update serviceApp;
        update linkedOpp;
        update linkedAcc;
    }

    public static List<OpportunityLineItem> HandleOpportunityAmount(Opportunity o,Decimal amount){
        List<OpportunityLineItem> lineItems = [SELECT Id,UnitPrice FROM OpportunityLineItem WHERE OpportunityId = :o.Id];
        if(lineItems != null) {
            for(OpportunityLineItem lineItem : lineItems){
                lineItem.UnitPrice = amount/o.Amount*lineItem.UnitPrice;
            }
        } else {
            o.Amount = amount;
            update o;
        }
        return lineItems;
    }
}