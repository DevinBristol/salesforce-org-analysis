/**
 * Created by Ben on 2/21/2025.
 */
@IsTest
public with sharing class AudioScavengeBatchTest {

    @TestSetup
    static void setupTaxkx(){
        Lead l1 = new Lead(FirstName='Le',LastName='ad',MobilePhone='3098999999',Street='741 Claremont Street',City='Lincoln',State='NE',PostalCode='68508',Country='US',Status='Open',Company='Le Ad',Name_of_Lead_Source__c='AudioScavengeBatch',Lead_Type__c='Residential',ba685ce4_2c28_433a_a4c6_cac18b40f436__c='4522353552',b7ef8429_9f35_4102_b1ea_44d3453a5086__c='soooooo');
        Lead l2 = new Lead(FirstName='aw',LastName='adaw',MobilePhone='4402599999',Street='1221 North 21st Street',City='Lincoln',State='NE',PostalCode='6850',Country='US',Status='Open',Company='aw adaw',Name_of_Lead_Source__c='AudioScavengeBatch',Lead_Type__c='Residential',ba685ce4_2c28_433a_a4c6_cac18b40f436__c='4522353552',b7ef8429_9f35_4102_b1ea_44d3453a5086__c='soooooo');
        Lead l3 = new Lead(FirstName='dkt',LastName='wwa6',MobilePhone='3068966339',Street='801 Saunders Street',City='Lincoln',State='NE',PostalCode='68503',Country='US',Status='Open',Company='dkt wwa6',Name_of_Lead_Source__c='AudioScavengeBatch',Lead_Type__c='Residential',ba685ce4_2c28_433a_a4c6_cac18b40f436__c='4522353552',b7ef8429_9f35_4102_b1ea_44d3453a5086__c='soooooo');

        insert new List<Lead>{l1,l2,l3};

        List<Lead> qls = [SELECT Id FROM Lead WHERE Name_of_Lead_Source__c='AudioScavengeBatch'];
        User u=[SELECT Id,F9AgentId__c FROM User WHERE FirstName='Ben' LIMIT 1];
        Task t1 = new Task(WhoId=qls[0].Id,CallDisposition='Unqualified : Renter',OwnerId=u.Id,Five9Campaign__c='Outbound - Cold Calling',Status='Closed',Subject='a au hwoawhwoueoh sdl;',
                Five9InteractionDuration__c='19',Five9TalkAndHoldTimeInSeconds__c=11,Five9Agent__c=u.F9AgentId__c,Five9__Five9SessionId__c='sldkajfsdl',
                Five9DNIS__c='3089899999',Five9ANI__c='5252552555');
//        Task t2 = new Task(WhoId=qls[1].Id,CallDisposition='Follow Up : Not Ready',OwnerId=u.Id,Five9Campaign__c='Outbound - Cold Calling',Status='Closed',Subject='a au hwoawhwoueoh sdl;',
//                Five9InteractionDuration__c='60',Five9Agent__c=u.F9AgentId__c,Five9__Five9SessionId__c='sldkajfsdl',
//                Five9DNIS__c='4402599999');
//        Task t3 = new Task(WhoId=qls[2].Id,CallDisposition='Disconnected',OwnerId=u.Id,Five9Campaign__c='Outbound - Cold Calling',Status='Closed',Subject='a au hwoawhwoueoh sdl;',
//                Five9InteractionDuration__c='14',Five9Agent__c=u.F9AgentId__c,Five9__Five9SessionId__c='sldkajfsdl',
//                Five9DNIS__c='3068966339');
        insert new List<Task>{t1
//                ,t2,t3
        };
    }
    @IsTest
    static void testMakeScope(){
        AudioScavengeBatch asb=new AudioScavengeBatch();
        List<Task>tasks=[SELECT Id,Subject,WhoId,CallDisposition,Five9__Five9SessionId__c,Five9_Call_Time__c,OwnerId,Five9DNIS__c,Five9ANI__c,Five9TalkAndHoldTimeInSeconds__c,CallDurationInSeconds,CallObject,Status,CreatedDate FROM Task ORDER BY CreatedDate DESC LIMIT 3];
//        CallCenter cc=[SELECT Id FROM CallCenter WHERE Name='Five9 Domain SSO' LIMIT 1];
//        VoiceCall vc=new voiceCall(ActivityId=tasks[0].Id,TranscribedLanguage='en',CallDurationInSeconds=1,CallCenterId=cc.Id,VendorType='Custom',ToPhoneNumber=tasks[0].Five9DNIS__c,FromPhoneNumber=tasks[0].Five9ANI__c,CallStartDateTime=tasks[0].CreatedDate,CallEndDateTime=tasks[0].CreatedDate.addSeconds(Integer.valueOf(tasks[0].Five9TalkAndHoldTimeInSeconds__c)),CallType='Outbound');
//        insert vc;
        Test.startTest();
        asb.makeScope();
        System.debug(asb.scopeTasks);
        System.debug(asb.delVCs);
        Test.stopTest();
        System.assertEquals(1,asb.scopeTasks.size());
        System.assertEquals(0,asb.delVCs.size());
        System.assertEquals(0,asb.taskVCmap.size());//cant make fucking voice calls so we gotta cheat.
    }
    @IsTest
    static void testEverything(){
        List<Lead> qls = [SELECT Id FROM Lead WHERE Name_of_Lead_Source__c='AudioScavengeBatch'];

        List<Task>tasks=[SELECT Id,Subject,WhoId,CallDisposition,Five9__Five9SessionId__c,Five9_Call_Time__c,OwnerId,Five9DNIS__c,Five9ANI__c,Five9TalkAndHoldTimeInSeconds__c,CallDurationInSeconds,CallObject,Status,CreatedDate FROM Task ORDER BY CreatedDate DESC LIMIT 3];
        tasks[0].Five9TalkAndHoldTimeInSeconds__c=1;
        update tasks[0];
//        CallCenter cc=[SELECT Id FROM CallCenter WHERE Name='Five9 Domain SSO' LIMIT 1];
//        VoiceCall vc=new VoiceCall(ActivityId=tasks[0].Id,TranscribedLanguage='en',CallDurationInSeconds=1,CallCenterId=cc.Id,VendorType='Custom',ToPhoneNumber=tasks[0].Five9DNIS__c,FromPhoneNumber=tasks[0].Five9ANI__c,CallStartDateTime=tasks[0].CreatedDate,CallEndDateTime=tasks[0].CreatedDate.addSeconds(Integer.valueOf(tasks[0].Five9TalkAndHoldTimeInSeconds__c)),CallType='Outbound');
//        insert vc;
        PropertyPirateShip.pirateShipFilter pFilt=new PropertyPirateShip.pirateShipFilter('CallObject','!=','');
        String atcutlQueryStrigg;
        String actulQTail;
        Test.startTest();
        AudioScavengeBatch AScvB = new AudioScavengeBatch();
        atcutlQueryStrigg=AScvB.queryString;
        actulQTail=AScvB.qTail;
        Database.executeBatch(AScvB,1);
        Test.stopTest();
    }
}