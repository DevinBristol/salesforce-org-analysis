/**
 * Created by brist on 8/8/2024.
 */
@IsTest
public with sharing class PropertyRelationHandlerTest {

    static final Integer recordMax = 7;

    public static String makeStreet(Integer i,Boolean isLead){
        List<String> streets = new List<String>();
    List<String> streetLetters = new List<String>{'Washington',
            'A','B','C','D','E','F','G','H','J','K','L','M','N','O','P','Q','R','S','T','U','Vine','W','X','Y','Orchard'};
        String streetDir;
        if(isLead){streetDir = 'East';} else {streetDir = 'West';}
        String street =  1+i.toString()+'0'+i+' '+streetDir+' '+streetLetters[i]+' Street';
        return street;
    }
    @TestSetup
    static void MakePropertiesLeadsAPRsOppties(){
        Integer i = 0;
        List<Lead> leads = new List<Lead>();
        List<Account> accts = new List<Account>();
        List<Contact> cs = new List<Contact>();
        List<Opportunity> opps = new List<Opportunity>();
        List<Property__c> props = new List<Property__c>();
        List<Account_Property_Relationship__c> aprs = new List<Account_Property_Relationship__c>();
        Map<Id,Property__c> ldPMap = new Map<Id,Property__c>();
        Map<Id,Property__c> acPMap = new Map<Id,Property__c>();
        List<Map<Id, Property__c>> propChildMaps = new List<Map<Id,Property__c>>();

//1.) Contact record Creation... fuck off
        for(i = 0 ; i < recordMax; i++){
            Contact c = new Contact(FirstName = 'c'+i,LastName = i.toString());
            cs.add(c);
        }
        insert cs; List<Contact> updateContacts = new List<Contact>();

//2.) Insert Leads & Accounts : Update Contacts

        List<String> factoryStreets = new List<String>();
        for (i = 0; i < recordMax; i++){
            Lead l = new Lead(FirstName = 'l'+i, LastName = i.toString()+'l',Company = i.toString()+'l'+', '+'l'+i, Status = 'Open', Name_of_Lead_Source__c = 'testShit',
                    Street = makeStreet(i,true),
                    City = 'Lincoln', State = 'NE', PostalCode = '68502', Country = 'US');
            leads.add(l);

            Account a = new Account(Name = 'a'+i, BillingStreet = makeStreet(i,false), BillingCity = 'Lincoln', BillingState = 'NE',BillingPostalCode = '68502',BillingCountry = 'US',Primary_Contact__c = cs[i].Id, Name_of_Lead_Source__c = 'testShit');
            accts.add(a);
            Contact c = cs[i]; c.AccountId=a.Id;
            updateContacts.add(c);
            factoryStreets.add(l.Street);
            factoryStreets.add(a.BillingStreet);
        }

        insert leads;
        insert accts;
        update updateContacts;
        System.debug(factoryStreets);

//3.) Insert Properties
        for(i = 0; i < recordMax; i++){
            Lead l = leads[i];
            Account a = accts[i];
            Property__c lP = new Property__c(Name = makeStreet(i,true)+' '+l.City+', '+l.State,
                    Address__Street__s=makeStreet(i,true),
                    Address__City__s = 'Lincoln',Address__StateCode__s = 'NE',
                    Address__PostalCode__s = '68502',Address__CountryCode__s = 'US');
            ldPMap.put(l.Id, lP);
            Property__c aP = new Property__c(Name = makeStreet(i,false)+' '+l.City+', '+l.State,
                    Address__Street__s= makeStreet(i,false),
                    Address__City__s = 'Lincoln',Address__StateCode__s = 'NE',
                    Address__PostalCode__s = '68502',Address__CountryCode__s = 'US');
            acPMap.put(a.Id, aP);
            System.debug(ldPMap); System.debug(acPMap);
            props.addAll(new List<Property__c>{lP,aP});
        }
        insert props;
        System.debug('soql accts ' +[SELECT Id, Name, BillingStreet,BillingCity,BillingState FROM Account WHERE Id IN :accts]);
        System.debug(accts);
        System.debug('soql accts ' +[SELECT Id, Name FROM Contact WHERE AccountId IN :accts]);
        System.debug(ldPMap);//lead is index 0 , acct is index 1
        System.debug(acPMap);

//1.) Insert APRs & Opportunities (One for each Account+Property pair) (One for each Account, requires acct + property])
    //1.2.) update leads[i].property__c & accts[i].property[i]
        for (i = 0; i < recordMax; i++){
            System.debug('accts['+i+']'+accts[i]);
            System.debug(ldPMap.keySet());
            Account_Property_Relationship__c apr = new Account_Property_Relationship__c(Account__c = accts[i].Id,Property__c=acPMap.get(accts[i].Id).Id,
                    isPrimaryResidence__c = true);
            aprs.add(apr);
            Opportunity o = new Opportunity(Name = 'o' + i,StageName = 'Confirming',CloseDate=System.today().addDays(i+1),AccountId=accts[i].Id,
                    Opportunity_Property__c = acPMap.get(accts[i].Id).Id);//gets id off the property from the acct(#1)maplist which was keyed to account#i's Id
            opps.add(o);

            //update leads...take the id from the property Object mapped in first map List (the leads one) to the Lead.Id for each i Lead
            leads[i].Property__c = ldPMap.get(leads[i].Id).Id;
        }
        insert aprs;
        insert opps;
        update leads;
    }
    @IsTest static void testObjectsExist(){
        List<Lead> leads = [SELECT Id, Name, Street, City, State, PostalCode FROM Lead WHERE Name_of_Lead_Source__c = 'TestShit'];
        List<Account> accts = [SELECT Id, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry FROM Account WHERE Name_of_Lead_Source__c = 'TestShit'];
        List<Property__c> props = [SELECT Id, Name FROM Property__c WHERE AccountId__c IN :accts OR CreatedDate = TODAY];
        List<Account_Property_Relationship__c> aprs = [SELECT Id, Name , Account__c, Property__c FROM Account_Property_Relationship__c WHERE Account__c IN :accts];
        System.assertEquals(recordMax,leads.size());
        System.assertEquals(recordMax,accts.size());
        System.assertEquals(recordMax,aprs.size());
    }
    @IsTest
    static void testAssignValues() {
        List<String> factoryStreets = new List<String>();

        for (Integer i = 0; i < recordMax; i++){
            String ldStreet = makeStreet(i,true);
            String acStreet = makeStreet(i,false);
            factoryStreets.add(ldStreet);
            factoryStreets.add(acStreet);
        }
        System.debug(factoryStreets);
        List<Lead> leads = [SELECT FirstName,LastName,Company,Status,City,State,PostalCode,Country, Property__c
        FROM Lead WHERE Street IN :factoryStreets];
        List<Account> accts = [SELECT Id,Name,BillingStreet,BillingCity,BillingState,BillingPostalCode,BillingCountry
        FROM Account WHERE BillingStreet IN :factoryStreets];
        List<Account_Property_Relationship__c> aPRs = [SELECT Id,Name,Account__c,Property__c,isPrimaryResidence__c
        FROM Account_Property_Relationship__c WHERE Account__c IN :accts];
        List<Property__c> props = [SELECT Id, Name, AccountId__c, Address__Street__s,Address__StateCode__s,Address__City__s,Address__PostalCode__s,Address__CountryCode__s
        FROM Property__c WHERE Address__Street__s IN :factoryStreets];
        List<Opportunity> opps = [SELECT Id, Name, AccountId, Opportunity_Property__c FROM Opportunity WHERE AccountId IN :accts];

        List<Id> aPropIds = new List<Id>();
        List<Id> lPropIds = new List<Id>();

        for (Integer i = 0; i < recordMax; i++) {
            aPropIds.add(aPRs[i].Property__c);
            lPropIds.add(leads[i].Property__c);
        }
        List<Property__c> aProps = [SELECT Id, Name, AccountId__c, Address__Street__s,Address__StateCode__s,Address__City__s,Address__PostalCode__s,Address__CountryCode__s FROM Property__c WHERE Id IN :aPropIds];
        List<Property__c> lProps = [SELECT Id, Name, AccountId__c, Address__Street__s,Address__StateCode__s,Address__City__s,Address__PostalCode__s,Address__CountryCode__s FROM Property__c WHERE Id IN :lPropIds];
        Map<Id,Property__c> testPropertyMap = new Map<Id,Property__c>();
        for (Integer i = 0; i < recordMax; i++) {
            Property__c aP = aProps[i];
            testPropertyMap.put(aPRs[i].Property__c,aP);
        }for (Integer i = 0; i < recordMax; i++) {
            Property__c lP = lProps[i];
            testPropertyMap.put(leads[i].Property__c, lP);
        }

        Set<String> resultStreets = new Set<String>();
        Set<String> factoryStreetsSet = new Set<String>();
        Integer i = 0;
        Set<String> returnableStreets = new Set<String>();
        for (String street: factoryStreets){
            factoryStreetsSet.add(street);
            if(i<recordMax){
                returnableStreets.add(lProps[i].Address__Street__s);
            }
            i++;
        }
        PropertyRelationHandler.HandlePropertyRelations(testPropertyMap);
        resultStreets.addAll(PropertyRelationHandler.Streets);


        System.assertEquals(factoryStreetsSet,resultStreets);
        System.assertNotEquals(returnableStreets,resultStreets);



//
//        for(Property__c p : props){
//        }

    }
    @IsTest
    static void testCreateAPRs(){
        List<Account> accs = [SELECT Id FROM Account WHERE Name_of_Lead_Source__c = 'TestShit'];
        List<Property__c> aProps = [SELECT Id, Name, AccountId__c, Address__Street__s,Address__StateCode__s,Address__City__s,Address__PostalCode__s,Address__CountryCode__s FROM Property__c WHERE AccountId__c IN :accs];
        PropertyRelationHandler.CreateAPRs(aProps);

        List<Account_Property_Relationship__c> testAPRs = [SELECT Id, Account__c FROM Account_Property_Relationship__c WHERE Property__c IN :aProps];
        System.assertNotEquals(PropertyRelationHandler.CreatedAPRs,testAPRs);

    }

    @IsTest
    static void testGetPropertiesFromLeadStreets(){
        Lead l1 = [SELECT Id, Street From Lead WHERE FirstName = 'l1' LIMIT 1];
        Map<Id,Lead> leadMapnew = new Map<Id,Lead>();
        leadMapnew.put(l1.Id,l1);
        Map<Id,Property__c> propMap = PropertyRelationHandler.getPropertiesFromLeadStreets(leadMapnew);
    }
//    @IsTest
//    static void MakeAPRMap(){
//
//    }
//    @IsTest
//    static void MakeLeadMap(){
//
//    }
//    @IsTest
//    static void MakeOpportunityMap(){
//
//    }
}