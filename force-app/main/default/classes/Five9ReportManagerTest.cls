/**
 * Created by benra on 9/18/2025.
 */
@IsTest
public class Five9ReportManagerTest {
    //static final Datetime START_STAMP=(Datetime.newInstance(2025,10,13,12,10,00));
    static final Integer MINUTE_INTERVAL=10;
    static final Datetime START_STAMP=(Datetime.newInstance(2025,10,13,12,00,00));
    static final Datetime END_STAMP=START_STAMP.addMinutes(MINUTE_INTERVAL);
    static final String FOLDER_NAME='Fake Five9 Report Folder';
    static final String REPORT_NAME='Fake Call Log Report';
    static final String DATASET_LABEL='Test Dataset';
//    static final String DATASET_APP='';
    static final String DATASET_NAME='TestDataset';
    static final String ORDERED_COL='CALL ID';
    static final String ORDERED_DIR='ASC';
    static final String OPERATION='Upsert';
    static final List<String> COLUMNS=new List<String>{
            'CALL ID','TIMESTAMP MILLISECOND','salesforce_id','AGENT','ANI','DNIS',
            'BILL TIME (ROUNDED)','SPEED OF ANSWER','HOLDS','f9_last_list','SESSION ID'
    };
    static final List<String>NAME_COLUMNS=new List<String>{
            'CallId','Timestamp','SalesforceId','Agent','Ani','Dnis',
            'BillTimeRounded','SpeedOfAnswer','Holds','LastList','SessionId'
    };
    static final Map<String,Map<String,Object>>ADJ_MAP=new Map<String,Map<String,Object>>{'CALL ID'=>new Map<String,Object>{'isUniqueId'=>true},
            'TIMESTAMP MILLISECOND'=>new Map<String,Object>{'label'=>'Timestamp'},'f9_last_list'=>new Map<String,Object>{'label'=>'Last List'}
    };
    static final String ADJMAP_CONSOLIDATED_JSON='{"SESSION ID":{"fullyQualifiedName":"SessionId","name":"SessionId","label":"SESSION ID","type":"Text"},"f9_last_list":{"fullyQualifiedName":"F9LastList","name":"F9LastList","label":"Last List","type":"Text"},"HOLDS":{"fullyQualifiedName":"Holds","name":"Holds","label":"HOLDS","format":"0","defaultValue":0,"precision":1,"scale":0,"type":"Numeric"},"SPEED OF ANSWER":{"fullyQualifiedName":"SpeedOfAnswer","name":"SpeedOfAnswer","label":"SPEED OF ANSWER","format":"0.000","defaultValue":0.000,"precision":18,"scale":3,"type":"Numeric"},"BILL TIME (ROUNDED)":{"fullyQualifiedName":"BillTimeRounded","name":"BillTimeRounded","label":"BILL TIME (ROUNDED)","format":"0.000","defaultValue":0.000,"precision":18,"scale":3,"type":"Numeric"},"DNIS":{"fullyQualifiedName":"Dnis","name":"Dnis","label":"DNIS","type":"Text"},"ANI":{"fullyQualifiedName":"Ani","name":"Ani","label":"ANI","type":"Text"},"AGENT":{"fullyQualifiedName":"Agent","name":"Agent","label":"AGENT","type":"Text"},"salesforce_id":{"fullyQualifiedName":"SalesforceId","name":"SalesforceId","label":"salesforce_id","type":"Text"},"TIMESTAMP MILLISECOND":{"fullyQualifiedName":"TimestampMillisecond","name":"TimestampMillisecond","label":"Timestamp","fiscalMonthOffset":0,"format":"yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'","type":"DateTime"},"CALL ID":{"isUniqueId":true,"fullyQualifiedName":"CallId","name":"CallId","label":"CALL ID","type":"Text"}}';
    static final List<String>NAME_HEADERS=new List<String>{'CallId','Timestamp','SalesforceId','ContactId','CampaignType','Campaign','CallType',
            'Agent','CustomerName','Ani','Dnis','LeadStatus','Disposition','LastDispo','Cost','Rate','BillTime','CallTime','HandleTime','TalkTime','ManualTime','DialTime','PreviewTime','RingTime','IvrTime','TalkTimeLessHoldAndPark','HoldTime','ParkTime','AfterCallWorkTime','QueueWaitTime','TotalQueueTime','QueueCallbackWaitTime','SpeedOfAnswer','TimeToAbandon','Calls','CallsTimedOutInIvr','CallsCompletedInIvr','Holds','Parks','Transfers','PreviewInterrupted','PreviewInterruptedByCall','PreviewInterruptedBySkillVm','QueueCallbackRegistered',
            'QueueCallbackProcessing','DisconnectedFromHold','IvrPath','Skill','ListName','Five9LastList','LastCampaign','Five9LastCampaignAttempts',
            'Carrier','DialResult','LiveConnect','NoPartyContact','Contacted','Abandoned','SessionId'
    };
    static final String METADATA_JSON=
    '{'+'"objects":[{' +
            '"fields":[' +
                '{"isUniqueId":true,"fullyQualifiedName":"CallId","name":"CallId","label":"CALL ID","type":"Text"},{"fullyQualifiedName":"TimestampMillisecond","name":"TimestampMillisecond","label":"Timestamp","fiscalMonthOffset":0,"format":"yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'","type":"DateTime"},' +
                '{"fullyQualifiedName":"SalesforceId","name":"SalesforceId","label":"salesforce_id","type":"Text"},{"fullyQualifiedName":"Agent","name":"Agent","label":"AGENT","type":"Text"},{"fullyQualifiedName":"Ani","name":"Ani","label":"ANI","type":"Text"},' +
                '{"fullyQualifiedName":"Dnis","name":"Dnis","label":"DNIS","type":"Text"},{"fullyQualifiedName":"BillTimeRounded","name":"BillTimeRounded","label":"BILL TIME (ROUNDED)","format":"0.000","defaultValue":0.000,"precision":18,"scale":3,"type":"Numeric"},' +
                '{"fullyQualifiedName":"SpeedOfAnswer","name":"SpeedOfAnswer","label":"SPEED OF ANSWER","format":"0.000","defaultValue":0.000,"precision":18,"scale":3,"type":"Numeric"},' +
                '{"fullyQualifiedName":"Holds","name":"Holds","label":"HOLDS","format":"0","defaultValue":0,"precision":1,"scale":0,"type":"Numeric"},' +
                '{"fullyQualifiedName":"F9LastList","name":"F9LastList","label":"Last List","type":"Text"},{"fullyQualifiedName":"SessionId","name":"SessionId","label":"SESSION ID","type":"Text"}'+
            '],'+
            '"name":"TestDataset","label":"Test Dataset","fullyQualifiedName":"TestDataset","connector":"CSV"'+
        '}],'+
        '"timezoneInfo":{"supportedTimezones":["America/Chicago"],"sourceTimezone":"GMT"},' +
        '"fileFormat":{"numberOfLinesToIgnore":1,"linesTerminatedBy":"\\r\\n","fieldsDelimitedBy":",","charsetName":"UTF-8"}' +
    '}';//Mon, 2025-10-13
    static List<String>CSV_ROWS=new List<String>{String.join(COLUMNS,','),
            '9000001,"Mon, 13 Oct 2025 11:01:10.100",00QR70Fake1ZyyVMA1,roddym@bristolwindows.org,5318001111,4028001111,00:00:11,00:01.11,0,SF - Nebraska - South Central - 2025,ENDofROW1',
            '9000002,"Wed, 13 Oct 2025 11:02:20.200",00QR70Fake2ZyyVMA2,ashleyl@bristolwindows.org,5318002222,4028002222,00:00:22,00:00.00,1,SF - Nebraska - Sandhills - 2025,ENDofROW2',
            '9000002,"Wed, 13 Oct 2025 11:03:30.300",,Awaldrop,5318003333,4028003333,,,,SF - Nebraska - Southwest - 2025,ENDofROW3'
    };
    static String FORMATTED_CSV=String.join(NAME_HEADERS,',')+'\r\n'+
            '9000001,"2025-10-13\'T\'16:01:10.100\'Z\'",00QR70Fake1ZyyVMA1,roddym@bristolwindows.org,5318001111,4028001111,11,1.11,0,SF - Nebraska - South Central - 2025,sessionIdnumber1\r\n'+
            '9000002,"2025-10-13\'T\'16:02:20.200\'Z\'",00QR70Fake2ZyyVMA2,ashleyl@bristolwindows.org,5318002222,4028002222,22,0.00,1,SF - Nebraska - Sandhills - 2025,sessionIdnumber2\r\n'+
            '9000002,"2025-10-13\'T\'16:03:30.300\'Z\'",,Awaldrop,5318003333,4028003333,,,,SF - Nebraska - Southwest - 2025,sessionIdnumber3';
    //return consolidated adjmap value    //{"SESSION ID":{"fullyQualifiedName":"SessionId","name":"SessionId","label":"SESSION ID","type":"Text"},"f9_last_list":{"fullyQualifiedName":"F9LastList","name":"F9LastList","label":"Last List","type":"Text"},"HOLDS":{"fullyQualifiedName":"Holds","name":"Holds","label":"HOLDS","format":"0","defaultValue":0,"precision":1,"scale":0,"type":"Numeric"},"SPEED OF ANSWER":{"fullyQualifiedName":"SpeedOfAnswer","name":"SpeedOfAnswer","label":"SPEED OF ANSWER","format":"0.000","defaultValue":0.000,"precision":18,"scale":3,"type":"Numeric"},"BILL TIME (ROUNDED)":{"fullyQualifiedName":"BillTimeRounded","name":"BillTimeRounded","label":"BILL TIME (ROUNDED)","format":"0.000","defaultValue":0.000,"precision":18,"scale":3,"type":"Numeric"},"DNIS":{"fullyQualifiedName":"Dnis","name":"Dnis","label":"DNIS","type":"Text"},"ANI":{"fullyQualifiedName":"Ani","name":"Ani","label":"ANI","type":"Text"},"AGENT":{"fullyQualifiedName":"Agent","name":"Agent","label":"AGENT","type":"Text"},"salesforce_id":{"fullyQualifiedName":"SalesforceId","name":"SalesforceId","label":"salesforce_id","type":"Text"},"TIMESTAMP MILLISECOND":{"fullyQualifiedName":"TimestampMillisecond","name":"TimestampMillisecond","label":"Timestamp","fiscalMonthOffset":0,"format":"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'","type":"DateTime"},"CALL ID":{"isUniqueId":true,"fullyQualifiedName":"CallId","name":"CallId","label":"CALL ID","type":"Text"}}
    static final Map<String,String>ALIAS_MAP=new Map<String,String>{'TIMESTAMP MILLISECOND'=>'Timestamp','f9_last_list'=>'Last List'};
    static final Five9ReportManager.reportRunner RUNNER=new Five9ReportManager.reportRunner(END_STAMP,START_STAMP,FOLDER_NAME,REPORT_NAME);
    static final InsightsExternalData IED=new InsightsExternalData(EdgemartAlias=DATASET_NAME,EdgemartLabel=DATASET_LABEL,Format='Csv',Operation=OPERATION,NotificationSent='Always',NotificationEmail='benr@bristolwindows.org',MetadataJson=Blob.valueOf(METADATA_JSON));
    static final IntegratedDatasetConfig__c IDC=new IntegratedDatasetConfig__c(DatasetName__c=DATASET_NAME,Columns__c=JSON.serialize(COLUMNS),Alias_Storage__c=JSON.serialize(ALIAS_MAP),Runner__c=JSON.serialize(RUNNER),OrderedColumn__c=ORDERED_COL,MinuteInterval__c=MINUTE_INTERVAL,
            Weekdays_Running__c='Sunday;Monday;Tuesday;Wednesday;Thursday;Friday;Saturday',LastRunTime__c=START_STAMP,NextRunTime__c=END_STAMP,DailyStartTime__c=Time.newInstance(0,0,0,0),DailyEndTime__c=Time.newInstance(23,59,59,999),
            MetadataJson__c=METADATA_JSON
    );
    static final AnalyticsUtility UPLOADER=new AnalyticsUtility(IED,ADJ_MAP,IDC,ALIAS_MAP);

//    static final Five9ReportManager MGR=new Five9ReportManager(END_STAMP,START_STAMP,FOLDER_NAME,REPORT_NAME,DATASET_NAME,OPERATION,ADJ_MAP,ORDERED_COL,MINUTE_INTERVAL);
//    static final Five9ReportManager.reportPoller POLLER=new Five9ReportManager.reportPoller(MGR);
//    static final Five9ReportManager.reportRetriever RETRIEVER=new Five9ReportManager.reportRetriever(new Five9ReportManager(END_STAMP,START_STAMP,FOLDER_NAME,REPORT_NAME,DATASET_NAME,OPERATION,ADJ_MAP,ORDERED_COL,MINUTE_INTERVAL));
    @TestSetup
    static void setupTest(){
        InsightsExternalData existingIed=IED;
        existingIed.EdgemartAlias=existingIed.EdgemartAlias+'Updating';
        existingIed.Status='Completed';
        insert existingIed;
//        InsightsExternalData scheduleIed=IED;
//        scheduleIed.EdgemartAlias=existingIed.EdgemartAlias+'Schedule';
//        scheduleIed.Status=''
//        System.debug('\n\n\tINSERTED IED:\n'+JSON.serializePretty(existingIed));
    }
    @IsTest
    static void testCreationConstructor(){
        Test.startTest();
        Five9ReportManager mgr=new Five9ReportManager(END_STAMP,START_STAMP,FOLDER_NAME,REPORT_NAME,DATASET_NAME,DATASET_LABEL,'',OPERATION,ADJ_MAP,COLUMNS,ORDERED_COL,MINUTE_INTERVAL);
        System.debug('TEST RESULTS: LastRunTime__c='+mgr.uploader.idc.LastRunTime__c+'\t... NextRunTime__c='+mgr.uploader.idc.NextRunTime__c);
        System.debug('TEST STATICS: LastRunTime__c='+IDC.LastRunTime__c+'\t... NextRunTime__c='+IDC.NextRunTime__c);
        Test.stopTest();
        System.assertEquals(true,mgr.uploader.idc.LastRunTime__c>=System.now().addMinutes(-5));//gives it padding for super long test runs
        System.assertEquals(mgr.uploader.idc.LastRunTime__c.addMinutes(MINUTE_INTERVAL),mgr.uploader.idc.NextRunTime__c);
        System.assertEquals(METADATA_JSON,mgr.uploader.idc.MetadataJson__c);
        System.assertEquals(METADATA_JSON,mgr.uploader.ied.MetadataJson.toString());
        IntegratedDatasetConfig__c idcExpected=IDC;
        idcExpected.LastRunTime__c=null;
        idcExpected.NextRunTime__c=null;
        mgr.uploader.idc.LastRunTime__c=null;
        mgr.uploader.idc.NextRunTime__c=null;
        System.assertEquals(RUNNER.toString(),mgr.runner.toString());
        System.assertEquals(JSON.serialize(idcExpected),JSON.serialize(mgr.uploader.idc));
        System.assertEquals(JSON.serialize(UPLOADER.AliasMap),JSON.serialize(mgr.uploader.AliasMap));
        System.assertEquals(new Set<String>(COLUMNS),mgr.uploader.AdjMap.keySet());
        System.assertEquals(ADJMAP_CONSOLIDATED_JSON,JSON.serialize(mgr.uploader.AdjMap));
        System.assertEquals(mgr.reportId,null);
        System.assertEquals(mgr.iedId,null);
    }
    @IsTest
    static void testUpdaterConstructor(){
        InsightsExternalData testIed=AnalyticsUtility.queryDataset(DATASET_NAME+'Updating');
        System.debug('\nQUERIED testIED:\n'+JSON.serializePretty(testIed));
        IntegratedDatasetConfig__c testIdc=IDC;
        testIdc.InsightsExternalDataId__c=testIed.Id;
        testIdc.DatasetName__c=testIed.EdgemartAlias;
        insert testIdc;
        System.debug('\nINSERTED testIDC:\n'+JSON.serializePretty(testIdc));
        Test.startTest();
        Five9ReportManager mgr=new Five9ReportManager(END_STAMP,START_STAMP,FOLDER_NAME,REPORT_NAME,testIed.Id,OPERATION,ADJ_MAP,ORDERED_COL,10);
        Test.stopTest();
        //System.debug('\nIED.getPopulatedFieldsAsMap() ...\n'+IED.getPopulatedFieldsAsMap()+'\n\n... mgr.uploader.ied.getPopulatedFieldsAsMap() ... \n'+mgr.uploader.ied.getPopulatedFieldsAsMap());//System.debug('\nIDC.getPopulatedFieldsAsMap() ...\n'+IDC.getPopulatedFieldsAsMap()+'\n\n... mgr.uploader.idc.getPopulatedFieldsAsMap() ... \n'+mgr.uploader.idc.getPopulatedFieldsAsMap());
        System.assertEquals(METADATA_JSON.replace(DATASET_NAME,DATASET_NAME+'Updating'),mgr.uploader.idc.MetadataJson__c);
        System.assertEquals(METADATA_JSON.replace(DATASET_NAME,DATASET_NAME+'Updating'),mgr.uploader.ied.MetadataJson.toString());
        System.assertEquals(JSON.serialize(RUNNER),JSON.serialize(mgr.runner)); // no idea
        System.assertEquals(null,mgr.polls);
    }
    @IsTest
    static void testReQueueConstructor(){
        InsightsExternalData testIed=AnalyticsUtility.queryDataset(DATASET_NAME+'Updating');
        System.debug('\nQUERIED testIED:\n'+JSON.serializePretty(testIed));
        IntegratedDatasetConfig__c testIdc=IDC;
        testIdc.InsightsExternalDataId__c=testIed.Id;
        testIdc.DatasetName__c=testIed.EdgemartAlias;
        insert testIdc;
        System.debug('\nINSERTED testIDC:\n'+JSON.serializePretty(testIdc));
        Test.startTest();
        Five9ReportManager mgr=new Five9ReportManager(testIed.Id);
        Test.stopTest();
        System.assertEquals(METADATA_JSON,mgr.uploader.idc.MetadataJson__c);
        System.assertEquals(METADATA_JSON,mgr.uploader.ied.MetadataJson.toString());
        System.assertNotEquals(JSON.serialize(RUNNER),JSON.serialize(mgr.runner));
        System.assertEquals(true,JSON.serialize(mgr.runner).contains('{"startGmtStr":"2025-10-13T17:10'));
        System.assertEquals(null,mgr.polls);
        System.debug('\nIED.getPopulatedFieldsAsMap() ...\n'+IED.getPopulatedFieldsAsMap()+'\n\n... mgr.uploader.ied.getPopulatedFieldsAsMap() ... \n'+mgr.uploader.ied.getPopulatedFieldsAsMap());
        System.debug('\nIDC.getPopulatedFieldsAsMap() ...\n'+IDC.getPopulatedFieldsAsMap()+'\n\n... mgr.uploader.idc.getPopulatedFieldsAsMap() ... \n'+mgr.uploader.idc.getPopulatedFieldsAsMap());
    }
    @IsTest
    static void testMgrPollingConstructors(){
        Test.startTest();
        Five9ReportManager mgr=new Five9ReportManager('FAKEREPORTID',UPLOADER,RUNNER);
        Five9ReportManager.reportPoller poller=new Five9ReportManager.reportPoller(mgr);
        Test.stopTest();
        System.assertNotEquals(null,mgr.uploader);
        System.debug('\nPOLLER:\n'+JSON.serializePretty(poller)+'\n');
    }
    @IsTest
    static void testRetrieverConstructor(){
        Test.startTest();
        Five9ReportManager.reportRetriever retriever=new Five9ReportManager.reportRetriever(new Five9ReportManager(END_STAMP,START_STAMP,FOLDER_NAME,REPORT_NAME,DATASET_NAME,DATASET_LABEL,'',OPERATION,ADJ_MAP,COLUMNS,ORDERED_COL,MINUTE_INTERVAL));
        Test.stopTest();
        System.debug('\n\nREPORT RETRIEVER object:\n'+JSON.serialize(retriever));
//        System.assertNotEquals(null,mgr.uploader);
    }
    @IsTest
    static void testMgrPostUploadPollerConstructors(){
        InsightsExternalData testIed=AnalyticsUtility.queryDataset(DATASET_NAME+'Updating');
        System.debug('\nQUERIED testIED:\n'+JSON.serializePretty(testIed));
        IntegratedDatasetConfig__c testIdc=IDC;
        testIdc.InsightsExternalDataId__c=testIed.Id;
        testIdc.DatasetName__c=testIed.EdgemartAlias;
        Test.startTest();
        Five9ReportManager mgr=new Five9ReportManager(testIed.Id,RUNNER);
        Five9ReportManager.analyticsUploader uploadSetup=new Five9ReportManager.analyticsUploader(testIed,CSV_ROWS,idc,RUNNER);
        Five9ReportManager.analyticsUploader uploadPolls=new Five9ReportManager.analyticsUploader(mgr);
        Test.stopTest();
        System.debug('\n\nSOURCE mgr:\n'+JSON.serialize(mgr)+'\nuploadSetup:\n'+JSON.serialize(uploadSetup)+'\nuploadPolls:\n'+JSON.serialize(uploadPolls)+'\n\n');
        System.assertNotEquals(null,mgr.iedId);
    }

    @IsTest
    static void testNormalizeDatasetLabel(){
        String normalizedName=AnalyticsUtility.normalizeDatasetLabel(null,DATASET_NAME);
        System.assertEquals('Test Dataset',normalizedName);
    }
    @IsTest
    static void testReformatRows() {
        List<String> cols=new List<String>{'TIMESTAMP MILLISECOND','CALL TIME','AGENT'};
        // Header row (will be removed by the method):
        String header=String.join(cols, ',');
        String row1='\uFEFF"Thu, 8 Sep 2025 15:49:42.381",00:01:05.000,Agent1';
        // Row 2: normal row without BOM or month-abbreviation quotes
        String row2='"Thu, 8 Sep 2025 15:50:21.122",00:00:32.000,Agent2';
        List<String>rows=new List<String>{header,row1,row2};
        List<String> results=Five9ReportManager.reformatRows(cols,rows);
        System.assertNotEquals(null,results,'Result should not be null');
        System.assert(results.size()>1,'Result should contain header + at least one reformatted row');
        // First element should still be the header row
        System.assertEquals(header, results[0],'First row of result should be header');
        // CHECK THAT THERES NO BOMs LEFT in REFORMATTED DATA
        for (Integer i=1; i < results.size(); i++) {
            System.assertEquals(-1, results[i].indexOf('\uFEFF'), 'No BOM character should remain in reformatted row ' + i);
        }

    }
    @IsTest
    static void testCheckCsvHeaders() {
        List<Map<String,Object>>fieldsMeta=AnalyticsUtility.makeFieldsMeta(COLUMNS,AnalyticsUtility.ConsolidateAdjMaps(ADJ_MAP,Five9ReportManager.labelMap,COLUMNS,ALIAS_MAP));
        System.debug('COLUMNS: '+COLUMNS);
        System.debug('FieldMetas'+JSON.serialize(fieldsMeta));
        Boolean checkPassed=Five9ReportManager.checkCsvHeaders(COLUMNS,fieldsMeta,ALIAS_MAP);
        System.assertEquals(false,checkPassed);
    }
    @IsTest
    static void splitLargeCsvTest(){// the rows from five9 are joined by \n
        List<String>rows=AnalyticsUtility.splitLargeCsv('yyy,xxx,00:00:05\nzzz,,00:01:00\n');
        System.debug('rows='+rows);
        System.assertEquals('yyy,xxx,00:00:05',rows[0]);
        System.assertEquals('zzz,,00:01:00',rows[1]);
    }
//    @IsTest
//    static void testQueryMetaDataJson(){// the rows from five9 are joined by \n
//        Blob iedBlob=AnalyticsUtility.queryMetaDataJson('CallLogTrialer');
//        System.debug('iedBlob='+iedBlob);
//        System.assertEquals('yyy,xxx,00:00:05',rows[0]);
//
//    }
    @IsTest
    static void testGetStandardName(){// the rows from five9 are joined by \n
        String standardName=AnalyticsUtility.getStandardName('CALL ID');
        System.debug('standardName='+standardName);
        System.assertEquals('CallId',standardName);
    }
    @IsTest
    static void testFormatDate(){
        String timestamp='13 Oct 2025 12:01:10.100'; //(11:01,PST/12:01,PDT)=>(13:01,CST/14:01,CDT)=>(19:01)UTC
        String formatted=Five9ReportManager.formatDate(timestamp);
        System.debug('Formatted date: ' + formatted);//(d MMM yyyy hh:mm:ss.SSS=Thu, 9 Oct 2025 12:00:00.010)   "2025-10-08T02:30:45.123Z"
        System.assertEquals('2025-10-13T19:01:10.100Z',formatted);
    }
    @IsTest
    static void testFormatDuration(){
        String hhmmss='01:01:05';
        String durFormat1=Five9ReportManager.formatDuration(hhmmss);
        String mmssSSS='02:03.5';
        String durFormat2=Five9ReportManager.formatDuration(mmssSSS);
        String hhmmssSSS='01:10:12.752';//4212.752
        String durFormat3=Five9ReportManager.formatDuration(hhmmssSSS);
        System.assertEquals(String.valueOf(3665),durFormat1);
        System.assertEquals(String.valueOf(123.5),durFormat2);
        System.assertEquals(String.valueOf(4212.752),durFormat3);
    }
    @IsTest
    static void testExecuteEnqueuesJob() {
        InsightsExternalData testIed=AnalyticsUtility.queryDataset(DATASET_NAME+'Updating');
        Test.startTest();
        Five9ReportScheduler scheduler = new Five9ReportScheduler(null);
        Test.setMock(SchedulableContext.class, new SchedulableContextMock());
        scheduler.execute(new SchedulableContextMock());
        Test.stopTest();
        System.assertEquals(null,scheduler.iedId, 'who gives a shit');
//        System.assertNotEquals(null, scheduler.idc, 'Expected non-null idc');
//        System.assertEquals(ied.Id, scheduler.ied.Id, 'Expected ied Id to match');
    }
    public class SchedulableContextMock implements SchedulableContext {
        public String getTriggerId() { return '707000000000001'; }
    }
//    @IsTest
//    static void testMakeFieldsMetaAndBuildMetaDataJson(){
//        List<String>headers=new List<String>{'CallId','Cost'};
//        List<Map<String,Object>>fieldsMeta=AnalyticsUtility.getFieldMetas(headers,Five9ReportManager.labelMap);
//        System.debug('fieldsMeta=\n'+JSON.serializePretty(fieldsMeta));
//        String metaJsonStr=AnalyticsUtility.buildMetadataJson(fieldsMeta,'Call Log Trialer,','CallLogTrialer');
//        System.debug('full metadataJson String:\n'+metaJsonStr);
//    }
//    @IsTest
//    static void testUploadHeaderToAnalytics_nullIED(){
//        AnalyticsUtility.uploadIed(null,datasetLabel,datasetName,datasetApp,OPERATION,nameHeaders,adjMap);
//    }
//    @IsTest
//    static void testMakeFormatGmtStr(){
//        String returnStr=Five9ReportManager.makeFormatGmtStr(Datetime.newInstance(2025,09,25,20,00,00));
//        System.debug('Formatted gmt datetime string='+returnStr);
//    }
//    @IsTest
//    static void testPutAdjustmentsIntoDefaultsMap(){
//        Map<String,Map<String,Object>>testAdjMap=new Map<String,Map<String,Object>>{
//                'newField'=>new Map<String,Object>{'label'=>'New Field'},
//                'CALL ID'=>new Map<String,Object>{'name'=>'CallId','isUniqueId'=>true,'label'=>'Call Id'}
//        };
//        Map<String,Map<String,Object>>testMap=Five9ReportManager.putAdjustmentsIntoDefaultsMap(testAdjMap,adjMap);
//        System.debug('\ntestMap result\n'+JSON.serializePretty(testMap));
//        AnalyticsUtility.uploadHeaderToAnalytics(null,datasetLabel,datasetName,datasetApp,OPERATION,nameHeaders,adjMap);
//    }
//    @IsTest
//    static void testAnalayticsUploaderConstructor(){
//        Five9ReportManager mgr=new Five9ReportManager();
//        Test.startTest();
//        Five9ReportManager.analyticsUploader mgrAU=new Five9ReportManager.analyticsUploader(mgr,null,rows);
//        Test.stopTest();
//        System.debug('\nrPoller=\n'+JSON.serializePretty(mgrAU));
//    }
//    @IsTest
//    static void testReportPollerConstructor(){
//        Five9ReportManager mgr=new Five9ReportManager();
//        Test.startTest();
//        Five9ReportManager.reportPoller rPoller=new Five9ReportManager.reportPoller(mgr);
//        Test.stopTest();
//        System.debug('\nrPoller=\n'+JSON.serializePretty(rPoller));
//    }
//    @IsTest
//    static void testReportRetriever(){
//        Five9ReportManager mgr=new Five9ReportManager();
//        Test.startTest();
//        Five9ReportManager.reportRetriever retriever=new Five9ReportManager.reportRetriever(mgr);
//        Test.stopTest();
//        System.debug('\nretriever=\n'+JSON.serializePretty(retriever));
//    }
//    @IsTest
//    static void testUploadHeaderToAnalytics_withIED(){
//
//        AnalyticsUtility.uploadHeaderToAnalytics();
//    }
//    @IsTest
//    static void testUploadPartFiles(){
//        AnalyticsUtility.uploadPartFiles();
//    }
//    @IsTest
//    static void fullFlowTest() {
//        Test.startTest();
//        Five9ReportManager mgr=new Five9ReportManager(
//                System.now(),System.now().addDays(-1),
//                'Five9Folder','Five9Report',
//                'TestDataset','Test Dataset',
//                'CustomerInsights','Overwrite',
//                Five9ReportManager.labelMap
//        );
//        System.assertNotEquals(null,mgr.reportId,'Report id should be set by runFive9Report');
//        System.enqueueJob(mgr); // —executes–>Five9ReportManager.execute
//        Test.stopTest();        // FLUSH!(the queueable chain)!.::.[poller—>reportRetriever—>analytixUploader]
//        //After stopTest all queueables have run, check that AnalyticsExternalData exists
//        List<InsightsExternalData>ieds=[SELECT Id,Action,OPERATION FROM InsightsExternalData];
//        System.assert(!ieds.isEmpty(),'A header InsightsExternalData record should have been inserted');
//        List<String> cols=new List<String>{'TIMESTAMP MILLISECOND','BILL TIME (ROUNDED)'};
//        List<String> rows=new List<String>{'TIMESTAMP MILLISECOND,BILL TIME (ROUNDED)','8 Sep 2025 15:49:42.381,00:00:05.000'};// trouble
//        List<String> reformatted=Five9ReportManager.reformatRows(cols,new List<String>(rows));
//        System.assertEquals(2,reformatted.size(),'reformatRows should keep header+1Row');
//        String formattedDate=Five9ReportManager.formatDate('8 Sep 2025 15:49:42.381'); //correct
//        System.assert(formattedDate.endsWith('Z'),'RETURN ZULU STAMP');
//        String formattedDuration=Five9ReportManager.formatDuration('00:00:05.000');
//        System.assertEquals('5',formattedDuration,'Duration should be converted to seconds');
//        Map<String,Map<String,Object>>adj=Five9ReportManager.putAdjustmentsIntoDefaultsMap(sampleAdjMap(),Five9ReportManager.labelMap);
//        System.assert(adj.containsKey('BILL TIME (ROUNDED)'));
//        // Confirm we can use the alternate constructor
//        Five9ReportManager mgr2=new Five9ReportManager('repollId',mgr.uploader);
//        System.assertEquals('repollId',mgr2.reportId);
//    }
//ANALYTICS UTILITY ONLY—>
    // Creating completed InsightsExternalData row for queryMetaDataJson
//    private static InsightsExternalData createCompletedIED(String aliasName) {
//        InsightsExternalData ied=new InsightsExternalData(
//                Format='Csv',EdgemartAlias=aliasName,EdgemartLabel=aliasName,EdgemartContainer='CustomerInsights',
//                OPERATION='Overwrite',Status='Completed',MetadataJson=Blob.valueOf(jsonRaw)//{"foo":"bar"} base64
//        ); // FIX THE META.JSON RETARD !! IT'S NOT THAT HARD.
//        insert ied;
//        return ied;
//    }
    @IsTest
    static void testAnalyticsUtilityConstructor() { //our org doesnt allow custom dataApps so just assume we'll always have customerInsights enabled.
//        Folder f=[SELECT Id, DeveloperName, Name, AccessType, CreatedDate, Type FROM Folder WHERE Type='Insights' AND (DeveloperName='CustomerInsights' OR Name='CustomerInsights') LIMIT 1];
//        Test.startTest();
//        AnalyticsUtility util=new AnalyticsUtility(ied, ad, f.DeveloperName, ADJM);
//        util.headers=headers;
//        util.AdjMap=adjMap;
//        Test.stopTest();
    }
//    @IsTest
//    static void testPollerExecutor() { //our org doesnt allow custom dataApps so just assume we'll always have customerInsights enabled.
//        Folder f=[SELECT Id, DeveloperName, Name, AccessType, CreatedDate, Type FROM Folder WHERE Type='Insights' AND (DeveloperName='CustomerInsights' OR Name='CustomerInsights') LIMIT 1];
//        List<String> headers=new List<String>{'CallId','CallTime','Cost','Rate'};
//        Map<String, Map<String,Object>>adjMap=Five9ReportManager.labelMap;
//        Five9ReportManager mgr=new Five9ReportManager();
//        Test.startTest();
//        mgr=Five9ReportManager.pollExecutor(mgr);
//        Test.stopTest();
//        System.debug('\nnew Mgr=\n'+JSON.serializePretty(mgr));
//    }
//    @IsTest
//    private static void testPollExecutor() {
//        // --- Branch 1: uploader.insightExtDataId is NOT null --------------------
//
//        // Create a dummy InsightsExternalData record so the SELECT finds something.
//        InsightsExternalData ied=new InsightsExternalData(
//                EdgemartAlias=datasetName,EdgemartLabel=datasetLabel,EdgemartContainer=datasetApp,
//                Format='Csv',MetadataJson=Blob.valueOf(jsonRaw),OPERATION=OPERATION);
//        insert ied;
//
//        // Build a Five9ReportManager with a fake uploader that points to the record we just inserted.
//        Five9ReportManager mgr1=new Five9ReportManager();
//        mgr1.uploader=new AnalyticsUtility(datasetName,datasetLabel,datasetApp,OPERATION,adjMap);
//        mgr1.uploader.insightExtDataId=ied.Id;
//        mgr1.OPERATION='Overwrite';
//        Test.startTest();
//        mgr1.polls=0;
//        Five9ReportManager result1=Five9ReportManager.pollExecutor(mgr1);
//        Test.stopTest();
//        System.assertNotEquals(null,result1,'Result should not be null');
//        // Should set isRunOngoing based on ied.Status (null means true)
//        System.assertEquals(true, result1.isRunOngoing,'Expected isRunOngoing to be true when ied.Status is null');
//        // --- Branch 2: uploader.insightExtDataId is NULL -------------------------
//        Five9ReportManager mgr2 = new Five9ReportManager();
//        mgr2.uploader=new AnalyticsUtility(datasetName,datasetLabel,datasetApp,OPERATION,adjMap);
//        mgr2.reportId='fakeReportId';
//        // Use a stub if Five9ReportRetriever.isReportRunningRequest is static;
//        // here we assume it returns false by default, or use a custom setting/mock.
//        Test.startTest();
//        Five9ReportManager result2=Five9ReportManager.pollExecutor(mgr2);
//        Test.stopTest();
//        System.assertNotEquals(null, result2, 'Result should not be null');
//        // When no insightExtDataId we hit the reportRetriever branch
//        System.assertEquals(false, result2.isRunOngoing,'Expected isRunOngoing to be false so job is queued immediately');
//    }
//    @IsTest
//    static void testAnalyticsUtility_AllMethods() { //our org doesnt allow custom dataApps so just assume we'll always have customerInsights enabled.
//        Folder f=[SELECT Id,DeveloperName,Name,AccessType,CreatedDate,Type FROM Folder WHERE Type='Insights'AND(DeveloperName='CustomerInsights'OR Name='CustomerInsights')LIMIT 1];
//        List<String> headers=new List<String>{'MyField'};
//        Map<String,Map<String,Object>>adjMap=new Map<String,Map<String,Object>>();
//        adjMap.put('MyField',new Map<String,Object>{'fullyQualifiedName'=>'MyField','name'=>'MyField','type'=>'Text','label'=>'My Field'});
//        Test.startTest();
//        AnalyticsUtility util=new AnalyticsUtility('TestDataset','Test Label',f.DeveloperName,'Overwrite',adjMap);
//        util.headers=headers;
//        util.AdjMap=adjMap;
//        // making completed ied record so queryMetaDataJson has something to find
//        InsightsExternalData completed=createCompletedIED('TestDataset');
//        List<Map<String,Object>>fm=AnalyticsUtility.makeFieldsMetaDataJson(headers,adjMap);
//        System.assertEquals(1,fm.size());
//        String standardName=AnalyticsUtility.getStandardName('Test Label');
//        System.assertNotEquals('',standardName);
//        Blob metaBlob=AnalyticsUtility.queryMetaDataJson('TestDataset');
//        System.assertNotEquals(null,metaBlob);
//        String metaJson=AnalyticsUtility.buildMetadataJson(fm,'Test Label','TestDataset');
//        System.assert(metaJson.contains('TestDataset'));
//        List<String>rows=AnalyticsUtility.splitLargeCsv('"Sep, 2025",Data\nRow2');
//        System.assertEquals(2,rows.size());
//        // We don’t need to pass an existing ied...uploadHeaderToAnalytics will insert one IDIOT
//        InsightsExternalData newIed=util.uploadHeaderToAnalytics(null,'MyField');
//        System.assertNotEquals(null,newIed.Id);
//        util.uploadPartFiles('MyField\r\nvalue1',newIed);
//        util.startProcessing(newIed);
//        Test.stopTest();
//        // action field has gotta be on Process by now.
//        InsightsExternalData check=[SELECT Action FROM InsightsExternalData WHERE Id=:newIed.Id];
//        System.assertEquals('Process',check.Action);
//    }
    /*
    List<Map<String,Object>>fieldMetas=new List<Map<String,Object>>();
    for(String col:cols.split(',')){
        Integer startSize=fieldMetas.size();
        for(String key:formatMap.keySet()){
            if(formatMap.get(key).get('name')==col){
                fieldMetas.add(formatMap.get(key));
            }
        }
        if(fieldMetas.size()==startSize){
            fieldMetas.add(new Map<String,Object>{'type'=>'Text','label'=>col,'name'=>col,'fullyQualifiedName'=>col});
        }
    }
    Map<String,Object>metadataJson=new Map<String,Object>{
            'fileFormat'=>new Map<String,Object>{
                    'charsetName'=>'UTF-8','fieldsDelimitedBy'=>','
            },
            'objects'=>new List<Object>{
                    new Map<String,Object>{
                            'connector'=>datasetName+'CSVConnector','fullyQualifiedName'=>datasetName,
                            'label'=>datasetName,'name'=>datasetName,'fields'=>fieldMetas
                    }
            }
    };
    System.debug(JSON.serializePretty(metadataJson));
    InsightsExternalData ied=new InsightsExternalData();
    ied.Format='Csv';
    ied.OPERATION='Overwrite';
    ied.EdgemartAlias=datasetName;
    ied.EdgemartLabel=datasetName;
    ied.MetadataJson=Blob.valueOf(JSON.serialize(metadataJson));
    insert ied;
    ied=[SELECT Id,Format,Operation,EdgemartAlias,EdgemartLabel,EdgemartContainer FROM InsightsExternalData WHERE Id=:ied.Id];
    System.debug('ied='+ied);
    String csvStr=cols+'\n'+'1501104,2025-09-09T02:43:23.501Z,00QR700000PR4KCMA1,15344831,Outbound,Outbound - Cold Calling,Outbound,[None],Alan Vervaecke,4026077007,4022906631,Open,Operator Intercept,Operator Intercept,0.00,0.0125,0,0,,,,24,,,,,,,,0.000,0.000,,,,1,0,0,,,,,,,0,0,0,,[None],SF - Nebraska - Lower Platte - 2025,SF - Nebraska - Lower Platte - 2025,Outbound - Cold Calling,1,ld_sip_sbc_sonus,Operator Intercept,0,1,0,,30AAD4C80AE0409482C1A36B19399D77';
    csvStr = csvStr.replace('\uFEFF','');

    Blob csvBlob = Blob.valueOf(csvStr);
    // Step 2: Base64 encode it
    String base64Str = EncodingUtil.base64Encode(csvBlob);

    // Step 3: Convert base64 string → Blob (this goes into DataFile)
    Blob dataBlob = Blob.valueOf(base64Str);

    InsightsExternalDataPart part = new InsightsExternalDataPart(
            InsightsExternalDataId = ied.Id,
            DataFile = dataBlob,
            PartNumber=1
    );
    insert part;
    ied.Action='Process';
    update ied;
         */
}