/**
 * Created by Devin on 6/6/2024.
 */

public without sharing class NamingUtility {

    public static List<Lead> NameLeadCompany(List<Lead> leads){
        List<Lead> returnLeads = new List<Lead>();
        String Missing = '[not provided]';

        for(Lead l: leads){
            String leadCompanyName;
            Integer i = 0;
            NameCompare nameCompare = new NameCompare();
            List<sortablePerson> sortablePersonsList = new List<sortablePerson>();

            sortablePersonsList.add(new sortablePerson(l.Id,(l.FirstName ?? Missing) + ' ' + (l.LastName ?? Missing)));

            if(String.isNotBlank(l.SecondaryContactFirstName__c) || String.isNotBlank(l.Secondary_Contact_Last_Name__c)){
                sortablePersonsList.add(new sortablePerson(l.Id,(l.SecondaryContactFirstName__c ?? Missing) + ' ' + ((l.Secondary_Contact_Last_Name__c ?? l.LastName) ?? Missing)));
            }

            sortablePersonsList.sort(nameCompare);

            for (sortablePerson s : sortablePersonsList){
                if(i == 0){
                    leadCompanyName = s.name;
                }else{
                    leadCompanyName = leadCompanyName + ' & ' + s.name;
                }
                i++;
            }
            l.Company = leadCompanyName;
            returnLeads.add(l);
        }
        return returnLeads;
    }
    public static List<Property__c> NameProperty(List<Property__c> Properties){
        String Missing = '[not provided]';
        List<Property__c> returnProperties = new List<Property__c>();
        for(Property__c p : Properties){
            System.debug(p);
            p.Name = (p.Address__Street__s ?? Missing) + ' ' + (p.Address__City__s ?? Missing) + ', ' + (p.Address__StateCode__s ?? Missing);
            returnProperties.add(p);
            System.debug(p);
        }
        return returnProperties;
    }
    public static String StandardizePropertyName(Property__c p){
        String Missing = '[not provided]';                                         //NE,IA,SD,KS,MO,CO,WY,MN
        if(p.Address__StateCode__s == null && p.Address__PostalCode__s != null){ //68010, 51100,57400,66777,65019,81009,82101,56666
            if(Long.valueOf(p.Address__PostalCode__s) >= 68001  && Long.valueOf(p.Address__PostalCode__s) <= 69367){
                p.Address__StateCode__s = 'NE';
            } else if(Long.valueOf(p.Address__PostalCode__s) >= 50001  && Long.valueOf(p.Address__PostalCode__s) <= 52809){
                p.Address__StateCode__s = 'IA';
            } else if(Long.valueOf(p.Address__PostalCode__s) >= 57001  && Long.valueOf(p.Address__PostalCode__s) <= 57799){
                p.Address__StateCode__s = 'SD';
            } else if(Long.valueOf(p.Address__PostalCode__s) >= 66001  && Long.valueOf(p.Address__PostalCode__s) <= 67954){
                p.Address__StateCode__s = 'KS';
            } else if(Long.valueOf(p.Address__PostalCode__s) >= 63001  && Long.valueOf(p.Address__PostalCode__s) <= 65899){
                p.Address__StateCode__s = 'MO';
            } else if(Long.valueOf(p.Address__PostalCode__s) >= 80001  && Long.valueOf(p.Address__PostalCode__s) <= 81658){
                p.Address__StateCode__s = 'CO';
            } else if(Long.valueOf(p.Address__PostalCode__s) >= 82001  && Long.valueOf(p.Address__PostalCode__s) <= 83414){
                p.Address__StateCode__s = 'WY';
            }else if(Long.valueOf(p.Address__PostalCode__s) >= 55001  && Long.valueOf(p.Address__PostalCode__s) <= 56763){
                p.Address__StateCode__s = 'MN';
            }
        }

        String PropertyName = (p.Address__Street__s ?? Missing) + ' ' + (p.Address__City__s ?? Missing) + ', ' + (p.Address__StateCode__s ?? Missing);
        return PropertyName;
    }
    public static String StandardizePropertyNameFromAddresses(String Street,String City,String State, String PostalCode){
        String Missing = '[not provided]';
        State = StateNameToStateCode(State);
        String PropertyName = (Street ?? Missing) + ' ' + (City ?? Missing) + ', ' + (State ?? Missing);
        return PropertyName;
    }
    public static List<Account> NameAccount(List<SObject> SObjects){
        List<Account> returnAccounts = new List<Account>();
        String Missing = '[not provided]';
        Set<Id> accIds = new Set<Id>();

        for(SObject s :SObjects){
        accIds.add(s.Id);
        }

        List<Account> accounts = new List<Account>([SELECT Id,(SELECT Id, FirstName, LastName FROM Contacts) FROM Account WHERE Id IN :accIds]);

        for(Account a: accounts){
            String accName;
            Integer i = 0;
            if(a.Contacts != null){
                NameCompare nameCompare = new NameCompare();
                List<sortablePerson> sortablePersonsList = new List<sortablePerson>();
                for(Contact c : a.Contacts){
                        sortablePersonsList.add(new sortablePerson(c.Id,(c.FirstName ?? Missing) + ' ' + (c.LastName ?? Missing)));

                }
                sortablePersonsList.sort(nameCompare);
                for (sortablePerson s : sortablePersonsList){
                    if(i == 0){
                        accName = s.name;
                    }else{
                        accName = accName + ' & ' + s.name;
                    }
                    i++;
                }
            }
            a.Name = accName ?? 'No Contacts in Account';
            System.debug(accName);
            returnAccounts.add(a);
        }
        return returnAccounts;
    }
    public static List<Opportunity> NameOpportunity(List<SObject> SObjects){
        String Missing = '[not provided]';
        List<Opportunity> returnOpportunities = new List<Opportunity>();
        Set<Id> accIds = new Set<Id>();
        Set<Id> propIds = new Set<Id>();
        List<Opportunity> opportunities = (List<Opportunity>)SObjects;

        if(opportunities.size() > 0){
            for(Opportunity o : opportunities){
                if(o.AccountId != null){
                    accIds.add(o.AccountId);
                }
                if(o.Opportunity_Property__c != null){
                    propIds.add(o.Opportunity_Property__c);
                }
            }

            Map<Id,Property__c> propertyMap = new Map<Id,Property__c>([SELECT Id,Name FROM Property__c WHERE Id IN :propIds]);
            Map<Id,Account> accountMap = new Map<Id,Account>([SELECT Id,Name FROM Account WHERE Id IN :accIds]);

            System.debug(propertyMap);
            System.debug(accountMap);

            for(Opportunity o : opportunities){
                o.Name = (accountMap.get(o.AccountId).Name ?? Missing);
                if(o.Opportunity_Property__c != null){
                    o.Name += ' – ' + (propertyMap.get(o.Opportunity_Property__c).Name ?? Missing);
                }else{
                    o.Name += ' – ' + Missing;
                }
                if(o.CloseDate != null){
                    o.Name += ' – ' + (o.CloseDate.format() ?? Missing);
                }else{
                    o.Name += ' – ' + Missing;
                }
                returnOpportunities.add(o);
            }
        }
        return returnOpportunities;
    }

//Work Order And Service Appointment Naming
    //Top
    public static void NameWorkOrdersAndServiceAppointments(Set<Id> Ids){
        Map<Id,WorkOrder> WorkOrderMap = getWorkOrdersById(Ids);
        Map<Id,ServiceAppointment> ServiceAppointmentMap = getServiceAppointmentsById(WorkOrderMap.keySet());
        WorkOrderMap = processWorkOrderMap(WorkOrderMap);
        ServiceAppointmentMap = processServiceAppointmentMap(ServiceAppointmentMap);
        update WorkOrderMap.values();
        update ServiceAppointmentMap.values();
    }
    public static Map<Id,WorkOrder> processWorkOrderMap(Map<Id,WorkOrder> WorkOrderMap){
        for(WorkOrder wo : WorkOrderMap.values()){
            wo.StartDate = getLatestServiceAppointmentTime(wo.ServiceAppointments) ?? wo.StartDate;
            wo.Subject = MakeWorkOrderSubject(wo.Account.Name,wo.WorkType.Name,wo.StartDate,'');
        }
        return WorkOrderMap;
    }
    public static Map<Id,ServiceAppointment> processServiceAppointmentMap(Map<Id,ServiceAppointment> ServiceAppointments){
        for(ServiceAppointment sa : ServiceAppointments.values()){
            sa.Subject = MakeWorkOrderSubject(sa.Account.Name,sa.WorkType.Name,sa.SchedStartTime,sa.Appointment_Result_1__c??'');
        }
        return ServiceAppointments;
    }
    //SOQL - Selector
    public static Map<Id,WorkOrder> getWorkOrdersById(Set<Id> Ids){
        Map<Id,WorkOrder> WorkOrderMap = new Map<Id,WorkOrder>([SELECT Id,Account.Name,WorkType.Name,StartDate, (SELECT SchedStartTime FROM ServiceAppointments) FROM WorkOrder WHERE Id IN :Ids]);
        return WorkOrderMap;
    }
    public static Map<Id,ServiceAppointment> getServiceAppointmentsById(Set<Id> Ids){
        Map<Id,ServiceAppointment> ServiceAppointmentMap = new Map<Id,ServiceAppointment>([SELECT Id,WorkType.Name,Account.Name,SchedStartTime,Appointment_Result_1__c FROM ServiceAppointment WHERE Id IN :Ids OR ParentRecordId IN :Ids]);
        return ServiceAppointmentMap;
    }
    //Logic - Service
    public static Datetime getLatestServiceAppointmentTime (List<ServiceAppointment> serviceAppointments){
        Datetime latestTime;
        for(ServiceAppointment sa : serviceAppointments){
            if(sa.SchedStartTime > latestTime || latestTime == null){
                latestTime = sa.SchedStartTime;
            }
        }
        return latestTime;
    }
    public static String MakeTaskSubject(Id taskId){
        Task t = [SELECT Id, Subject, Five9Agent__c,Five9ANI__c, Five9DNIS__c, WhoId, CallDisposition, CreatedDate, CreatedBy.FirstName FROM Task WHERE Id = :taskId LIMIT 1];
        String whoName;
        if(t.WhoId.toString().startsWith('00Q')) {
            Lead l = [SELECT Name FROM Lead WHERE Id = :t.WhoId];
            whoName = l.Name;
        }
        else if(t.WhoId.toString().startsWith('003')){
            Contact c = [SELECT Name FROM Contact WHERE Id = :t.WhoId];
            whoName = c.Name;
        }
        String missing = '[not provided]';
            String subject = (t.CreatedBy.FirstName ?? missing)+'('+(t.Five9ANI__c ?? missing)+') → '+(whoName ?? missing)+'('+(t.Five9DNIS__c ?? missing)+')'+', '+(t.CallDisposition ?? missing)+'; '+(t.CreatedDate.format('MM/dd/YYYY hh:mm a') ?? ' [Date Missing]');
        return subject;
    }
    public static String MakeWorkOrderSubject(String AccountName, String WorkTypeName, Datetime DateVar, String AppointmentResult){
        String Missing = '[not provided]';
        String WorkOrderName;
        if(DateVar == null){
            WorkOrderName = (AccountName ?? Missing) + ' : ' + (WorkTypeName ?? Missing) + ' - [Date Missing]' + (' - ' + AppointmentResult ?? '[Result Missing]');
        } else {
            WorkOrderName = (AccountName ?? Missing) + ' : ' + (WorkTypeName ?? Missing) + ' - ' + (DateVar.format() ?? Missing)  + (' - ' + AppointmentResult ?? '[Result Missing]');
        }
        return WorkOrderName;
    }
    public static String StateNameToStateCode(String State){
        if(State != null){
            if(State.equalsIgnoreCase('Nebraska')|State.equalsIgnoreCase('ne')){
                State = 'NE';
            } else if (State.equalsIgnoreCase('Iowa')|State.equalsIgnoreCase('ia')){
                State = 'IA';
            } else if (State.equalsIgnoreCase('South Dakota')|State.equalsIgnoreCase('sd')){
                State = 'SD';
            } else if (State.equalsIgnoreCase('Kansas')|State.equalsIgnoreCase('ks')){
                State = 'KS';
            } else if (State.equalsIgnoreCase('Missouri')|State.equalsIgnoreCase('mo')){
                State = 'MO';
            } else if (State.equalsIgnoreCase('Colorado')|State.equalsIgnoreCase('co')){
                State = 'CO';
            } else if (State.equalsIgnoreCase('Wyoming')|State.equalsIgnoreCase('wy')){
                State = 'WY';
            } else if (State.equalsIgnoreCase('Minnesota')|State.equalsIgnoreCase('mn')){
                State = 'MN';
            }
        }
        return State;
    }
    public static String CountryNameToCountryCode(String Country){
        if(Country != null){
            if(Country == 'United States'){
                Country = 'US';
            } else {
                Country = 'US';
            }
        }
        return Country;
    }

    // Name Sorting
    public class sortablePerson{
        private Id Id;
        private String name;
        public sortablePerson(Id i, String n) {
            Id = i;
            name = n;
        }
        public String getName() { return name; }
    }

    public class NameCompare implements Comparator<sortablePerson> {
        public Integer compare(sortablePerson e1, sortablePerson e2) {
            if(e1?.getName() == null && e2?.getName() == null) {
                return 0;
            } else if(e1?.getName() == null) {
                return -1;
            } else if(e2?.getName() == null) {
                return 1;
            }
            return e1.getName().compareTo(e2.getName());
        }
    }
}