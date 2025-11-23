/**
 * Created by Ben on 8/1/2024.
 */

@IsTest
private class DispoHandlerTest {
    static final Integer recordMax = 15;
    @TestSetup
    static void setupDispoHandlerTest(){




        List<Lead> testLeads = new List<Lead>();
        List<String> phNumbVals = new List<String>();
        List<CampaignMember> cmpMmbrs = new List<CampaignMember>();
        List<Task> testTasks = new List<Task>();
        List<PhoneNumber__c> testPhones = new List<PhoneNumber__c>();
        for(Integer i = 0; i<recordMax; i++){
            Long testDnisNum = Long.valueOf('9991234567');
            String testDnis = (testDnisNum-(i*3)).toString();

            String ldPhoneTaskDNIS;
            String ldMobileTaskDNIS;
            String phName;
            if(Math.mod((i + 2), 2) == 0) {
                ldMobileTaskDNIS = testDnis;
                ldPhoneTaskDNIS = '';
                Lead l = new Lead(FirstName = 'ld'+i, LastName = i.toString(), Company = i.toString()+' Test'+i.toString(),
                        MobilePhone = ldMobileTaskDNIS, Phone = ldPhoneTaskDNIS, Status = 'Open');
                testLeads.add(l);
            } else if (Math.mod((i + 2), 2) == 1) {
                ldPhoneTaskDNIS = testDnis;
                ldMobileTaskDNIS = '';
                Lead l2 = new Lead(FirstName = 'ld'+i, LastName = i.toString(), Company = i.toString()+' Test'+i.toString(),
                        MobilePhone = ldMobileTaskDNIS, Phone = ldPhoneTaskDNIS, Status = 'Open');
                testLeads.add(l2);
            }

            PhoneNumber__c ph = new PhoneNumber__c(Name=phName,Total_Calls__c=0,Disconnected__c=false,Do_Not_Call__c=false);
            testPhones.add(ph);
            phNumbVals.add(testDnis);
        }
        Campaign testCampaign = new Campaign(Name = 'testCampaign',Type = 'Cold Calling',StartDate = System.today(), IsActive = true);
        insert testCampaign;
        insert testLeads;
        System.debug(testLeads);

        insert testPhones;

        List<String> rawDispos = new List<String>{ //i counted 20, so lets make 10 leads and 10 contacts, 20 tasks
                'Disconnected','Fax','Wrong Number',
                'Follow Up : Call to Set', 'Follow Up : Not Ready',
                'Visit Set', 'Appointment Set',
                'Unqualified : Can Not Do','Unqualified : Deceased','Unqualified : Language Barrier', 'Unqualified : Minor' , 'Unqualified : New Windows', 'Unqualified : Out of Territory','Unqualified : Renter','Unqualified : Senior',
                'Nurturing : Budget','Nurturing : Competitor Preference', 'Nurturing : General No Interest','Nurturing : Moving',
                'Do Not Call','DNC',
                'No-Answer', 'Answering-Machine','No Answer', 'Answering Machine'
        };


        for(Integer i = 0; i < recordMax; i++) {
            PhoneNumber__c phNum;
            if(testLeads[i].Phone == '' && testLeads[i].MobilePhone != ''){
                phNum = [SELECT Id, Name FROM PhoneNumber__c WHERE Name = :testLeads[i].MobilePhone LIMIT 1];
            } else {phNum = [SELECT Id, Name FROM PhoneNumber__c WHERE Name = :testLeads[i].Phone LIMIT 1];
              }

            PhoneNumber__c phoneNumber = [SELECT Id, Name FROM PhoneNumber__c WHERE Name = :testLeads[i].MobilePhone OR Name = :testLeads[i].Phone];
            Id ldDNIS = phoneNumber.Id;
            String ldTaskDNIS = phoneNumber.Name;
            testTasks.add(new Task(WhoId = testLeads[i].Id, Five9DNIS__c = ldTaskDNIS, CallDisposition = rawDispos[i], DNIS__c = ldDNIS));
            cmpMmbrs.add(new CampaignMember(LeadId = testLeads[i].Id, CampaignId = testCampaign.Id,
                    Mobile_Provided__c = testLeads[i].MobilePhone, Phone_Provided__c = testLeads[i].Phone));
        }
        insert testTasks;
        insert cmpMmbrs;
        System.debug(cmpMmbrs);
        // Create Campaign records for Unit
        Campaign campaign1 = new Campaign(Name = 'unitTestCamp 1',Type = 'Cold Calling',StartDate = System.today().addDays(-1), IsActive = true);
        Campaign campaign2 = new Campaign(Name = 'unitTestCamp 2',Type = 'Cold Calling',StartDate = System.today().addDays(-1), IsActive = true);
        insert new List<Campaign>{campaign1, campaign2};

        // Create CampaignMember records for Unit
        CampaignMember cm1 = new CampaignMember(CampaignId = campaign1.Id, Mobile_Provided__c = testLeads[1].MobilePhone, Phone_Provided__c = testLeads[1].Phone,Status = 'Uncontacted', LeadId = testLeads[1].Id);
        CampaignMember cm2 = new CampaignMember(CampaignId = campaign1.Id, Mobile_Provided__c = testLeads[2].MobilePhone, Phone_Provided__c = testLeads[2].Phone,Status = 'Uncontacted',LeadId = testLeads[2].Id);
        CampaignMember cm3 = new CampaignMember(CampaignId = campaign2.Id, Mobile_Provided__c = testLeads[3].MobilePhone, Phone_Provided__c = testLeads[3].Phone,Status = 'Uncontacted',LeadId = testLeads[3].Id);
        insert new List<CampaignMember>{cm1, cm2, cm3};

    }
    @IsTest
    static void testProcessCampaignMemberMap() {
        Campaign campaign1 = [SELECT Id, Name, Total_Calls__c,Total_Unqualified__c,Total_Recycling__c,Total_Disconnects__c,Total_DNCs__c,Total_Follow_Up__c,Total_Appointments__c,Total_Wrong_Numbers__c FROM Campaign WHERE Name = 'unitTestCamp 1'];
        Campaign campaign2 = [SELECT Id, Name, Total_Calls__c,Total_Unqualified__c,Total_Recycling__c,Total_Disconnects__c,Total_DNCs__c,Total_Follow_Up__c,Total_Appointments__c,Total_Wrong_Numbers__c FROM Campaign WHERE Name = 'unitTestCamp 2'];
        System.debug(campaign1);
        System.debug(campaign2);
        CampaignMember cm1 = [SELECT Id, Mobile_Provided__c, Phone_Provided__c,Phone, MobilePhone, CampaignId FROM CampaignMember WHERE CampaignId = :campaign1.Id AND Name LIKE 'ld1%' LIMIT 1];
        CampaignMember cm2 = [SELECT Id, Mobile_Provided__c, Phone_Provided__c,Phone, MobilePhone,CampaignId FROM CampaignMember WHERE CampaignId = :campaign1.Id AND Name LIKE 'ld2%' LIMIT 1];
        CampaignMember cm3 = [SELECT Id, Mobile_Provided__c, Phone_Provided__c,Phone, MobilePhone,CampaignId FROM CampaignMember WHERE CampaignId = :campaign2.Id AND Name LIKE 'ld3%' LIMIT 1];
        // Populate static maps
        DispoHandler.CampaignMemberMap = new Map<Id, CampaignMember>{
                cm1.Id => cm1,
                cm2.Id => cm2,
                cm3.Id => cm3
        };
        DispoHandler.CampaignMap = new Map<Id, Campaign>{
                campaign1.Id => campaign1,
                campaign2.Id => campaign2
        };
        // Define the static sets with phone values
        DispoHandler.UnqualifiedPhoneValues = new Set<String>{cm1.Mobile_Provided__c};
        DispoHandler.NurturingPhoneValues = new Set<String>{cm1.Phone_Provided__c};
        DispoHandler.DisconnectedPhoneValues = new Set<String>{cm2.Mobile_Provided__c};
        DispoHandler.DoNotCallPhoneValues = new Set<String>{cm2.Phone_Provided__c};
        DispoHandler.FollowUpPhoneValues = new Set<String>{cm3.Mobile_Provided__c};
        DispoHandler.AppointmentSetPhoneValues = new Set<String>{cm3.Phone_Provided__c};
        DispoHandler.WrongNumberPhoneValues = new Set<String>{'2151591591'};

        // Call the method
        DispoHandler.ProcessCampaignMemberMap();

        // Query updated Campaign records
        List<Campaign> updatedCs = [SELECT Id, Name, Total_Appointments__c,Total_Calls__c,Total_Disconnects__c,Total_DNCs__c,Total_Follow_Up__c,Total_Recycling__c,Total_Unqualified__c,Total_Wrong_Numbers__c FROM Campaign WHERE Name = 'unitTestCamp 1' OR Name = 'unitTestCamp 2' ORDER BY Name];
        System.debug(updatedCs);
        // Query updated CampaignMember records
        CampaignMember updatedCM1 = [SELECT Status,MobilePhone,Mobile_Provided__c,Phone,Phone_Provided__c FROM CampaignMember WHERE Id = :cm1.Id];
        CampaignMember updatedCM2 = [SELECT Status,MobilePhone,Mobile_Provided__c,Phone,Phone_Provided__c FROM CampaignMember WHERE Id = :cm2.Id];
        CampaignMember updatedCM3 = [SELECT Status,MobilePhone,Mobile_Provided__c,Phone,Phone_Provided__c FROM CampaignMember WHERE Id = :cm3.Id];

        // Assert results
        System.assertEquals('Sent', updatedCM1.Status);
        System.assertEquals('Sent', updatedCM2.Status);
        System.assertEquals('Sent', updatedCM3.Status);
    }

    @IsTest
    static void testHandleDispos() {

        List<Lead> leads = [SELECT Id, FirstName, LastName, Status, Lead_Disposition__c, Company, MobilePhone, Phone FROM Lead WHERE FirstName LIKE 'ld%'];

        List<String> normalizedDispos = new List<String>{
                'Disconnected Number','Wrong Number', //-1
                'Follow Up : Call to Set', 'Follow Up : Not Ready', //-1
                'Appointment Set', //-1
                'Unqualified : Can Not Do','Unqualified : Deceased','Unqualified : Language Barrier', 'Unqualified : Minor' , 'Unqualified : New Windows', 'Unqualified : Out of Territory','Unqualified : Renter','Unqualified : Senior',
                'Nurturing : Budget','Nurturing : Competitor Preference', 'Nurturing : General No Interest','Nurturing : Moving',
                'Do Not Call', //-1
                'No Answer', 'Answering Machine' //-1

        };
        List<Task> tasks = [SELECT Id, WhoId, Five9DNIS__c, CallDisposition, DNIS__c FROM Task WHERE WhoId IN :leads];

        Map<Id,Task> taskMap = new Map<Id,Task>();
        for(Task t : tasks){
            taskMap.put(t.Id,t);
        }
        List<String> dnisList = new List<String>();
        for (Task t : tasks){
            dnisList.add(t.Five9DNIS__c);
        }

        Integer dcCount = 0;
        Integer dncCount = 0;
        Integer unqCount = 0;
        Integer nurtCount = 0;
        Integer flwUpCount = 0;
        Integer apptSetCount = 0;
        Integer wrNumbCount = 0;
        Integer callCount = 0;
        Integer i = 0;
        System.debug(tasks);
            for (Task t: tasks){
                if(t.CallDisposition.contains('Unqualified')){
                    unqCount++;
                    i++;
                    callCount++;
                }
                else if(t.CallDisposition.contains('Do Not Call')){
                    dncCount++;
                    i++;
                    callCount++;
                }
                else if(t.CallDisposition.contains('Follow')){ //this is NO ANSWER;
                    flwUpCount++;
                    i++;
                    callCount++;
                }
                else if(t.CallDisposition.contains('Nurturing')){
                    nurtCount++;
                    i++;
                    callCount++;
                }
                else if(t.CallDisposition.contains('Wrong')) {
                    wrNumbCount++;
                    i++;
                    callCount++;
                }
                else if(t.CallDisposition.contains('Appointment Set') || t.CallDisposition.contains('Visit Set')) { //visit or appointment set
                    apptSetCount++;
                    i++;
                    callCount++;
                }
                else if(t.CallDisposition.contains('Disconnected')){
                    dcCount++;
                    i++;
                    callCount++;

                }
                else{i++;callCount++;}
            }
        Test.startTest();
        DispoHandler.HandleDispos(taskMap);
        Test.stopTest();
        Campaign updatedcmp = [SELECT Id, Name, Type, NumberOfContacts, NumberOfLeads, NumberOfResponses,
                Total_Appointments__c,Total_Calls__c,Total_Disconnects__c,Total_DNCs__c,
                Total_Follow_Up__c, Total_Recycling__c, Total_Unqualified__c, Total_Wrong_Numbers__c
        FROM Campaign WHERE Name = 'testCampaign' LIMIT 1];
        System.debug(updatedcmp);
        System.debug('DcCount:::'+dcCount+', recycle/nurtCount:::'+nurtCount+', apptCount:::'+apptSetCount+', callCount:::'+callCount+', flwUpCount:::'+flwUpCount+', unqCount:::'+unqCount+', wrgNumbCount:::'+wrNumbCount+', dncCount:::'+dncCount);
        System.assertEquals(dcCount, updatedcmp.Total_Disconnects__c,'Total Disconnects should be: '+updatedcmp.Total_Disconnects__c);
        System.assertEquals(dncCount, updatedcmp.Total_DNCs__c,'Total Dnc should be: '+updatedcmp.Total_Disconnects__c);
        System.assertEquals(unqCount, updatedcmp.Total_Unqualified__c,'Total Unqualified should be: '+updatedcmp.Total_Unqualified__c);
        System.assertEquals(nurtCount, updatedcmp.Total_Recycling__c,'Total Recycling should be: '+updatedcmp.Total_Recycling__c);
        System.assertEquals(flwUpCount, updatedcmp.Total_Follow_Up__c,'Total Follow Up should be: '+updatedcmp.Total_Follow_Up__c);
        System.assertEquals(wrNumbCount, updatedcmp.Total_Wrong_Numbers__c,'Total Recycling should be: '+updatedcmp.Total_Wrong_Numbers__c);
        System.assertEquals(apptSetCount, updatedcmp.Total_Appointments__c,'Total Appointments should be: '+updatedcmp.Total_Appointments__c);
        System.assertEquals(callCount, updatedcmp.Total_Calls__c,'Total Calls should be: '+updatedcmp.Total_Calls__c);

    }
    @IsTest
    static void testMakeValues(){
        List<Task> tasks = [SELECT Id, WhoId, Five9DNIS__c, CallDisposition, DNIS__c FROM Task];
        Test.startTest();
        DispoHandler.MakeValues(tasks);
        Test.stopTest();


    }
        @IsTest
        static void testNormalizeDispos() {
            // if contains '-'
            Lead lead1 = new Lead(FirstName = 'uLd1', LastName = '1nrml', Company = 'uLd1, 1nrml', Status = 'Open');
            Task task1 = new Task(CallDisposition = 'Answering-Machine', WhoId = lead1.Id);
            DispoHandler.NormalizeDispos(task1);
            System.assertEquals('Answering Machine', task1.CallDisposition);

            // if 'DNC'
            Lead lead2 = new Lead(FirstName = 'uLd2', LastName = '2nrml', Company = 'uLd2, 2nrml', Status = 'Open');
            Task task2 = new Task(CallDisposition = 'DNC', WhoId = lead2.Id);
            DispoHandler.NormalizeDispos(task2);
            System.assertEquals('Do Not Call', task2.CallDisposition);

            // if 'Fax'
            Lead lead3 = new Lead(FirstName = 'uLd3', LastName = '3nrml', Company = 'uLd3, 3nrml', Status = 'Open');
            Task task3 = new Task(CallDisposition = 'Fax',WhoId = lead3.Id);
            DispoHandler.NormalizeDispos(task3);
            System.assertEquals('Disconnected Number', task3.CallDisposition);

            // if else
            Lead lead4 = new Lead(FirstName = 'uLd4', LastName = '4nrml', Company = 'uLd4, 4nrml',Status = 'Open');
            Task task4 = new Task(CallDisposition = 'Completed',WhoId = lead4.Id);
            DispoHandler.NormalizeDispos(task4);
            System.assertEquals('Completed', task4.CallDisposition);
        }

    @IsTest
    static void testProcessLead() {
        List<Lead> leads = [SELECT Id, Lead_Disposition__c,Status,MobilePhone,Phone,Secondary_Contact_Mobile__c,Bad_Phone_History__c FROM Lead WHERE FirstName LIKE 'ld%'];
        for(Lead l : leads){
            Task t = [SELECT Id, WhoId,CallDisposition,Five9DNIS__c FROM Task WHERE WhoId = :l.Id ORDER BY CreatedDate DESC LIMIT 1];
            DispoHandler.ProcessLead(l, t);

            if(t.CallDisposition.contains('Unqualified') && (t.CallDisposition=='DNC' || t.CallDisposition=='Do Not Call')){
                System.assertEquals('Unqualified', l.Status);
                System.assertEquals('Do Not Call', l.Lead_Disposition__c);
            }
            else if(t.CallDisposition.contains('Unqualified')){
                System.assertEquals('Unqualified', l.Status);
            }
            else if(t.CallDisposition.contains('Nurturing')){
                System.assertEquals(l.Lead_Disposition__c,t.CallDisposition);
                System.assertEquals('Recycling',l.Status);
            }
            else if(t.CallDisposition.contains('Follow')){
                System.assertEquals(l.Lead_Disposition__c, t.CallDisposition);
                System.assertEquals('Assigned', l.Status);
            }
            else if(t.CallDisposition.contains('Appointment') | t.CallDisposition.contains('Visit')){
                System.assertEquals(l.Lead_Disposition__c, t.CallDisposition);
            }
            else if(t.CallDisposition.contains('Do Not Call')){
                System.assertEquals('Unqualified', l.Status);
                }
            else if(t.CallDisposition=='Wrong Number'){
                System.assertEquals('Wrong Number',l.Lead_Disposition__c,'newDispo:::'+l.Lead_Disposition__c + 'calDispo:::'+ t.CallDisposition);
            }
            else if(t.CallDisposition != '' || t.CallDisposition != null){
                System.assertEquals(null,l.Lead_Disposition__c,'newDispo:::'+l.Lead_Disposition__c + 'calDispo:::'+ t.CallDisposition);
            }
            else {System.assertEquals(t.CallDisposition,l.Lead_Disposition__c);}
        }
    }
    @IsTest
    static void testProcessPhoneMap(){
        List<Lead> leads = [SELECT Id, FirstName, LastName, Status, Lead_Disposition__c, Company, MobilePhone, Phone FROM Lead WHERE FirstName LIKE 'ld%'];
        List<Task> tasks = [SELECT Id, Five9DNIS__c, CallDisposition, DNIS__c, WhoId FROM Task WHERE WhoId IN :leads];
        List<PhoneNumber__c> phonenumbers = [SELECT Id, Name, Disconnected__c, Do_Not_Call__c,Total_Calls__c FROM PhoneNumber__c WHERE CreatedDate = TODAY];
        List<String> phVals = new List<String>();
        Map<Id,PhoneNumber__c> testPhoneMap= new Map<Id,PhoneNumber__c>();
        Map<Id,Task> testPhoneFive9Tasks = new Map<Id,Task>();
        Map<Id, Task> PhoneIdToTaskMap = new Map<Id, Task>();
        for(Integer i = 0; i < recordMax; i++) { //can do leads and contacts same here cause they're made on same iterating integer crap & this is just for SOQL
            if (leads[i].MobilePhone != '') {
                phVals.add(leads[i].MobilePhone); //phVals.add(contacts[i].MobilePhone);
            } //phone1
            else if (leads[i].Phone != '') {
                phVals.add(leads[i].Phone);
            } //phone2
            testPhoneMap.put(phonenumbers[i].Id,phonenumbers[i]);
            testPhoneFive9Tasks.put(tasks[i].Id,tasks[i]);
            PhoneIdToTaskMap.put(tasks[i].DNIS__c,tasks[i]);
        }

        DispoHandler.HandleDispos(testPhoneFive9Tasks);

        List<PhoneNumber__c> updatedPhonenumbers = [SELECT Id, Name, Disconnected__c, Do_Not_Call__c,Total_Calls__c FROM PhoneNumber__c WHERE CreatedDate = TODAY];
        for(Integer i = 0; i < leads.size(); i++){
            Task t = PhoneIdToTaskMap.get(updatedPhonenumbers[i].Id);
            if(t.CallDisposition == 'Do Not Call'){
                System.assertEquals(true,updatedPhonenumbers[i].Do_Not_Call__c, 'needs to be do not call');
                System.assertEquals(1, updatedPhonenumbers[i].Total_Calls__c);
            }
            else if(t.CallDisposition == 'Disconnected Number'){
                System.assertEquals(true, updatedPhonenumbers[i].Disconnected__c);
                System.debug(updatedPhonenumbers[i]);
                System.assertEquals(1, updatedPhonenumbers[i].Total_Calls__c);
            }
            else{
                System.debug(updatedPhonenumbers[i]);
                System.assertEquals(1, updatedPhonenumbers[i].Total_Calls__c);
                //System.assertEquals(0, updatedPhonenumbers[i].Total_Calls__c, 'heres the real total Calls' + updatedPhonenumbers[i].Total_Calls__c);
            }


        }
        testPhoneMap.clear();
        testPhoneFive9Tasks.clear();
        PhoneIdToTaskMap.clear();
        PhoneNumber__c p = new PhoneNumber__c(Name = '1001001000', Total_Calls__c = null);
        insert p;
        Task t2 = new Task(Five9DNIS__c = '1001001000',CallDisposition = 'Answering Machine', WhatId = p.Id, DNIS__c = p.Id);
        testPhoneMap.put(p.Id,p);
        testPhoneFive9Tasks.put(t2.Id,t2);
        PhoneIdToTaskMap.put(t2.DNIS__c,t2);
        DispoHandler.HandleDispos(testPhoneFive9Tasks);
        PhoneNumber__c updatedPhoneForNull = [SELECT Id, Name, Disconnected__c, Do_Not_Call__c, Total_Calls__c FROM PhoneNumber__c WHERE Id = :p.Id];
        System.assertEquals(1, updatedPhoneForNull.Total_Calls__c);


//        for(PhoneNumber__c pn : PhoneMap.values()){
//
//            Task t = TaskMapByDNIS.get(pn.Name);
//            if(pn.Total_Calls__c != null){
//                pn.Total_Calls__c ++;
//            } else { pn.Total_Calls__c = 1;}
//            if(DoNotCallPhoneValues.contains(pn.Name)){
//                pn.Do_Not_Call__c = true;
//            }
//            else if(DisconnectedPhoneValues.contains(pn.Name)){
//                pn.Disconnected__c = true;
//            }
//        }
    }
}