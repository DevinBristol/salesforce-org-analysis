/**
 * Created by Devin on 8/5/2024.
 */

public without sharing class PropertyRelationHandler {

    public static void HandlePropertyRelations(Map<Id,Property__c> InputPropertyMap){
        if(TripWire != null && TripWire == true){
        } else {
            MakeValues(InputPropertyMap);
            MakeMaps();
            ProcessMaps();
            UpdateMaps();

            System.debug(LeadMap);
            System.debug(OpportunityMap);
            System.debug(PropertyMap);
            System.debug(DeletableProperties);
        }
    }

    //Property Management
    public static void MakeValues(Map<Id,Property__c> InputPropertyMap){
        InitializeValues();
        AssignValues(InputPropertyMap);
    }
    //...
    public static void InitializeValues(){
        InputPropertyIds = new Set<Id>();
        TripWire = true;
        CreatedAPRs = new List<Account_Property_Relationship__c>();
        DeletableProperties = new List<Property__c>();
        Streets = new Set<String>();
        PropertyNameIdMap = new Map<String,Id>();
        PropertyOldIdNewIdMap = new Map<Id,Id>();
        APRsDeletable = new List<Account_Property_Relationship__c>();
        AccountIdPropertyListMap = new Map<Id,List<Id>>();
    }
    public static void AssignValues(Map<Id,Property__c> InputPropertyMap){
        MakeAPRsAndInsert(InputPropertyMap.values());
        for(Property__c p : InputPropertyMap.values()){
            InputPropertyIds.add(p.Id);
            Streets.add(p.Address__Street__s);
        }
    }
    public static void MakeAPRsAndInsert(List<Property__c> properties){
        CreateAPRs(properties);
        if(CreatedAPRs!=null){
            insert CreatedAPRs;
        }
    }
    public static void CreateAPRs(List<Property__c> properties){
        for(Property__c p : properties){
            if(p.AccountId__c != null){
                CreatedAPRs.add(new Account_Property_Relationship__c(Property__c = p.Id, Account__c = p.AccountId__c));
            }
        }
        System.debug(CreatedAPRs);
    }
    //Map Construction
    public static void MakeMaps(){
        MakePropertyMap();
        MakePropertyMaps();
        MakeAPRMap();
        MakeLeadMap();
        MakeOpportunityMap();
    }
    //...
    public static void MakePropertyMaps(){
        for(Property__c p : PropertyMap.values()){
            p.Name = NamingUtility.StandardizePropertyName(p);
            if(PropertyNameIdMap.containsKey(p.Name)) {
                PropertyOldIdNewIdMap.put(p.Id,PropertyNameIdMap.get(p.Name));
                DeletableProperties.add(p);
            } else {
                PropertyNameIdMap.put(p.Name,p.Id);
            }
        }
    }
    public static void MakeAPRMap(){
        APRMap = getAccountPropertyRelationships();
        APRMap.putAll(CreatedAPRs);
    }
    public static void MakePropertyMap(){
        PropertyMap = getProperties();
    }
    public static void MakeLeadMap(){
        LeadMap = getLeads();
    }
    public static void MakeOpportunityMap(){
        OpportunityMap = getOpportunities();
    }

    //Map Processing
    public static void ProcessMaps(){
        ProcessLeadMap();
        ProcessAPRMap();
        ProcessOpportunityMap();
    }
    //...
    public static void ProcessLeadMap(){
        for(Lead l : LeadMap.values()){
            String LeadPropertyName = NamingUtility.StandardizePropertyNameFromAddresses(l.Street,l.City,l.State,l.PostalCode);
            System.debug(LeadPropertyName);
            l.Property__c = PropertyNameIdMap.get(LeadPropertyName);
        }
    }
    public static void ProcessAPRMap(){
        for (Account_Property_Relationship__c APR : APRMap.values()){
            if(PropertyOldIdNewIdMap.containsKey(APR.Property__c)){
                APR.Property__c = PropertyOldIdNewIdMap.get(APR.Property__c);
            }
            if(AccountIdPropertyListMap.containsKey(APR.Account__c)) {
                if(AccountIdPropertyListMap.get(APR.Account__c).contains(APR.Property__c)) {
                    APRsDeletable.add(APR);
                    //TODO refactor out so many If statements... Also, Handle deletable APRs Where isPrimary=true
                } else {
                    AccountIdPropertyListMap.get(APR.Account__c).add(APR.Property__c);
                }
            } else {
                AccountIdPropertyListMap.put(APR.Account__c,new List<Id>{APR.Property__c});
            }
        }
    }
    public static void ProcessOpportunityMap(){
        for(Opportunity o : OpportunityMap.values()){
            if(o.Opportunity_Property__c != null && PropertyOldIdNewIdMap.keySet().contains(o.Opportunity_Property__c)){
                o.Opportunity_Property__c = PropertyOldIdNewIdMap.get(o.Opportunity_Property__c);
            } else if (o.Property__c != null && PropertyOldIdNewIdMap.keySet().contains(o.Property__c)){
                o.Opportunity_Property__c = PropertyOldIdNewIdMap.get(o.Opportunity_Property__c);
            }
        }
    }

    //Map Updaters
    public static void UpdateMaps(){
        update LeadMap.values();
        update APRMap.values();
        update OpportunityMap.values();
        delete APRsDeletable;
        delete DeletableProperties;
    }

    //SOQL
    private static Map<Id,Property__c> getProperties(){
        Map<Id,Property__c> returnProperties = new Map<Id,Property__c>([SELECT Id,Name,Address__Street__s,Address__City__s,Address__StateCode__s,Address__PostalCode__s,AccountId__c,(SELECT Id, Street,City,State FROM Leads__r),(SELECT Id,Account__c FROM Account_Property_Relationships__r),(SELECT Id FROM Opportunities__r) FROM Property__c WHERE Address__Street__s IN :Streets OR Id IN :InputPropertyIds ORDER BY CreatedDate DESC ]);
        return returnProperties;
    }
    private static Map<Id,Account_Property_Relationship__c> getAccountPropertyRelationships(){
        Map<Id,Account_Property_Relationship__c> returnAPRMap = new Map<Id,Account_Property_Relationship__c>([SELECT Id,Property__c,Account__c FROM Account_Property_Relationship__c WHERE Property__c IN :PropertyMap.keySet() OR Property__c IN :InputPropertyIds]);
        returnAPRMap.putAll(CreatedAPRs);
        return returnAPRMap;
    }
    private static Map<Id,Lead> getLeads(){
        Map<Id,Lead> returnLeads = new Map<Id,Lead>([SELECT Id,Street,City,State,PostalCode,Property__c FROM Lead WHERE Street IN :Streets]);
        return returnLeads;
    }
    private static Map<Id,Opportunity> getOpportunities(){
        Map<Id,Opportunity> returnOpportunities = new Map<Id,Opportunity>([SELECT Id,Opportunity_Property__c,Property__c FROM Opportunity WHERE Property__c IN :PropertyMap.keySet() OR Opportunity_Property__c IN :PropertyMap.keySet() OR Property__c IN :InputPropertyIds OR Opportunity_Property__c IN :InputPropertyIds]);
        return returnOpportunities;
    }

    //Random SOQL Helpers

    public static Map<Id,Property__c> getPropertiesFromLeadStreets(Map<Id,Lead> LeadMapNew){
        Streets = new Set<String>();
        for(Lead l : LeadMapNew.values()){
            if(l.Street != null){
                Streets.add(l.Street);
            }
        }
        Map<Id,Property__c> returnProperties = getProperties();
        return returnProperties;
    }
    public static Map<Id,Property__c> PropertyMapFromNewAccountIds(Set<Id> accountIds){
        Map<Id,Property__c> returnPropertyMap = MakeInputPropertyMapFromAccounts(getAccounts(accountIds));
        return returnPropertyMap;
    }
    public static Map<Id,Account> getAccounts(Set<Id> AccountIds){
        Map<Id,Account> accountMap = new Map<Id,Account>([SELECT Id,(SELECT Id,Address__Street__s,AccountId__c FROM Properties__r),(SELECT Id,Property__r.AccountId__c,Property__r.Address__Street__s,Property__r.Id FROM Account_Property_Relationships__r) FROM Account WHERE Id IN :AccountIds]);
        return accountMap;
    }
    public static Map<Id,Property__c> MakeInputPropertyMapFromAccounts(Map<Id,Account> AccountMap){
        Map<Id,Property__c> returnPropertyMap = new Map<Id,Property__c>();
        for(Account a : AccountMap.values()){
            for(Property__c p : a.Properties__r){
                returnPropertyMap.put(p.Id,p);
            }
            for(Account_Property_Relationship__c apr : a.Account_Property_Relationships__r){
                returnPropertyMap.put(apr.Property__c,apr.Property__r);
            }
        }
        System.debug(returnPropertyMap);
        return returnPropertyMap;
    }

    //Properties
    public static Set<Id> InputPropertyIds {get;set;}
    public static List<Account_Property_Relationship__c> CreatedAPRs {get;set;}
    public static List<Account_Property_Relationship__c> APRsDeletable {get;set;}
    public static List<Property__c> DeletableProperties {get;set;}
    public static Set<String> Streets {get;set;}
    public static Map<Id,Property__c> PropertyMap {get;set;}
    public static Map<Id,Id> PropertyOldIdNewIdMap {get;set;}
    public static Map<String,Id> PropertyNameIdMap {get;set;}
    public static Map<Id,Account_Property_Relationship__c> APRMap {get;set;}
    public static Map<Id,Lead> LeadMap {get;set;}
    public static Map<Id,Opportunity> OpportunityMap {get;set;}
    public static Map<Id,List<Id>> AccountIdPropertyListMap {get;set;}
    public static Boolean TripWire {get;set;}
}