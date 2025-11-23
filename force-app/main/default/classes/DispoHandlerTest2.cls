/**
 * Created by ben on 12/4/2024.
 */

@IsTest
private class DispoHandlerTest2 {
    public static List<String> rawDispos = new List<String>{
            'Answering Machine','No Answer','Do Not Call',
            'Unqualified : Can Not Do','Unqualified : Deceased','Unqualified : Language Barrier','Unqualified : Minor','Unqualified : New Windows','Unqualified : Out of Territory','Unqualified : Renter','Unqualified : Senior',
            'Nurturing : Budget','Nurturing : Competitor Preference','Nurturing : General No Interest','Nurturing : Moving',
            'Follow Up : Call to Set','Follow Up : Not Ready',
            'Visit Set','Appointment Set',
            'Disconnected','Wrong Number'
    };
    public static Integer recordMax = rawDispos.size();
    @TestSetup
    static void setupTestData() {
        List<Account> accounts = new List<Account>();
        List<Contact> contacts = new List<Contact>();
        List<Lead> leads = new List<Lead>();
        List<PhoneNumber__c> phoneNumbs = new List<PhoneNumber__c>();
        List<Task> tasks = new List<Task>();
        Campaign campaign = new Campaign(Name='testCamp',Type='Cold Calling',StartDate=System.today().addDays(-1),IsActive=true);
        List<CampaignMember> cMbrs = new List<CampaignMember>();

        insert campaign;
        insert new List<CampaignMemberStatus>{
                new CampaignMemberStatus(Label='Contacted',HasResponded=true,IsDefault=false,CampaignId=campaign.Id),
                new CampaignMemberStatus(Label='Uncontacted',HasResponded=false,IsDefault=false,CampaignId=campaign.Id),
                new CampaignMemberStatus(Label='Bad Contact Info',HasResponded=false,IsDefault=false,CampaignId=campaign.Id),
                new CampaignMemberStatus(Label='Never Called',HasResponded=false,IsDefault=true,CampaignId=campaign.Id)
        };
        for(Integer i=0;i<recordMax;i++){
            accounts.add(new Account(Name=i+'x0'+i,Stage__c='Nurturing'));
        }
        insert accounts;

        for(Integer i=0;i<recordMax;i++){
            String lPhVal='66666666'+('0'+i).right(2);
            String cPhVal='77777777'+('0'+i).right(2);
            if(Math.mod(i,2)==0){
                leads.add(new Lead(FirstName='l'+i,LastName=i.toString(),MobilePhone=lPhVal,Status='Open',Company='.'));
                contacts.add(new Contact(FirstName='c'+i,LastName=i.toString(),AccountId=accounts[i].Id,MobilePhone=cPhVal));
            } else {
                leads.add(new Lead(FirstName='l'+i,LastName=i.toString(),Phone=lPhVal,Status='Open',Company='.'));
                contacts.add(new Contact(FirstName='c'+i,LastName=i.toString(),AccountId=accounts[i].Id,HomePhone=cPhVal));
            }
            phoneNumbs.add(new PhoneNumber__c(Name=lPhVal));
            phoneNumbs.add(new PhoneNumber__c(Name=cPhVal));
        }
        insert phoneNumbs;
        insert contacts;
        insert leads;

        for(Integer i=0;i<recordMax;i++){
            tasks.add(new Task(WhoId=leads[i].Id,DNIS__c=phoneNumbs[2*i].Id,Five9DNIS__c=phoneNumbs[2*i].Name,CallDisposition=rawDispos[i],Status='Completed'));
            tasks.add(new Task(WhoId=contacts[i].Id,DNIS__c=phoneNumbs[(2*i)+1].Id,Five9DNIS__c=phoneNumbs[(2*i)+1].Name,CallDisposition=rawDispos[i],Status='Completed'));
            cMbrs.add(new CampaignMember(LeadId=leads[i].Id,CampaignId=campaign.Id,Mobile_Provided__c=leads[i].MobilePhone,Phone_Provided__c=leads[i].Phone,Status='Never Called'));
            cMbrs.add(new CampaignMember(ContactId=contacts[i].Id,CampaignId=campaign.Id,Mobile_Provided__c=contacts[i].MobilePhone,Phone_Provided__c=contacts[i].HomePhone,Status='Never Called'));
            System.debug('set['+i+' Lead] task('+(2*i)+')--> '+tasks[2*i]);
            System.debug('set['+i+' Contact] task('+((2*i)+1)+')--> '+tasks[(2*i)+1]);
            System.debug('set['+i+' Lead] cMbr('+(2*i)+')--> '+cMbrs[2*i]);
            System.debug('set['+i+' Contact] cMbr('+((2*i)+1)+')--> '+cMbrs[(2*i)+1]);
        }
        insert tasks;
        insert cMbrs;
        System.debug('accounts --> '+accounts);
        System.debug('contacts --> '+contacts);
        System.debug('leads --> ' +leads);
        System.debug('phoneNumbs --> '+phoneNumbs);
        System.debug('campaign --> '+campaign);
        System.debug('cMbrs --> '+cMbrs);
    }
    @IsTest
    static void testEverything() {
        Map<String,Lead> dispoLeadMapOld = new Map<String,Lead>();
        Map<String,Contact> dispoContactMapOld = new Map<String,Contact>();
        Map<String,PhoneNumber__c> lDispoPhoneNumbMapOld = new Map<String,PhoneNumber__c>();
        Map<String,PhoneNumber__c> cDispoPhoneNumbMapOld = new Map<String,PhoneNumber__c>();
        Map<String,CampaignMember> lDispoCMbrMapOld = new Map<String,CampaignMember>();
        Map<String,CampaignMember> cDispoCMbrMapOld = new Map<String,CampaignMember>();

        List<Task> tasks = [SELECT Id,WhoId,WhatId,DNIS__c,Five9DNIS__c,CallDisposition,Status FROM Task WHERE CreatedDate=TODAY];
        Map<Id,Task> five9TaskMap = new Map<Id,Task>();

        List<Lead> leads = [SELECT Id,FirstName,LastName,MobilePhone,Phone,Secondary_Contact_Mobile__c,Bad_Phone_History__c,Status,Lead_Disposition__c FROM Lead WHERE Firstname LIKE 'l%' AND CreatedDate = TODAY];
        List<Contact> contacts = [SELECT Id,FirstName,LastName,MobilePhone,HomePhone,Phone,Bad_Phone_History__c,Account_Disposition__c FROM Contact WHERE FirstName LIKE 'c%' AND CreatedDate=TODAY];
        List<PhoneNumber__c> lPhoneNumbs = [SELECT Id,Name,Total_Calls__c,Do_Not_Call__c,Disconnected__c FROM PhoneNumber__c WHERE Name LIKE '66666666%' AND CreatedDate=TODAY];
        List<PhoneNumber__c> cPhoneNumbs = [SELECT Id,Name,Total_Calls__c,Do_Not_Call__c,Disconnected__c FROM PhoneNumber__c WHERE Name LIKE '77777777%' AND CreatedDate=TODAY];
        Campaign campaign = [SELECT Id, Name, Total_Disconnects__c,Total_Wrong_Numbers__c,Total_Unqualified__c,Total_Recycling__c,Total_Follow_Up__c,Total_DNCs__c,Total_Calls__c,Total_Appointments__c FROM Campaign WHERE Name = 'testCamp' AND CreatedDate = TODAY LIMIT 1];
        List<CampaignMember> lCMbrs = [SELECT Id,LeadId,ContactId,CampaignId,Status,Mobile_Provided__c,Phone_Provided__c,Type FROM CampaignMember WHERE CampaignId=:campaign.Id AND Type = 'Lead'];
        List<CampaignMember> cCMbrs = [SELECT Id,LeadId,ContactId,CampaignId,Status,Mobile_Provided__c,Phone_Provided__c,Type FROM CampaignMember WHERE CampaignId=:campaign.Id AND Type = 'Contact'];

        for(String dispo : rawDispos){
            Integer i = rawDispos.indexOf(dispo);
            five9TaskMap.put(tasks[i*2].Id,tasks[i*2]);//lead task
            five9TaskMap.put(tasks[(i*2)+1].Id,tasks[(i*2)+1]);//contact task
            dispoLeadMapOld.put(dispo,leads[i]);
            dispoContactMapOld.put(dispo,contacts[i]);
            lDispoPhoneNumbMapOld.put(dispo,lPhoneNumbs[i]);
            cDispoPhoneNumbMapOld.put(dispo,cPhoneNumbs[i]);
            lDispoCMbrMapOld.put(dispo,lCMbrs[i]);
            cDispoCMbrMapOld.put(dispo,cCMbrs[i]);
        }
        Test.startTest();
        DispoHandler.HandleDispos(five9TaskMap);
        Test.stopTest();

        List<Lead> updatedLeads = [SELECT Id,FirstName,LastName,MobilePhone,Phone,Secondary_Contact_Mobile__c,Bad_Phone_History__c,Status,Lead_Disposition__c FROM Lead WHERE Firstname LIKE 'l%' AND CreatedDate = TODAY];
        List<Contact> updatedContacts = [SELECT Id,FirstName,LastName,MobilePhone,HomePhone,Phone,Bad_Phone_History__c,Account_Disposition__c FROM Contact WHERE FirstName LIKE 'c%' AND CreatedDate=TODAY];
        Campaign updatedCampaign = [SELECT Id, Name, Total_Disconnects__c,Total_Wrong_Numbers__c,Total_Unqualified__c,Total_Recycling__c,Total_Follow_Up__c,Total_DNCs__c,Total_Calls__c,Total_Appointments__c FROM Campaign WHERE Name = 'testCamp' AND CreatedDate = TODAY LIMIT 1];
        List<CampaignMember> updatedLcMbrs = [SELECT Id,LeadId,ContactId,CampaignId,Status,Mobile_Provided__c,Phone_Provided__c,Type FROM CampaignMember WHERE CampaignId=:campaign.Id AND Type = 'Lead' ORDER BY LeadId];
        List<CampaignMember> updatedCcMbrs = [SELECT Id,LeadId,ContactId,CampaignId,Status,Mobile_Provided__c,Phone_Provided__c,Type FROM CampaignMember WHERE CampaignId=:campaign.Id AND Type = 'Contact' ORDER BY ContactId];
        List<PhoneNumber__c> updatedLPhoneNumbs = [SELECT Id,Name,Total_Calls__c,Do_Not_Call__c,Disconnected__c FROM PhoneNumber__c WHERE Name LIKE '66666666%' AND CreatedDate=TODAY];
        List<PhoneNumber__c> updatedCPhoneNumbs = [SELECT Id,Name,Total_Calls__c,Do_Not_Call__c,Disconnected__c FROM PhoneNumber__c WHERE Name LIKE '77777777%' AND CreatedDate=TODAY];

        Map<String,Lead> dispoLeadMapNew = new Map<String,Lead>();
        Map<String,Contact> dispoContactMapNew = new Map<String,Contact>();
        Map<String,PhoneNumber__c> lDispoPhoneNumbMapNew = new Map<String,PhoneNumber__c>();
        Map<String,PhoneNumber__c> cDispoPhoneNumbMapNew = new Map<String,PhoneNumber__c>();
        Map<String,CampaignMember> lDispoCMbrMapNew = new Map<String,CampaignMember>();
        Map<String,CampaignMember> cDispoCMbrMapNew = new Map<String,CampaignMember>();

        for(String dispo : rawDispos){
            Integer i = rawDispos.indexOf(dispo);
            dispoLeadMapNew.put(dispo,updatedLeads[i]);
            dispoContactMapNew.put(dispo,updatedContacts[i]);
            lDispoPhoneNumbMapNew.put(dispo,updatedLPhoneNumbs[i]);
            cDispoPhoneNumbMapNew.put(dispo,updatedCPhoneNumbs[i]);
            lDispoCMbrMapNew.put(dispo,updatedLcMbrs[i]);
            cDispoCMbrMapNew.put(dispo,updatedCcMbrs[i]);
        }
        System.debug('>>=—-updatedCampaign—>>'+updatedCampaign);
        Integer campTotalCalls=0;
        Integer campTotalDNC=0;
        Integer campTotalUnqualified=0;
        Integer campTotalRecycling=0;
        Integer campTotalFollowUp=0;
        Integer campTotalAppointmentSet=0;
        Integer campTotalDisconnected=0;
        Integer campTotalWrongNumber=0;

        for(String dispo : rawDispos){
            System.debug('¦¦     ___-—-—=== FOR DISPO: '+dispo+' ===—-—-___'+'\r'+'————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————');
            System.debug('¦¦ lead Task——>'+rawDispos.indexOf(dispo)+'_--> '+tasks[rawDispos.indexOf(dispo)*2]);
            System.debug('¦¦ contact_Task——>'+rawDispos.indexOf(dispo)+'_--> '+tasks[(rawDispos.indexOf(dispo)*2)+1]);
            System.debug('¦¦ lead_old——> '+dispoLeadMapOld.get(dispo));
            System.debug('¦¦ lead_new——> '+dispoLeadMapNew.get(dispo));
            System.debug('¦¦ contact_old——> '+dispoContactMapOld.get(dispo));
            System.debug('¦¦ contact_new——> '+dispoContactMapNew.get(dispo));
            System.debug('¦¦ lead—>PhoneNumber_old——> '+lDispoPhoneNumbMapOld.get(dispo));
            System.debug('¦¦ lead—>PhoneNumber_new——> '+lDispoPhoneNumbMapNew.get(dispo));
            System.debug('¦¦ contact—>PhoneNumber_old——> '+cDispoPhoneNumbMapOld.get(dispo));
            System.debug('¦¦ contact—>PhoneNumber_new——> '+cDispoPhoneNumbMapNew.get(dispo));
            System.debug('¦¦ lead—>CampaignMember_old——> '+lDispoCMbrMapOld.get(dispo));
            System.debug('¦¦ lead—>CampaignMember_new——> '+lDispoCMbrMapNew.get(dispo));
            System.debug('¦¦ contact—>CampaignMember_old——> '+cDispoCMbrMapOld.get(dispo));
            System.debug('¦¦ contact—>CampaignMember_new——> '+cDispoCMbrMapNew.get(dispo));

            switch on dispo{
                when 'Answering Machine','No Answer'{
                    campTotalCalls++;campTotalCalls++;
                    System.assertEquals(null,dispoLeadMapNew.get(dispo).Lead_Disposition__c,'lead.Lead_Disposition');
                    System.assertEquals(null,dispoContactMapNew.get(dispo).Account_Disposition__c,'contact.Account_Disposition');
                    System.assertEquals('Open',dispoLeadMapNew.get(dispo).Status,'Lead Status');
                    System.assertEquals('Uncontacted',cDispoCMbrMapNew.get(dispo).Status,'lead CampaignMember.Status');
                    System.assertEquals('Uncontacted',cDispoCMbrMapNew.get(dispo).Status,'contact CampaignMember.Status');
                }
                when 'Do Not Call'{
                    campTotalCalls++;campTotalCalls++;
                    campTotalDNC++;campTotalDNC++;
                    System.assertEquals('Do Not Call',dispoLeadMapNew.get(dispo).Lead_Disposition__c,'lead.Lead_Disposition');
                    System.assertEquals('Do Not Call',dispoContactMapNew.get(dispo).Account_Disposition__c,'contact.Account_Disposition');
                    System.assertEquals('Unqualified',dispoLeadMapNew.get(dispo).Status,'Lead Status');
                    System.assertEquals(true,lDispoPhoneNumbMapNew.get(dispo).Do_Not_Call__c,'lead PhoneNumber DoNotCall');
                    System.assertEquals(true,cDispoPhoneNumbMapNew.get(dispo).Do_Not_Call__c,'contact PhoneNumber DoNotCall');
                    System.assertEquals('Contacted',cDispoCMbrMapNew.get(dispo).Status,'lead CampaignMember.Status');
                    System.assertEquals('Contacted',cDispoCMbrMapNew.get(dispo).Status,'contact CampaignMember.Status');
                }
                when 'Unqualified : Can Not Do','Unqualified : Deceased','Unqualified : Language Barrier', 'Unqualified : Minor' , 'Unqualified : New Windows', 'Unqualified : Out of Territory','Unqualified : Renter','Unqualified : Senior'{
                    campTotalCalls++;campTotalCalls++;
                    campTotalUnqualified++;campTotalUnqualified++;
                    System.assertEquals(dispo,dispoLeadMapNew.get(dispo).Lead_Disposition__c,'lead.Lead_Disposition');
                    System.assertEquals(dispo,dispoContactMapNew.get(dispo).Account_Disposition__c,'contact.Account_Disposition');
                    System.assertEquals('Unqualified',dispoLeadMapNew.get(dispo).Status,'Lead Status');
                    System.assertEquals('Contacted',cDispoCMbrMapNew.get(dispo).Status,'lead CampaignMember.Status');
                    System.assertEquals('Contacted',cDispoCMbrMapNew.get(dispo).Status,'contact CampaignMember.Status');
                }
                when 'Nurturing : Budget','Nurturing : Competitor Preference','Nurturing : General No Interest','Nurturing : Moving'{
                    campTotalCalls++;campTotalCalls++;
                    campTotalRecycling++;campTotalRecycling++;
                    System.assertEquals(dispo,dispoLeadMapNew.get(dispo).Lead_Disposition__c,'lead.Lead_Disposition');
                    System.assertEquals(dispo,dispoContactMapNew.get(dispo).Account_Disposition__c,'contact.Account_Disposition');
                    System.assertEquals('Recycling',dispoLeadMapNew.get(dispo).Status,'Lead Status');
                    System.assertEquals('Contacted',cDispoCMbrMapNew.get(dispo).Status,'lead CampaignMember.Status');
                    System.assertEquals('Contacted',cDispoCMbrMapNew.get(dispo).Status,'contact CampaignMember.Status');
                }
                when 'Follow Up : Call to Set','Follow Up : Not Ready'{
                    campTotalCalls++;campTotalCalls++;
                    campTotalFollowUp++;campTotalFollowUp++;
                    System.assertEquals(dispo,dispoLeadMapNew.get(dispo).Lead_Disposition__c,'lead.Lead_Disposition');
                    System.assertEquals(dispo,dispoContactMapNew.get(dispo).Account_Disposition__c,'contact.Account_Disposition');
                    System.assertEquals('Assigned',dispoLeadMapNew.get(dispo).Status,'Lead Status');
                    System.assertEquals('Contacted',cDispoCMbrMapNew.get(dispo).Status,'lead CampaignMember.Status');
                    System.assertEquals('Contacted',cDispoCMbrMapNew.get(dispo).Status,'contact CampaignMember.Status');
                }
                when 'Visit Set','Appointment Set'{
                    campTotalCalls++;campTotalCalls++;
                    campTotalAppointmentSet++;campTotalAppointmentSet++;
                    System.assertEquals(dispo,dispoLeadMapNew.get(dispo).Lead_Disposition__c,'lead.Lead_Disposition');
                    System.assertEquals(dispo,dispoContactMapNew.get(dispo).Account_Disposition__c,'contact.Account_Disposition');
                    System.assertEquals('Assigned',dispoLeadMapNew.get(dispo).Status,'Lead Status');
                    System.assertEquals('Contacted',cDispoCMbrMapNew.get(dispo).Status,'lead CampaignMember.Status');
                    System.assertEquals('Contacted',cDispoCMbrMapNew.get(dispo).Status,'contact CampaignMember.Status');
                }
                when 'Disconnected'{
                    campTotalCalls++;campTotalCalls++;
                    campTotalDisconnected++;campTotalDisconnected++;
                    System.assertEquals(null,dispoLeadMapNew.get(dispo).Lead_Disposition__c,'lead.Lead_Disposition');
                    System.assertEquals(null,dispoContactMapNew.get(dispo).Account_Disposition__c,'contact.Account_Disposition');
                    System.assertEquals('Open',dispoLeadMapNew.get(dispo).Status,'Lead Status');
                    System.assertEquals(true,lDispoPhoneNumbMapNew.get(dispo).Disconnected__c,'lead PhoneNumber Disconnected');
                    System.assertEquals(true,cDispoPhoneNumbMapNew.get(dispo).Disconnected__c,'contact PhoneNumber Disconnected');
                    System.assertEquals('Bad Contact Info',cDispoCMbrMapNew.get(dispo).Status,'lead CampaignMember.Status');
                    System.assertEquals('Bad Contact Info',cDispoCMbrMapNew.get(dispo).Status,'contact CampaignMember.Status');
                }
                when 'Wrong Number'{
                    campTotalCalls++;campTotalCalls++;
                    campTotalWrongNumber++;campTotalWrongNumber++;
                    System.assertEquals(dispo,dispoLeadMapNew.get(dispo).Lead_Disposition__c,'lead.Lead_Disposition');
                    System.assertEquals(dispo,dispoContactMapNew.get(dispo).Account_Disposition__c,'contact.Account_Disposition');
                    System.assertEquals('Unqualified',dispoLeadMapNew.get(dispo).Status,'Lead Status');
                    System.assertEquals('Bad Contact Info',cDispoCMbrMapNew.get(dispo).Status,'lead CampaignMember.Status');
                    System.assertEquals('Bad Contact Info',cDispoCMbrMapNew.get(dispo).Status,'contact CampaignMember.Status');
                    if(dispoLeadMapOld.get(dispo).MobilePhone==lDispoPhoneNumbMapNew.get(dispo).Name){
                        System.assertEquals(null,dispoLeadMapNew.get(dispo).MobilePhone,'Lead Mobile set to blank on wrong number');

                        System.assertEquals(('Wrong Number : '+dispoLeadMapOld.get(dispo).MobilePhone+' -- '+System.Datetime.now()).left(43),dispoLeadMapNew.get(dispo).Bad_Phone_History__c.left(43),'Lead BadPhoneHistory(Mobile)populated on wrong number');
                        System.assertEquals(null,dispoContactMapNew.get(dispo).MobilePhone,'Contact Mobile set to blank on wrong number');
                        System.assertEquals(('Wrong Number : '+dispoContactMapOld.get(dispo).MobilePhone+' -- '+System.Datetime.now()).left(43),dispoContactMapNew.get(dispo).Bad_Phone_History__c.left(43),'Contact BadPhoneHistory(Mobile)populated on wrong number');
                    }else if(dispoLeadMapOld.get(dispo).Phone==lDispoPhoneNumbMapNew.get(dispo).Name){
                        System.assertEquals(null,dispoLeadMapNew.get(dispo).Phone,'Lead Phone set to blank on wrong number');
                        System.assertEquals(('Wrong Number : '+dispoLeadMapOld.get(dispo).Phone+' -- '+System.Datetime.now()).left(43),dispoLeadMapNew.get(dispo).Bad_Phone_History__c.left(43),'Lead BadPhoneHistory(Phone)populated on wrong number');
                        System.assertEquals(null,dispoContactMapNew.get(dispo).HomePhone,'Contact HomePhone set to blank on wrong number');
                        System.assertEquals(('Wrong Number : '+dispoContactMapOld.get(dispo).HomePhone+' -- '+System.Datetime.now()).left(43),dispoContactMapNew.get(dispo).Bad_Phone_History__c.left(43),'Contact BadPhoneHistory(HomePhone)populated on wrong number');
                    }
                }
            }
            System.assertEquals(1,lDispoPhoneNumbMapNew.get(dispo).Total_Calls__c,'lead PhoneNumber TotalCalls');
            System.assertEquals(1,cDispoPhoneNumbMapNew.get(dispo).Total_Calls__c,'contact PhoneNumber TotalCalls');
            System.debug('//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////'+'\r');
        }
        System.assertEquals(campTotalCalls,updatedCampaign.Total_Calls__c,'campTotalCalls');
        System.assertEquals(campTotalDNC,updatedCampaign.Total_DNCs__c,'campTotalDNC');
        System.assertEquals(campTotalUnqualified,updatedCampaign.Total_Unqualified__c,'campTotalUnqualified');
        System.assertEquals(campTotalRecycling,updatedCampaign.Total_Recycling__c,'campTotalRecycling');
        System.assertEquals(campTotalFollowUp,updatedCampaign.Total_Follow_Up__c,'campTotalFollowUp');
        System.assertEquals(campTotalAppointmentSet,updatedCampaign.Total_Appointments__c,'campTotalAppointmentSet');
        System.assertEquals(campTotalDisconnected,updatedCampaign.Total_Disconnects__c,'campTotalDisconnected');
        System.assertEquals(campTotalWrongNumber,updatedCampaign.Total_Wrong_Numbers__c,'campTotalWrongNumber');
    }
    @IsTest
    static void testNormalizeDispos() {
        List<Task> tasks = [SELECT Id,Five9DNIS__c,CallDisposition,WhoId FROM Task WHERE CreatedDate = TODAY LIMIT 5];
        tasks[0].CallDisposition='DNC';
        tasks[1].CallDisposition='No-Answer';
        tasks[2].CallDisposition='Answering-Machine';
        tasks[3].CallDisposition='Fax';
        for(Task t : tasks) {
            DispoHandler.NormalizeDispos(t);
            switch on t.CallDisposition {
                when 'No-Answer'{
                    System.assertEquals('No Answer', t.CallDisposition);
                }
                when 'Answering-Machine'{
                    System.assertEquals('Answering Machine', t.CallDisposition);
                }
                when 'DNC'{
                    System.assertEquals('Do Not Call', t.CallDisposition);
                }
                when 'Fax'{
                    System.assertEquals('Disconnected Number', t.CallDisposition);
                }
            }
        }
    }
}