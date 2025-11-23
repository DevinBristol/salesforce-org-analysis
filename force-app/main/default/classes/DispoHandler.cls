/**
 * Created by Devin on 7/24/2024.
 */
// TODO Fix Five9API
// TODO Is Task Who Id being updated on wrong association??

public with sharing class DispoHandler {

    public static void HandleDispos(Map<Id,Task> Five9TaskMap){
        MakeValues(Five9TaskMap.values());
        MakeMaps();
        ProcessMaps();
        UpdateMaps();

        System.debug('DispoHandler.HandleDispos LeadMap::: '+LeadMap);
        System.debug('DispoHandler.HandleDispos PhoneMap::: '+PhoneMap);
        System.debug('DispoHandler.HandleDispos ContactMap::: '+ContactMap);
        System.debug('DispoHandler.HandleDispos AccountMap::: '+AccountMap);
        System.debug('DispoHandler.HandleDispos CampaignMemberMap::: '+CampaignMemberMap);
        System.debug('DispoHandler.HandleDispos CampaignMap::: '+CampaignMap);
    }
    public static void MakeValues(List<Task> tasks){
        InitializeProperties();
        AssignProperties(tasks);
        System.debug('DispoHandler.MakeValues WhoIds::: '+WhoIds);
        System.debug('DispoHandler.MakeValues PhoneValues::: '+PhoneValues);
    }
    public static void InitializeProperties(){
        WhoIds = new Set<Id>();
        PhoneValues = new Set<String>();
        TaskMapByWhoId = new Map<Id,Task>();
        TaskMapByDNIS = new Map<String,Task>();
        AccountMap = new Map<Id,Account>();
        DisconnectedPhoneValues = new Set<String>();
        DoNotCallPhoneValues = new Set<String>();
        FollowUpPhoneValues = new Set<String>();
        UnqualifiedPhoneValues = new Set<String>();
        WrongNumberPhoneValues = new Set<String>();
        AppointmentSetPhoneValues = new Set<String>();
        NurturingPhoneValues = new Set<String>();
    }
    public static void AssignProperties(List<Task> tasks){
        for(Task t : tasks){
            SortPhoneValuesByDisposition(t.Five9DNIS__c,t.CallDisposition);
            PhoneValues.add(t.Five9DNIS__c);
            WhoIds.add(t.WhoId);
            TaskMapByWhoId.put(t.WhoId,t);
            TaskMapByDNIS.put(t.Five9DNIS__c,t);
        }
    }
    public static void NormalizeDispos(Task t){
        if(t.CallDisposition != null){
            t.CallDisposition = t.CallDisposition.replace('-',' ');
            if(t.CallDisposition == 'DNC'){
                t.CallDisposition = 'Do Not Call';
            } else if(t.CallDisposition == 'Fax'){
                t.CallDisposition = 'Disconnected Number';
            }
        }
    }

    public static void SortPhoneValuesByDisposition(String PhoneValue, String Disposition){
        if(Disposition != null){
            if(Disposition.contains('Unqualified')){
                UnqualifiedPhoneValues.add(PhoneValue);
            } else if(Disposition.contains('Do Not Call')){
                DoNotCallPhoneValues.add(PhoneValue);
            } else if(Disposition.contains('Follow')){
                FollowUpPhoneValues.add(PhoneValue);
            } else if (Disposition.contains('Nurturing')){
                NurturingPhoneValues.add(PhoneValue);
            } else if (Disposition.contains('Wrong')){
                WrongNumberPhoneValues.add(PhoneValue);
            } else if (Disposition.contains('Appointment Set') || Disposition.contains('Visit Set')){
                AppointmentSetPhoneValues.add(PhoneValue);
            } else if (Disposition.contains('Disconnected')){
                DisconnectedPhoneValues.add(PhoneValue);
            }
        }
    }

    //Make Maps
    public static void MakeMaps(){
        MakeLeadMap();
        MakeContactMap();
        MakePhoneNumberMaps();
        MakeCampaignMemberMap();
        MakeCampaignMap();

        System.debug(LeadMap);
        System.debug(ContactMap);
        System.debug(PhoneMapByName);
        System.debug(CampaignMemberMap);
        System.debug(CampaignMap);
    }
    public static void MakeLeadMap(){
        LeadMap = getLeadRecords();
    }
    public static void MakeContactMap(){
        ContactMap = getContactRecords();
    }
    public static void MakePhoneNumberMaps(){
        PhoneMapByName = new Map<String,PhoneNumber__c>();
        PhoneMap = getPhoneRecords();
        for(PhoneNumber__c pn : PhoneMap.values()){
            PhoneMapByName.put(pn.Name,pn);
        }
    }
    public static void MakeCampaignMemberMap(){
        CampaignMemberMap = getCampaignMemberRecords();
    }
    public static void MakeCampaignMap(){
        setCampaignIds();
        CampaignMap = getCampaignRecords();
    }
    public static void setCampaignIds(){
        CampaignIds = new Set<Id>();
        for(CampaignMember cm : CampaignMemberMap.values()){
            CampaignIds.add(cm.CampaignId);
        }
    }

    //SOQL
    private static Map<Id,Lead> getLeadRecords(){
        Map<Id,Lead> returnLeads = new Map<Id,Lead>([SELECT Id, FirstName, MobilePhone, Phone, Secondary_Contact_Mobile__c,Bad_Phone_History__c, Status FROM Lead WHERE Id IN :WhoIds]);
        return returnLeads;
    }
    private static Map<Id,Contact> getContactRecords(){
        Map<Id,Contact> returnContacts = new Map<Id,Contact>([SELECT Id, AccountId,FirstName,MobilePhone,Phone, HomePhone,Bad_Phone_History__c FROM Contact WHERE Id IN :WhoIds]);
        return returnContacts;
    }
    private static Map<Id,PhoneNumber__c> getPhoneRecords(){
        Map<Id,PhoneNumber__c> returnPhoneRecords = new Map<Id,PhoneNumber__c>([SELECT Id,Name,Total_Calls__c FROM PhoneNumber__c WHERE Name IN :PhoneValues]);
        return returnPhoneRecords;
    }
    private static Map<Id,CampaignMember> getCampaignMemberRecords(){
        Map<Id,CampaignMember> returnCampaignMemberRecords = new Map<Id,CampaignMember>([SELECT Id,Campaign.Id,Mobile_Provided__c,Phone_Provided__c, MobilePhone, Phone, Status FROM CampaignMember WHERE Mobile_Provided__c IN :PhoneValues OR Phone_Provided__c IN :PhoneValues]);
        return returnCampaignMemberRecords;
    }
    private static Map<Id,Campaign> getCampaignRecords(){
        Map<Id,Campaign> returnCampaigns = new Map<Id,Campaign>([SELECT Id, Total_Disconnects__c,Total_Recycling__c,Total_Appointments__c,Total_Calls__c,Total_Follow_Up__c, Total_Unqualified__c,Total_Wrong_Numbers__c, Total_DNCs__c FROM Campaign WHERE Id IN :CampaignIds]);
        return returnCampaigns;
    }

    //Map Processors
    public static void ProcessMaps(){
        ProcessPhoneMap();
        ProcessCampaignMemberMap();
        ProcessLeadMap();
        ProcessContactMap();
    }
    public static void ProcessPhoneMap(){
        for(PhoneNumber__c pn : PhoneMap.values()){
            Task t = TaskMapByDNIS.get(pn.Name);
            if(pn.Total_Calls__c != null){
                pn.Total_Calls__c ++;
            } else { pn.Total_Calls__c = 1;}
            if(DoNotCallPhoneValues.contains(pn.Name)){
                pn.Do_Not_Call__c = true;
            } else if(DisconnectedPhoneValues.contains(pn.Name)){
                pn.Disconnected__c = true;
            }
        }
    }
    public static void ProcessCampaignMemberMap(){
        if(CampaignMemberMap.isEmpty()){
           return;
        } else{
            for(CampaignMember cm : CampaignMemberMap.values()){ //TODO Handle null
                Campaign c = CampaignMap.get(cm.CampaignId);
                c.Total_Calls__c++;
                if(UnqualifiedPhoneValues.contains(cm.Mobile_Provided__c) || UnqualifiedPhoneValues.contains(cm.Phone_Provided__c)){
                    c.Total_Unqualified__c++;
                    cm.Status = 'Contacted';
                }
                if(NurturingPhoneValues.contains(cm.Mobile_Provided__c) || NurturingPhoneValues.contains(cm.Phone_Provided__c)){
                    c.Total_Recycling__c++;
                    cm.Status = 'Contacted';
                }
                if(DisconnectedPhoneValues.contains(cm.Mobile_Provided__c) || DisconnectedPhoneValues.contains(cm.Phone_Provided__c)){
                    c.Total_Disconnects__c++;
                    if(cm.Phone == null | cm.MobilePhone == null){
                        cm.Status = 'Bad Contact Info'; //these run 1 at a time so if one is null and current DNIS is disconnectable, we can status BCI
                    }
                }
                if(DoNotCallPhoneValues.contains(cm.Mobile_Provided__c) || DoNotCallPhoneValues.contains(cm.Phone_Provided__c)){
                    c.Total_DNCs__c++;
                    cm.Status = 'Contacted';
                }
                if(FollowUpPhoneValues.contains(cm.Mobile_Provided__c) || FollowUpPhoneValues.contains(cm.Phone_Provided__c)){
                    c.Total_Follow_Up__c++;
                    cm.Status = 'Contacted';
                }
                if(AppointmentSetPhoneValues.contains(cm.Mobile_Provided__c) || AppointmentSetPhoneValues.contains(cm.Phone_Provided__c)){
                    c.Total_Appointments__c++;
                    cm.Status = 'Contacted';
                }
                if(WrongNumberPhoneValues.contains(cm.Mobile_Provided__c) || WrongNumberPhoneValues.contains(cm.Phone_Provided__c)){
                    c.Total_Wrong_Numbers__c++;
                    if(cm.Phone == null | cm.MobilePhone == null){
                        cm.Status = 'Bad Contact Info';
                    }
                }
                if(cm.Status == 'Never Called'){
                    cm.Status = 'Uncontacted';
                }
            }
        }
    }
    public static void ProcessLeadMap(){
        for(Lead l : LeadMap.values()){
            Task t = TaskMapByWhoId.get(l.Id);
            Set<String> LeadPhones = new Set<String>();

            if(l.MobilePhone != null){
                LeadPhones.add(l.MobilePhone);
            }
            if(l.Phone != null){
                LeadPhones.add(l.Phone);
            }
            if(l.Secondary_Contact_Mobile__c != null){
                LeadPhones.add(l.Secondary_Contact_Mobile__c);
            }
            if(!LeadPhones.contains(t.Five9DNIS__c)) {
//                t.WhoId = null;
//                t.WhatId = PhoneMapByName.get(t.Five9DNIS__c).Id;
            } else {
                ProcessLead(l,t);
            }
        }
    }
    public static void ProcessLead(Lead l,Task t){
        switch on t.CallDisposition{
            when 'Do Not Call'{
                l.Status = 'Unqualified';
                l.Lead_Disposition__c = t.CallDisposition;
            }
            when 'Follow Up : Call to Set', 'Follow Up : Not Ready','Visit Set','Appointment Set'{
                if(l.Status != 'Converted'){
                    l.Status = 'Assigned';
                }
                l.Lead_Disposition__c = t.CallDisposition;
            }
            when 'Unqualified : Can Not Do','Unqualified : Deceased','Unqualified : Language Barrier', 'Unqualified : Minor' , 'Unqualified : New Windows', 'Unqualified : Out of Territory','Unqualified : Renter','Unqualified : Senior'{
                l.Status = 'Unqualified';
                l.Lead_Disposition__c = t.CallDisposition;
            }
            when 'Nurturing : Budget','Nurturing : Competitor Preference', 'Nurturing : General No Interest','Nurturing : Moving'{
                l.Status = 'Recycling';
                l.Lead_Disposition__c = t.CallDisposition;
            }
            when 'Wrong Number'{
                l.Status = 'Unqualified';
                l.Lead_Disposition__c = t.CallDisposition;
                HandleWrongNumber(l,t);
            }
        }
    }
    public static void ProcessContactMap(){
        for(Contact c : ContactMap.values()){
            Task t = TaskMapByWhoId.get(c.Id);
            Set<String> contactPhones = new Set<String>();
            if(c.MobilePhone != null){
                contactPhones.add(c.MobilePhone);
            }
            if(c.HomePhone != null){
                contactPhones.add(c.HomePhone);
            }
            if(c.Phone != null){
                contactPhones.add(c.Phone);
            }
            if(!contactPhones.contains(t.Five9DNIS__c)) {
//                t.WhoId = null;
//                t.WhatId = PhoneMapByName.get(t.Five9DNIS__c).Id;
            } else {
                ProcessContact(c,t);
            }
        }
    }
    public static void ProcessContact(Contact c, Task t){
        Account a = new Account(Id = c.AccountId);
        switch on t.CallDisposition{
            when 'Do Not Call'{
                a.Stage__c = 'Lost';
                a.Account_Disposition__c = t.CallDisposition;
                a.isDo_Not_Call__c = true;
                a.Type = 'Avoid';
            }
            when 'Follow Up : Call to Set', 'Follow Up : Not Ready','Visit Set','Appointment Set'{
                a.Stage__c = 'Working';
                a.Account_Disposition__c = t.CallDisposition;
            }
            when 'Unqualified : Can Not Do','Unqualified : Deceased','Unqualified : Language Barrier', 'Unqualified : Minor' , 'Unqualified : New Windows', 'Unqualified : Out of Territory','Unqualified : Renter','Unqualified : Senior'{
                a.Stage__c = 'Lost';
                a.Account_Disposition__c = t.CallDisposition;
            }
            when 'Nurturing : Budget','Nurturing : Competitor Preference', 'Nurturing : General No Interest','Nurturing : Moving'{
                a.Stage__c = 'Nurturing';
                a.Account_Disposition__c = t.CallDisposition;
            }
            when 'Wrong Number'{
                a.Stage__c = 'Nurturing';
                a.Account_Disposition__c = t.CallDisposition;
                HandleWrongNumber(c,t);
            }
        }
        AccountMap.put(a.Id,a);
    }

    public static void HandleWrongNumber(Lead l,Task t){
        Boolean badPhoneRemoved = false;
        if(l.MobilePhone == t.Five9DNIS__c){
            l.MobilePhone = '';
            badPhoneRemoved = true;
        }
        if(l.Phone == t.Five9DNIS__c){
            l.Phone = '';
            badPhoneRemoved = true;
        }
        if(l.Secondary_Contact_Mobile__c == t.Five9DNIS__c){
            l.Secondary_Contact_Mobile__c = '';
            badPhoneRemoved = true;
        }
        if(badPhoneRemoved){
            l.Bad_Phone_History__c = 'Wrong Number : '+ t.Five9DNIS__c +' -- ' + System.Datetime.now() + ', ' + '\r\n' + l.Bad_Phone_History__c;
            l.Bad_Phone_History__c = l.Bad_Phone_History__c.remove('null, ');
        }
    }
    public static void HandleWrongNumber(Contact c,Task t){
        Boolean badPhoneRemoved = false;
        if(c.MobilePhone == t.Five9DNIS__c){
            c.MobilePhone = '';
            badPhoneRemoved = true;
        }
        if(c.Phone == t.Five9DNIS__c){
            c.Phone = '';
            badPhoneRemoved = true;
        }
        if(c.HomePhone == t.Five9DNIS__c){
            c.HomePhone = '';
            badPhoneRemoved = true;
        }
        if(badPhoneRemoved){
            c.Bad_Phone_History__c = 'Wrong Number : '+ t.Five9DNIS__c +' -- ' + System.Datetime.now() + ', ' + '\r\n' + c.Bad_Phone_History__c;
            c.Bad_Phone_History__c = c.Bad_Phone_History__c.remove('null, ');
        }
    }
    //Map Updater
    public static void UpdateMaps(){
        update PhoneMap.values();
        update LeadMap.values();
        update ContactMap.values();
        update AccountMap.values();
        update CampaignMap.values();
        update CampaignMemberMap.values();
    }

    //Properties
    public static Map<Id,Task> TaskMapByWhoId {get; set;}
    public static Map<String,Task> TaskMapByDNIS {get; set;}
    public static Map<String,PhoneNumber__c> PhoneMapByName {get; set;}
    public static Map<Id,PhoneNumber__c> PhoneMap {get; set;}
    public static Map<Id,Lead> LeadMap { get; set;}
    public static Map<Id,Contact> ContactMap { get; set;}
    public static Map<Id,Account> AccountMap { get; set;}
    public static Map<Id,Campaign> CampaignMap { get; set;}
    public static Map<Id,CampaignMember> CampaignMemberMap { get; set;}

    public static Set<Id> WhoIds { get; set;}
    public static Set<Id> CampaignIds { get; set;}
    public static Set<String> PhoneValues { get; set;}
    public static Set<String> DisconnectedPhoneValues { get; set;}
    public static Set<String> DoNotCallPhoneValues { get; set;}
    public static Set<String> FollowUpPhoneValues { get; set;}
    public static Set<String> UnqualifiedPhoneValues { get; set;}
    public static Set<String> WrongNumberPhoneValues { get; set;}
    public static Set<String> AppointmentSetPhoneValues { get; set;}
    public static Set<String> NurturingPhoneValues { get; set;}
}