/**
 * Created by Ben on 8/7/2025.
 */
@IsTest
public with sharing class CallLogAnalyticsBatchableTest {
    @IsTest
    static void testTurnstile(){
        Test.startTest();

        Test.stopTest();
    }
    @IsTest
    static void testTypesetter(){
        Test.startTest();

        Test.stopTest();
    }
    @IsTest
    static void testProcessPostSuccess(){
        Map<String,String> params=new Map<String,String>{'call_id'=>'1','ANI'=>'2223335555','secretKey'=>'remove this.'};
        String reqBody='';
        Test.startTest();
        String successResult=Five9Webhook.processPost(params,reqBody,'secretKey');
        Test.stopTest();
        System.assertEquals('SUCCESS',successResult,'This was the good one.');
        System.assertEquals(200,Five9Webhook.endcode,'success endcode should be 200');
        List<Call_Log__c> logs=[SELECT Id,Name FROM Call_Log__c];
        System.assertEquals(1,logs.size(),'A call log should have been inserted');
    }
    @IsTest
    static void testProcessPostInsertError(){
        Map<String,String> params=new Map<String,String>{'unhandled field name'=>'1'};
        String reqBody='';
        String xKey='secretKey';
        Test.startTest();
        String result=Five9Webhook.processPost(params,reqBody,xKey);
        Test.stopTest();
        System.debug(Five9Webhook.cl);
        System.assertEquals('["AUTHORIZED","reqBody=","params={unhandledfieldname=1}","Deserialized:{\\n\\"attributes\\":{\\n\\"type\\":\\"Call_Log__c\\"\\n}\\n}","ERRORONINSERT.","{\\n\\"attributes\\":{\\n\\"type\\":\\"Call_Log__c\\"\\n}\\n}","Insertfailed.Firstexceptiononrow0;firsterror:FIELD_CUSTOM_VALIDATION_EXCEPTION,NOEMPTIES!:[Name]"]',result.deleteWhitespace(),'Gimme the no insert fail message.');
        System.assert(result.contains('ERROR ON INSERT'),'Error message should mention insert');
        System.assertEquals(501,Five9Webhook.endcode);
    }
    @IsTest
    static void testDoPostAuthorized(){
        String secret=Five9Reporter_Setting__mdt.getInstance('Current').Secret__c;
        RestRequest req=new RestRequest();
        RestResponse res=new RestResponse();
        req.requestURI='/services/apexrest/Five9Webhook';
        req.httpMethod='POST';
        req.requestBody=Blob.valueOf('');
        req.params.put('call_id','2');
        req.params.put('x-shared-secret',secret);
        RestContext.request=req;
        RestContext.response=res;
        Test.startTest();
        String result=Five9Webhook.doPost();
        Test.stopTest();
        System.assertEquals(200,res.statusCode,'should authorize&succeed on insert');
        System.assertEquals('SUCCESS',result);
        System.assert(res.responseBody.toString().contains('SUCCESS'),'SUCCESS should be the response body');
    }
    @IsTest
    static void testDoPostUnauthorized(){
        RestRequest req=new RestRequest();
        RestResponse res=new RestResponse();
        req.requestURI='/services/apexrest/Five9Webhook';
        req.httpMethod='POST';
        req.requestBody=Blob.valueOf('');
        req.params.put('call_id','2');
        req.params.put('x-shared-secret','WRONG!');
        RestContext.request=req;
        RestContext.response=res;
        Test.startTest();
        String result=Five9Webhook.doPost();
        Test.stopTest();
        System.assertEquals(401,res.statusCode,'was looking for 401');
        System.assertEquals('Unauthorized',result);
    }
}