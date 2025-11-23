/**
 * Created by Ben on 2/25/2025.
 */

@IsTest
private class LeadPropertyRelationshipBatchableTest {
    @TestSetup
    static void setup(){
        List<Property__c> propsIn = new List<Property__c>();
        propsIn.add(new Property__c(Name='3430 North 63rd Street Lincoln, NE',Address__Street__s='3430 North 63rd Street',Address__City__s='Lincoln',Address__StateCode__s='NE',Address__CountryCode__s='US',Address__PostalCode__s='68507'
                ,Address__Latitude__s=40.84716887201762,Address__Longitude__s=-96.63413415970275
        ));
        propsIn.add(new Property__c(Name='1400 West Washington Street Lincoln, NE',Address__Street__s='1400 West Washington Street',Address__City__s='Lincoln',Address__StateCode__s='NE',Address__CountryCode__s='US',Address__PostalCode__s='68522'
                ,Address__Latitude__s=40.798445304073184,Address__Longitude__s=-96.7418975696945
        ));
        propsIn.add(new Property__c(Name='1000 Larkspur Drive Hickman, NE',Address__Street__s='1000 Larkspur Drive',Address__City__s='Hickman',Address__StateCode__s='NE',Address__CountryCode__s='US',Address__PostalCode__s='68372',
                Address__Latitude__s=40.39916887201762,Address__Longitude__s=-96.41590
        ));
        insert propsIn;
        List<Lead> leadsIn=new List<Lead>();
        leadsIn.add(new Lead(FirstName='l1',LastName='testBat1',Status='Open',MobilePhone='5552513151',Name_of_Lead_Source__c='LeadPropRelationBatchTest',Company='3430 North 63rd Street Lincoln, NE',Street='3430 North 63rd Street',City='Lincoln',State='NE',Country='US',PostalCode='68507'
                ,Latitude=40.84716887201762,Longitude=-96.63413415970275
        ));
        leadsIn.add(new Lead(FirstName='l2',LastName='testBat2',Status='Open',MobilePhone='5554665487',Name_of_Lead_Source__c='LeadPropRelationBatchTest',Company='1400 West Washington Street Lincoln, NE',Street='1400 West Washington Street',City='Lincoln',State='NE',Country='US',PostalCode='68522'
                ,Latitude=40.798445304073184,Longitude=-96.7418975696945
        ));
        leadsIn.add(new Lead(FirstName='l3',LastName='testBat3',Status='Open',MobilePhone='5558876542',Name_of_Lead_Source__c='LeadPropRelationBatchTest',Company='1000 Larkspur Drive Hickman, NE',Street='1000 Larkspur Drive',City='Hickman',State='NE',Country='US',PostalCode='68372'
                ,Latitude=40.39916887201762,Longitude=-96.41590
        ));
        insert leadsIn;

    }
    @IsTest
    static void makeScopePropQStringTest() {
        List<Lead>leads=
        [SELECT Id,Street,City,State,PostalCode,Country,Latitude,Longitude,CreatedDate
        FROM Lead WHERE Name_of_Lead_Source__c='LeadPropRelationBatchTest'];
        String propQString;
        Test.startTest();
        LeadPropertyRelationshipBatchable lprb=new LeadPropertyRelationshipBatchable(false,null,null);
        lprb.initializeLeadMaps(leads);
        propQString=lprb.makeScopePropQString(leads);
        String expectedQString='SELECT Id,Street,City,State,PostalCode,Country,Latitude,Longitude,Property__c,CreatedDate FROM Lead WHERE Property__c=NULL AND InitializedProperty__c=FALSE ANDStreet LIKE \'% %\' AND ((City!=NULL AND State!=NULL) OR PostalCode!=NULL) ORDER BY LastModifiedDate ASC';
        Test.stopTest();
        System.assertEquals(expectedQString.remove(' ').remove('\n'),lprb.queryString.remove(' ').remove('\n'));
        System.debug(lprb.ldAddressToLdIndex);
        System.debug(lprb.ldAddressToLeadId);
        System.debug('streets='+lprb.streets);
        System.debug('cities='+lprb.cities);
        System.debug('states='+lprb.states);
        System.debug('postals='+lprb.postals);
        System.assertNotEquals(null,lprb.streets);
        System.assertNotEquals(null,lprb.cities);
        System.assertNotEquals(null,lprb.states);
        System.assertNotEquals(null,lprb.postals);
        System.debug(propQString);

    }
    @IsTest
    static void makeUpdateLeadsTest() {
        List<Lead>leads=
        [SELECT Id,Street,City,State,PostalCode,Country,Latitude,Longitude,CreatedDate
        FROM Lead WHERE Name_of_Lead_Source__c='LeadPropRelationBatchTest'];
        String propQString;
        List<Lead>updateLeads=new List<Lead>();
        List<Property__c>props=[SELECT Id,Address__Street__s,Address__City__s,Address__StateCode__s,
                Address__PostalCode__s,Address__CountryCode__s,Address__Latitude__s,Address__Longitude__s
        FROM Property__c WHERE CreatedDate=TODAY ORDER BY CreatedDate DESC LIMIT 3];
        Test.startTest();
        LeadPropertyRelationshipBatchable lprb=new LeadPropertyRelationshipBatchable(false,null,null);
        lprb.initializeLeadMaps(leads);
        propQString=lprb.makeScopePropQString(leads);
        updateLeads=lprb.makeUpdateLeads(leads,props,lprb.leadIdToPropId);
        Test.stopTest();
        System.debug(lprb.ldAddressToLdIndex);
        System.debug('updateLeads='+updateLeads);
        System.debug(propQString);

    }
    @IsTest
    static void makeMarkForInitializedProperty() {
        List<Lead>leads= [SELECT Id,Street,City,State,PostalCode,Country,Latitude,Longitude,Property__c,CreatedDate,InitializedProperty__c FROM Lead WHERE Name_of_Lead_Source__c='LeadPropRelationBatchTest' LIMIT 3];
        List<Property__c>props= [SELECT Id,Address__Street__s,Address__City__s,Address__StateCode__s,Address__PostalCode__s,Address__CountryCode__s,Address__Latitude__s,Address__Longitude__s FROM Property__c WHERE CreatedDate=TODAY LIMIT 3];
        leads[0].Property__c=props[0].Id;
        leads[2].Property__c=null;
        update leads;
        Set<Id>lIds=new Set<Id>();
        for(Lead l : leads){
            lIds.add(l.Id);
        }
        Test.startTest();
        LeadPropertyRelationshipBatchable.markForInitializedProperty(lIds);
        Test.stopTest();
        List<Lead>qLeads= [SELECT Id,InitializedProperty__c,Property__c FROM Lead WHERE Name_of_Lead_Source__c='LeadPropRelationBatchTest' LIMIT 3];
        for(Lead l : qLeads){
            if(l.Property__c==null){
                System.assertEquals(false,l.InitializedProperty__c);
            } else {
                System.assertEquals(true,l.InitializedProperty__c);
            }
        }
    }
    @IsTest
    static void useTriggerHelper(){
        List<Lead>leads=[SELECT Id,Street,City,State,PostalCode,Country,Latitude,Longitude,CreatedDate
        FROM Lead WHERE Name_of_Lead_Source__c='LeadPropRelationBatchTest'];
        Test.startTest();
        LeadPropertyRelationshipBatchable lprb=new LeadPropertyRelationshipBatchable(true,null,null);
        lprb.initializeLeadMaps(leads);
        Test.stopTest();
        Map<Id,Lead>leadMap=new Map<Id,Lead>();
        for(Lead l : leads){
            leadMap.put(l.Id,l);
        }
        System.assertEquals(lprb.leadMap,leadMap);

    }
}