/**
 * Created by Ben on 8/19/2025.
 */
@IsTest
public with sharing class RecipeRunnerTest {
    private class RecipeRunnerHttpMock implements HttpCalloutMock {
        Integer statusCode;
        String body;
        RecipeRunnerHttpMock(Integer statusCode,String body) {
            this.statusCode=statusCode;
            this.body=body;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res=new HttpResponse();
            res.setHeader('Content-Type','application/json');
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }
    @IsTest
    static void testSuccessfulGet(){ //using the manual parameter constructor—>
        Test.setMock(HttpCalloutMock.class,new RecipeRunnerHttpMock(200,'{"targetDataflowId":"somebullshit"}'));
        Datetime startTime=System.now();
        RecipeRunner runner=new RecipeRunner();
        Test.startTest();
        String targetId=RecipeRunner.getTargetDataflowId('testRecipeId');
        Test.stopTest();
        System.assertEquals(targetId,'somebullshit');
    }
    @IsTest
    static void testSuccessfulPost(){ //using the manual parameter constructor—>
        String targetId='somebullshit';
        Test.setMock(HttpCalloutMock.class,new RecipeRunnerHttpMock(200,'{"Id":"theJobId"}'));
        Datetime startTime=System.now();
        RecipeRunner runner=new RecipeRunner();
        Test.startTest();
        String jobId=RecipeRunner.postRecipeRunRequest('testRecipeId');
        Test.stopTest();
        System.assertEquals(jobId,'theJobId');
    }

//SCHEDULABLE SHIT DOWN HERE
    @IsTest
    static void testSchedulableExecute(){
        Test.setMock(HttpCalloutMock.class,new RecipeRunnerHttpMock(200,'{"ok":true}'));
        String recipeId='testRecipeId';
        Test.startTest();
        String cronExp='0 0 12 * * ?';//set for 12:00PM
        System.schedule('testRecipeRunnerSchedulable',cronExp,new RecipeRunnerSchedulable(recipeId));
        Test.stopTest();
        List<CronTrigger>crons=[SELECT Id,CronJobDetail.Name,CronExpression,TimesTriggered FROM CronTrigger WHERE CronJobDetail.Name='testRecipeRunnerSchedulable'];
        System.assertEquals(1,crons.size(),'no just make ONE job at a time');
    }
    @IsTest
    static void testSchedWithDefaultConstructor(){
        Test.setMock(HttpCalloutMock.class,new RecipeRunnerHttpMock(200,'{"ok":true}'));
        Test.startTest();
        String cronExp='0 15 10 * * ?';//Run at 10:15 AM
        System.schedule('testRecipeRunnerSchedulable_Default',cronExp,new RecipeRunnerSchedulable());
        Test.stopTest();
        List<CronTrigger>crons=[SELECT Id,CronJobDetail.Name,CronExpression FROM CronTrigger WHERE CronJobDetail.Name='testRecipeRunnerSchedulable_Default'];
        System.assertEquals(1,crons.size(),'no just make ONE job at a time');
    }
    @IsTest
    static void testSchedWithManualConstructor(){
        Test.setMock(HttpCalloutMock.class,new RecipeRunnerHttpMock(200,'{"ok":true}'));
        String recipeId='testRecipeId';
        Datetime startTime=Datetime.newInstance(
                System.now().date(),
                Time.newInstance(System.now().hour(),((System.now().addMinutes(9).minute())/10)*10,0,0)
        );
        Datetime stopTime=startTime.addHours(10);
        Integer periods=60;
        Integer minInterval=((((stopTime.getTime()+59999)-startTime.getTime())/60000)/periods).intValue();
        System.debug('\r\t\t—startTime–> '+startTime.format('E M/d h:00a'));
        System.debug('\r\t\t—stopTime–> '+stopTime.format('E M/d h:00a'));
        System.debug('\r\t\t—minInterval–>'+minInterval);
        RecipeRunnerSchedulable rrs;
        Test.startTest();
        String cronExp='0 15 10 * * ?';//Run at 10:15 AM
        rrs=new RecipeRunnerSchedulable(recipeId,startTime,stopTime,periods);
        System.schedule('testRecipeRunnerSchedulable_Manual',cronExp,new RecipeRunnerSchedulable(recipeId,startTime,stopTime,periods));
        Test.stopTest();
        System.debug('\r\r——manual-rrs.rr––>\r'+JSON.serializePretty(rrs.rr));
//        System.assertEquals(startTime.minute(),10*(1+Integer.valueOf(System.now().format('mm').left(1))));
        System.assertEquals(stopTime,startTime.addMinutes(minInterval*periods),'minute Intervals * periods SHOULD be stop time.');
        System.assertEquals(minInterval,10);
        System.assertEquals(startTime,rrs.rr.startTime,'startTime should equal the rr variable');
        System.assertEquals(stopTime,rrs.rr.stopTime,'stopTime should equal the rr variable');
        System.assertEquals(periods,rrs.rr.periods,'periods should equal rrs.rr.periods');
        System.assertEquals(minInterval,rrs.rr.minInterval,'minInterval should equal the rrs.rr.minInterval');
        List<CronTrigger>crons=[SELECT Id,CronJobDetail.Name,CronExpression FROM CronTrigger WHERE CronJobDetail.Name='testRecipeRunnerSchedulable_Manual'];
        System.assertEquals(1,crons.size(),'no just make ONE job at a time');
    }
}
//    @IsTest
//    static void testSuccessfulExecute(){ //using the manual parameter constructor—>
//        clearCrons();
//        Test.setMock(HttpCalloutMock.class,new RecipeRunnerHttpMock(200,'{"result":"ok"}'));
//        Datetime startTime=System.now();
//        Datetime stopTime=startTime.addHours(10);
//        RecipeRunner runner=new RecipeRunner();
//        Test.startTest();
//        System.enqueueJob(runner);
//        Test.stopTest();
//        List<CronTrigger>crons=[SELECT Id,CronJobDetail.Name,CreatedDate,StartTime,EndTime,CronExpression,TimesTriggered,NextFireTime FROM CronTrigger];
//        System.debug('\rcrons:\r'+crons);
//        System.assert(!crons.isEmpty(),'where is my FREAKING scheduled job?');
//    }
//    @IsTest
//    static void testFailedExecute(){//500 error
//        clearCrons();
//        Test.setMock(HttpCalloutMock.class,new RecipeRunnerHttpMock(500,'{"error":"fail"}'));
//        RecipeRunner runner=new RecipeRunner('testRecipeId');
//        Test.startTest();
//        System.enqueueJob(runner);
//        Test.stopTest();
//        System.assertEquals('testRecipeId',runner.recipeId,'sorry');
//    }
//    @IsTest
//    static void testBlankConstructor(){
//        Test.setMock(HttpCalloutMock.class,new RecipeRunnerHttpMock(200,'{"result":"ok"}'));
//        Test.startTest();
//        clearCrons();
//        System.enqueueJob(new RecipeRunner());//mdt record named 'Current'
//        Test.stopTest();
//        System.assert(true,'no parameters constructor ok!');
//    }
//    @IsTest
//    static void testConstructor(){ //runs makeCallout and runRecipe
//        Test.setMock(HttpCalloutMock.class,new MockHttpResponse(200,'OK','{"Good deal"}'));
//        Test.startTest();
//        RecipeRunner rrEmpty=new RecipeRunner();
//        RecipeRunner rr=new RecipeRunner('05vR7000000QnbNIAS');
//        HttpRequest testReq=RecipeRunner.req; //cause its already made in constructor
////        HttpResponse testRes=RecipeRunner.res;
//        Test.stopTest();
//        System.debug('\r\r—–req—>\r'+testReq.toString());
////        System.debug('\r\r—–res—>\r'+testRes.toString());
//        System.assertEquals('System.HttpRequest[Endpoint='+Url.getOrgDomainUrl().toExternalForm()+'/services/data/v64.0/wave/recipes/05vR7000000QnbNIAS/jobs,Method=POST]',testReq.toString());
////        System.assertEquals('OK',testRes.getStatus());
////        System.assertEquals(200,testRes.getStatusCode());
//
//    }