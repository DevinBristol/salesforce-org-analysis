/**
 * Created by brist on 3/5/2025.
 */
@IsTest
public with sharing class PhoneRelationHandlerBatchableTest {
    @TestSetup
    static void setup(){
        Campaign c=new Campaign(Name='PhoneRelationHandlerBatchableTest',Type='Cold Calling');
        insert c;
        Campaign qC=[SELECT Id FROM Campaign WHERE Name='PhoneRelationHandlerBatchableTest' LIMIT 1];
        Lead l1=new Lead(FirstName='prhbtest1',LastName='l1',MobilePhone='5115115111',Name_of_Lead_Source__c='PhoneRelationHandlerBatchableTest');
        Lead l2=new Lead(FirstName='prhbtest2',LastName='l2',MobilePhone='5225225222',Name_of_Lead_Source__c='PhoneRelationHandlerBatchableTest');
        Lead l3=new Lead(FirstName='prhbtest3',LastName='l3',Name_of_Lead_Source__c='PhoneRelationHandlerBatchableTest');
        insert new List<Lead>{l1,l2,l3};
        List<Lead>qLeads=[SELECT Id,FirstName FROM Lead WHERE Name_of_Lead_Source__c='PhoneRelationHandlerBatchableTest'];
        List<CampaignMember>cmbrs=new List<CampaignMember>();
        for(Lead l : qLeads){
            cmbrs.add(new CampaignMember(LeadId=l.Id,CampaignId=qC.Id));
        }
        System.debug('\r\r\trequeried testleads:\r'+qLeads);
        insert cmbrs;
    }
    @IsTest
    static void testWithFilterStr(){
        PhoneRelationHandlerBatchable prhb = new PhoneRelationHandlerBatchable('Name_of_Lead_Source__c=\'Fake and gay\'');
        Test.startTest();
        Database.executeBatch(prhb,100);
        Test.stopTest();
        String expectedQString='SELECT Id,Name,MobilePhone,Phone,Secondary_Contact_Mobile__c FROM Lead WHERE Name_of_Lead_Source__c=\'Fake and gay\'';
        System.assertEquals(expectedQString.remove(' ').remove('\n'),prhb.queryString.remove(' ').remove('\n'));
    }
    @IsTest
    static void testCampaignNameConstructor(){
        List<Lead>qLeads=[SELECT Id,FirstName FROM Lead WHERE Name_of_Lead_Source__c='PhoneRelationHandlerBatchableTest'];
        Test.startTest();
        PhoneRelationHandlerBatchable prhb = new PhoneRelationHandlerBatchable('PhoneRelationHandlerBatchableTest','Name_of_Lead_Source__c=\'PhoneRelationHandlerBatchableTest\'');
        Test.stopTest();
        System.debug(prhb.queryString);
        String expectedQString='SELECT Id,Name,MobilePhone,Phone,Secondary_Contact_Mobile__c FROM Lead WHERE (Id=\''+qLeads[0].Id+'\' OR Id=\''+qLeads[1].Id+'\' OR Id=\''+qLeads[2].Id+'\') AND Name_of_Lead_Source__c=\'PhoneRelationHandlerBatchableTest\'';
        System.assertEquals(expectedQString.remove(' ').remove('\n'),prhb.queryString.remove(' ').remove('\n'));
    }
    @IsTest
    static void testPhoneRelationHandlerPrep(){
        List<Lead>qLeads=[SELECT Id,MobilePhone,Phone,Secondary_Contact_Mobile__c,InitializedNumbers__c,(SELECT Id,Phonenumber__r.Name,Phonenumber__r.Incidence__c FROM Phone2LeadRelationship__r) FROM Lead WHERE Name_of_Lead_Source__c='PhoneRelationHandlerBatchableTest'];
        Set<Id>runIds=new Set<Id>();

        Test.startTest();
        qLeads=PhoneRelationHandlerBatchable.phoneRelationHandlerPrep(qLeads);
        Test.stopTest();
        for(Lead l : qLeads){
            System.debug('testPhoneRelationHandlerPrep: mobilePhone='+l.MobilePhone+'\r\t...PPRs—>'+l.Phone2LeadRelationship__r+'\r\t...InitializedNumbers='+l.InitializedNumbers__c);
            if((l.MobilePhone==null&&l.Phone==null&&l.Secondary_Contact_Mobile__c==null)){
                System.assertEquals(100.00,l.InitializedNumbers__c);
                System.assertEquals(true,l.Phone2LeadRelationship__r.isEmpty());
            } else {
                Integer numbVals=0;
                if(l.MobilePhone!=null){
                    numbVals=numbVals+1;
                }
                if(l.Phone!=null){
                    numbVals=numbVals+1;
                }
                if(l.Secondary_Contact_Mobile__c!=null){
                    numbVals=numbVals+1;
                }
                System.assertEquals(false,l.Phone2LeadRelationship__r.isEmpty());
            }
        }
    }
}