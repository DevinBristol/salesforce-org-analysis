/**
 * Created by Devin on 8/12/2024.
 */

public with sharing class WorkOrderRelationHelper {

    @InvocableMethod(Label = 'Check Unrelated Appointments' Category = 'Account')
    public static void RelateUnrelatedAppointmentsFromAccountIds(List<Id> ids){
        for(Id id : ids){
            Set<Id> idSet = new Set<Id>{id};
            Map<Id,Account> accountMap = getAccountMap(idSet);
            for(Account a : accountMap.values()){
                RelatedUnrelatedAppointments(a);
            }
        }
    }

    public static void RelatedUnrelatedAppointments(Account a){
        Map<String,Property__c> PropertyMap = MakePropertyMap(a.Account_Property_Relationships__r);
        ServiceAppointment serviceAppointment = getServiceAppointment(makeStreetLikeVariables(PropertyMap.values()),makeZipCodeVariables(PropertyMap.values()));
        if(serviceAppointment != null){
            HandleRelations(a,serviceAppointment,PropertyMap.get(serviceAppointment.Street.substringBefore(' ')));
        }
    }

    public static Map<String,Property__c> MakePropertyMap(List<Account_Property_Relationship__c> propertyRelationships){
        Map<String,Property__c> PropertyMap = new Map<String,Property__c>();
        for(Account_Property_Relationship__c apr : propertyRelationships){
            PropertyMap.put(apr.Property__r.Address__Street__s.substringBefore(' '),apr.Property__r);
        }
        System.debug(PropertyMap);
        return PropertyMap;
    }

    public static ServiceAppointment getServiceAppointment(Set<String> Streets,Set<String>Zips){
        ServiceAppointment returnAppointment;
        Datetime lookupDate = System.now().addMinutes(-1);
        List<ServiceAppointment> serviceAppointments = new List<ServiceAppointment>([SELECT Id,ParentRecordId,Street,SchedStartTime,PostalCode FROM ServiceAppointment WHERE Street LIKE :Streets AND PostalCode IN :Zips AND LastModifiedDate >= :lookupDate ORDER BY LastModifiedDate DESC LIMIT 1]);
        System.debug(serviceAppointments);
        if(!serviceAppointments.isEmpty()){
            returnAppointment = serviceAppointments[0];
        }
        return returnAppointment;
    }

    public static void HandleRelations(Account a, ServiceAppointment sa, Property__c p){
        WorkOrder wo = new WorkOrder(Id = sa.ParentRecordId);
        Opportunity RelatedOpportunity = getOpenOpportunity(a);
        System.debug(RelatedOpportunity);
        if(RelatedOpportunity == null){
            HandleNoOpenOpportunity(a,sa,p,wo);
        } else {
            HandleOpenOpportunity(a,sa,p,wo,RelatedOpportunity);
        }
    }

    public static void HandleNoOpenOpportunity(Account a, ServiceAppointment sa, Property__c p,WorkOrder wo){
        a.Stage__c = 'Active';

        Opportunity newOpp = new Opportunity(AccountId = a.Id,StageName = 'Pending',Opportunity_Property__c = p.Id,CloseDate = sa.SchedStartTime.date(),OwnerId = a.OwnerId);
        insert newOpp;
        wo.AccountId = a.Id;
        wo.Opportunity__c = newOpp.Id;

        update a;
        update wo;
    }

    public static void HandleOpenOpportunity(Account a, ServiceAppointment sa, Property__c p,WorkOrder wo,Opportunity o){
        System.debug(o);
        a.Stage__c = 'Active';
        o.StageName = 'Pending';
        o.Opportunity_Property__c = p.Id;
        o.CloseDate = sa.SchedStartTime.date();
        wo.AccountId = a.Id;
        wo.Opportunity__c = o.Id;

        System.debug(o);
        update a;
        update o;
        update wo;
    }

    public static Opportunity getOpenOpportunity(Account a){
        Opportunity returnOpportunity;
        Date latestCloseDate = System.today().addMonths(-3);
        for(Opportunity o : a.Opportunities){
            if(o.IsClosed != true && o.CloseDate > latestCloseDate) {
                returnOpportunity = o;
            }
        }
        return returnOpportunity;
    }

    public static Map<Id,Account> getAccountMap(Set<Id> AccIds){
        Map<Id,Account> returnMap = new Map<Id,Account>([SELECT Id,Stage__c,OwnerId, (SELECT Id,Property__c,Property__r.Id,Property__r.Address__Street__s,Property__r.Address__PostalCode__s FROM Account_Property_Relationships__r),(SELECT Id,StageName,CloseDate,IsClosed FROM Opportunities) FROM Account WHERE Id IN :AccIds]);
        return returnMap;
    }

    public static Set<String> makeStreetLikeVariables(List<Property__c> properties){
        Set<String> returnList = new Set<String>();
        for(Property__c p : properties){
            returnList.add('%'+ p.Address__Street__s.substringBefore(' ') +'%');
        }
        return returnList;
    }
    public static Set<String> makeZipCodeVariables(List<Property__c> properties){
        Set<String> returnList = new Set<String>();
        for(Property__c p : properties){
            returnList.add(p.Address__PostalCode__s);
        }
        return returnList;
    }


}