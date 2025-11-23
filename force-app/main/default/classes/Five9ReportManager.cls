/**
 * Created by Ben on 9/5/2025.
 */

global class Five9ReportManager implements Queueable,Database.AllowsCallouts{// so this will call the first 2 methods, there will be a delay, the 3rd will
    public reportRunner runner{get;set;}
    public AnalyticsUtility uploader{get;set;}
    public Integer polls{get;set;}
    public String reportId{get;set;}
    public Id iedId{get;set;}
//  THE ONLY CLASS VARIABLES THAT SURVIVE THE POLLING CALLS ARE reportId&uploader...put stuff to use later in uploader class for storage
    //only for creating
    //FLEX Create
    public Five9ReportManager(Datetime endTime,Datetime startTime,String folderName,String reportName,String datasetName,String datasetLabel,String datasetApp,String operation,Map<String,Map<String,Object>>adjMap,List<String>headers,String orderedCol,Integer minuteInterval){
        System.debug('\nFive9ReportManager Constructor #1[2 - FLEX](createNewDataset) Start Values...\n\tendTime='+endTime+'\n\tstartTime='+startTime+'\n\tfolderName='+folderName+'\n\treportName='+reportName+'\n\tdatasetName='+datasetName+'\n\tdatasetLabel='+datasetLabel+'\n\tdatasetApp='+datasetApp+'\n\theaders='+headers+'\n\tadjMap=\n'+JSON.serialize(adjMap));
        this.runner=new reportRunner(endTime,startTime,folderName,reportName);
        InsightsExternalData ied=AnalyticsUtility.createNewDataset(datasetName,datasetLabel,datasetApp,operation);
        Map<String,String>aliasMap=AnalyticsUtility.takeAliasesFromStartAdjMap(adjMap);
        adjMap=AnalyticsUtility.ConsolidateAdjMaps(adjMap,labelMap,headers,aliasMap);
        IntegratedDatasetConfig__c idc=new IntegratedDatasetConfig__c(
                DatasetName__c=ied.EdgemartAlias,Columns__c=JSON.serialize(headers),
                Alias_Storage__c=JSON.serialize(aliasMap),Runner__c=JSON.serialize(this.runner),
                OrderedColumn__c=orderedCol,MinuteInterval__c=minuteInterval,
                Weekdays_Running__c=String.join(AnalyticsUtility.weekdays,';'),
                LastRunTime__c=System.now(),NextRunTime__c=System.now().addMinutes(minuteInterval),
                DailyStartTime__c=Time.newInstance(0,0,0,0),
                DailyEndTime__c=Time.newInstance(23,59,59,999),
                MetadataJson__c=AnalyticsUtility.getMetadataJson(ied.EdgemartLabel,ied.EdgemartAlias,headers,adjMap)
        );
        ied.MetadataJson=Blob.valueOf(idc.MetadataJson__c);
        this.uploader=new AnalyticsUtility(ied,adjMap,idc,aliasMap);
        System.debug('\n\tConstructor#1 runner:\n'+JSON.serializePretty(this.runner)+'\n\tConstructor#1 uploader:\n'+JSON.serializePretty(this.uploader)+'\n');
    }
    //NEW WORKFLOW for updates: you have to insert a new ied every time so you have to save the metadatajson to idc at creation.
    //      We can copy fields(not metadatajson after 2weeks)into the ied from there though&insert in the uploader step.
    //DATASET UPDATING CONSTRUCTOR(QUERY PREVIOUS IED(no more metadatajson),grab operation.),CHANGING METADATA(MUST BE WITHIN 2 WEEK)
    public Five9ReportManager(Datetime endTime,Datetime startTime,String folderName,String reportName,String datasetName,String operation,Map<String,Map<String,Object>>adjMap,String orderedCol,Integer minuteInterval){
        System.debug('\nFive9ReportManager Constructor #1[3 - UPDATE](updateOldDataset) Start Values...\n\tendTime='+endTime+'\n\tstartTime='+startTime+'\n\tfolderName='+folderName+'\n\treportName='+reportName+'\n\toperation='+operation+'\n\tdatasetName=\n'+datasetName+'\n\tadjMap=\n'+JSON.serialize(adjMap));
        //QUERY PREVIOUS IED&IDC
        InsightsExternalData ied=AnalyticsUtility.queryDataset(datasetName);
        ied=AnalyticsUtility.updateOldDataset(ied,operation);
        System.debug('ied queryCheck: '+ied);
        //SET INDEPENDENT IDC FIELDS
        IntegratedDatasetConfig__c idc=AnalyticsUtility.queryDatasetConfig(ied.Id);
        idc.MinuteInterval__c=(minuteInterval??idc.MinuteInterval__c);
        idc.DatasetName__c=(datasetName??idc.DatasetName__c);
        idc.OrderedColumn__c=(orderedCol??idc.OrderedColumn__c);
        //UPDATE ALIASMAP & ASSIGN TO IDC BEFORE ADJMAP CONSOLIDATION
        List<String>headers=AnalyticsUtility.extractHeadersFromConfigColumns(idc.Columns__c);
        Map<String,String>aliasMap=AnalyticsUtility.refreshAliasStorage(AnalyticsUtility.takeAliasesFromStartAdjMap(adjMap),idc.Alias_Storage__c);
        idc.Alias_Storage__c=JSON.serialize(aliasMap);
        //CONSOLIDATE ADJMAP & MAKE METADATAJSON
        adjMap=AnalyticsUtility.ConsolidateAdjMaps(adjMap,labelMap,headers,aliasMap);
        idc.MetadataJson__c=AnalyticsUtility.getMetadataJson(ied.EdgemartLabel,ied.EdgemartAlias,headers,adjMap);
        ied.MetadataJson=Blob.valueOf(idc.MetadataJson__c);
        //CONSTRUCT RUNNER & ASSIGN TO IDC, UPDATE IDC RUN SCHEDULE FIELDS
        this.runner=new reportRunner(endTime,startTime,folderName,reportName);
        System.debug('old runner:\n'+idc.Runner__c+'\nnew runner:'+JSON.serialize(this.runner)+'\n');
        idc.Runner__c=JSON.serialize(this.runner);
        idc.LastRunTime__c=System.now();
        idc.NextRunTime__c=idc.LastRunTime__c.addMinutes(idc.MinuteInterval__c.intValue());
        //CONSTRUCT UPLOADER
        this.uploader=new AnalyticsUtility(ied,adjMap,idc,aliasMap);
    }
    //NEW PIGGYBACK CONSTRUCTOR(QUERY PREVIOUS IED, NO CHANGING METADATA)
    public Five9ReportManager(Id iedId){        //QUERY PREVIOUS IED&IDC
        if(iedId!=null&&iedId.toString().left(3)=='06V'){
            InsightsExternalData ied=AnalyticsUtility.queryDataset(iedId);
            IntegratedDatasetConfig__c idc=AnalyticsUtility.queryDatasetConfig(iedId);
            System.debug('\nFive9ReportManager Constructor #1[4 - PIGGYBACK](updateOldDataset) Start Values...\n\tidc='+JSON.serializePretty(idc)+'\n\tied'+JSON.serializePretty(ied));
            //CONSTRUCT RUNNER & ASSIGN TO IDC, UPDATE IDC RUN SCHEDULE FIELDS
            this.runner=new reportRunner((reportRunner)JSON.deserialize(idc.Runner__c,reportRunner.class));
            System.debug('new idc.LastRunTime: '+idc.LastRunTime__c+'\nold runner:\n'+idc.Runner__c+'\nnew runner:'+JSON.serialize(this.runner)+'\n');
            idc.Runner__c=JSON.serialize(this.runner);
            idc.LastRunTime__c=System.now();
            idc.NextRunTime__c=idc.LastRunTime__c.addMinutes(idc.MinuteInterval__c.intValue());
            this.uploader=new AnalyticsUtility(ied,null,idc,AnalyticsUtility.refreshAliasStorage(new Map<String,String>(),idc.Alias_Storage__c));
        }
    }
    //POLLING ONLY CONSTRUCTOR(LIGHTWEIGHT)
    public Five9ReportManager(String reportId,AnalyticsUtility uploader,reportRunner runner){ //POLLING STATION
        this.reportId=reportId; // this is the constructor for repolling;
        this.uploader=uploader;
        this.runner=runner;
        System.debug('Five9ReportManager Constructor #2 Finished...');
    }
    //ENDPOLLING CONSTRUCTOR(POST UPLOAD) -->Eventually reschedule out of this too. Especially if we double barrel
    public Five9ReportManager(Id iedId,reportRunner runner){ //put the next launch time here, any other params to pass the scheduling class constructor the variables we can skip if we're doing the same,
        this.iedId=iedId;
        this.runner=runner;
    }
/*
    make decisions on which mgr constructor we start on.
    if(ied==null)-->    CREATE #1 (endStamp,startStamp,folderName,reportName,datasetName,datasetLabel,datasetApp,adjMap,cols));
    if unexpected-->    FLEX   #2 (endStamp,startStamp,folderName,reportName,datasetName,datasetLabel,datasetApp,'Upsert',adjMap,cols));
    if for tweaks-->    UPDATE #3 (endStamp,startStamp,folderName,reportName,datasetName,operation,adjMap));
    if alls good --> PIGGYBACK #4 (endStamp,startStamp,folderName,reportName,datasetName));
*/
    global void execute(QueueableContext qc){ System.debug('––—Five9ReportManager-EXECUTE–START—–>\n');
        if(this.runner!=null){
            this.reportId=this.runner.runReport();
            System.debug('\nTOP EXECUTE, (running instance)this —> \n'+JSON.serializePretty(this));
            if(this.reportId!=null){
                Five9ReportManager mgr=new Five9ReportManager(this.reportId,this.uploader,this.runner);
                mgr.polls=0; //BEGINNING OF POLLING LOOP
                System.debug('\n\n\t—BEGINNING-OF–POLLING-LOOP–>\n\n');
                System.enqueueJob(new reportPoller(mgr));
            } else { System.assertNotEquals(null,this.reportId,'\n\n\t–—QUEUEABLE-CHAIN-TERMINATED—->\n\nYou didn\'t get a reportId.\n'+JSON.serializePretty(this)); }
        }
    }
    public class reportRunner{
        private String endGmtStr;
        private String startGmtStr;
        private String folderName;
        private String reportName;
        public reportRunner(Datetime endTime,Datetime startTime,String folderName,String reportName){
            this.endGmtStr=AnalyticsUtility.makeFormatGmtStr(endTime);
            this.startGmtStr=AnalyticsUtility.makeFormatGmtStr(startTime);
            this.folderName=folderName;
            this.reportName=reportName;
        }
        public reportRunner(reportRunner runnerPrev){
            this.startGmtStr=runnerPrev.endGmtStr;
            this.endGmtStr=AnalyticsUtility.makeFormatGmtStr(System.now());
            System.debug('reportRunner consumption constructor result: \n\tnewStart='+this.startGmtStr+'\n\tthis.endGmtStr='+this.endGmtStr);
            this.folderName=runnerPrev.folderName;
            this.reportName=runnerPrev.reportName;
        }
        public String runReport(){
            try { return Five9ReportRetriever.runReportRequest(this.endGmtStr,this.startGmtStr,this.folderName,this.reportName);
            } catch(Exception e){ throw e; }
        }
    }
    global class reportPoller implements Queueable,Database.AllowsCallouts{
        private Five9ReportManager mgr;
        global reportPoller(Five9ReportManager mgr){
            this.mgr=mgr;
        }
        global void execute(QueueableContext qc){ this.mgr.polls++;
            System.debug('\n\t\t—POLL-#'+this.mgr.polls+'–>\n');
            //FIRST OPERATION...poll Five9Reporting
            if(Five9ReportRetriever.isReportRunningRequest(this.mgr.reportId)){ System.enqueueJob(new reportPoller(this.mgr),1);
                System.debug('—RE-QUEUEING–>'); //SELF-REQUEUEING AFTER 1 MINUTE
            } else { System.enqueueJob(new reportRetriever(this.mgr));
                System.debug('\n\t——FINISHED-reportPoller–—>\n\t——ENQUEUE–reportRetriever—–>\n');
            }
        }
    }
    global class reportRetriever implements Queueable,Database.AllowsCallouts{
        private Five9ReportManager mgr;//        public Map<String,Map<String,Object>>adjNameSwapMap;//        public List<Map<String,Object>>indexedNameSwaps;
        public List<String>nameHeaders;
        global reportRetriever(Five9ReportManager mgr){
            this.mgr=mgr;
            System.debug('Five9ReportManager.reportRetriever Constructor Finished...');
        }
        public void nameSwapper(List<String>headers){ // this doesnt accomplish anything but its hard to remove.
            this.nameHeaders=new List<String>();
            for(String header:headers){
                System.debug('reportRetriever nameswapper: CSV@(row[0],col['+headers.indexOf(header)+']) = '+header+' ... ');//this.mgr.uploader.AdjMap.get(header)//                Map<String,Object>swapMap=new Map<String,Object>();
                this.nameHeaders.add(AnalyticsUtility.getStandardName(header));
            }
        }
        global void execute(QueueableContext qc){
            System.debug('Five9ReportManager.reportRetriever execute Start...');
            String csv=Five9ReportRetriever.getReportResultCsvRequest(this.mgr.reportId);
            if(csv!=null){ //this.mgr.uploader.datasetRowTerminator=AnalyticsUtility.getDatasetRowTerminator(this.mgr.uploader.ied.MetadataJson.toString());
                String rowBreaker='\n';
                if(csv.substringBefore('\n').right(1)=='\r'){ rowBreaker='\r\n'; }
                System.debug('reportRetriever.execute: this.mgr.uploader.ied.MetadataJson=\n'+this.mgr.uploader.ied.MetadataJson.toString()+'\n\n');
                System.debug('reportRetriever.execute: this.mgr.uploader.AdjMap=\n'+JSON.serialize(this.mgr.uploader.AdjMap)+'\n\n');
                List<String>firstRow=csv.substringBefore(rowBreaker).split(',');
                List<Map<String,Object>>fieldMetas;
                if(this.mgr.uploader.AdjMap==null&&this.mgr.uploader.ied.MetadataJson!=null){ fieldMetas=AnalyticsUtility.extractFieldMetas(this.mgr.uploader.ied.MetadataJson.toString());
                } else { fieldMetas=AnalyticsUtility.makeFieldsMeta(firstRow,this.mgr.uploader.AdjMap); }
                System.debug('\nreportRetriever.execute: fieldMetas=\n'+JSON.serialize(fieldMetas)+'\n\nreportRetriever.execute: firstRow=\n'+JSON.serialize(firstRow)+'\n\n');
                System.debug('this.mgr.uploader.AliasMap=\n'+JSON.serializePretty(this.mgr.uploader.AliasMap));
                for(String aliasKey:this.mgr.uploader.AliasMap.keySet()){ //fieldMetas are already abiding by adjMap specs, so we only gotta change the csv Headers that match
                    if(firstRow.contains(aliasKey)){ firstRow.set(firstRow.indexOf(aliasKey),this.mgr.uploader.AliasMap.get(aliasKey));
                        System.debug('Switching csvHeader#'+firstRow.indexOf(aliasKey)+' —> '+aliasKey+', with —> '+this.mgr.uploader.AliasMap.get(aliasKey));
                    }
                }
                System.debug('reportRetriever.execute: relabeledFirstRow=\n'+JSON.serialize(firstRow)+'\n\n');
                if(checkCsvHeaders(firstRow,fieldMetas,this.mgr.uploader.AliasMap)){ System.debug('—–reportRetriever—–> csv & header checks passed ... this.mgr.uploader.ied.Id='+this.mgr.uploader.ied.Id);
                    nameSwapper(firstRow);
                    System.debug('\treportRetriever class variable map check...\n\nthis.nameHeaders: '+JSON.serializePretty(this.nameHeaders));//\nthis.adjNameSwapMap: '+JSON.serialize(this.adjNameSwapMap)+'\n\nthis.indexedNameSwaps: '+this.indexedNameSwaps
//                    csv=String.join(this.nameHeaders,',')+'\n'+csv.substringAfter('\n');
//                    List<String>rows=AnalyticsUtility.splitLargeCsv(csv);
//                    System.assert(!rows.isEmpty(),'We received no csv data. Change the hours in your criteria.');
//                    System.debug('CSV.row count='+rows.size()+' ... \n—Rows[0-1]–>\n'+rows[0]+'\n'+rows[1]);
                    List<String>rows=reformatRows(this.nameHeaders,AnalyticsUtility.splitLargeCsv(String.join(this.nameHeaders,',')+'\n'+csv.substringAfter('\n')));
                    System.debug('\nFive9ReportManager: Post-Reformat HEADER Check ...\n\tHEADER='+rows[0]+'\nROWS[1]->\n'+rows[1]+'ROWS[last]->\n'+rows[rows.size()-1]+'\n');
                    System.debug('lastrow time='+rows[rows.size()-1].split(',')[1]);
                    System.enqueueJob(new analyticsUploader(this.mgr.uploader.ied,rows,this.mgr.uploader.idc,this.mgr.runner));
                } else {
                    System.debug('\n\n\t—–CUTTING-CHAIN—–> (On reportRetriever.EXECUTE) While checking csv Headers You FAILED the test!\n\t\t');
                }
            }
        }
    }
    global class analyticsUploader implements Queueable,Database.AllowsCallouts{
        public Five9ReportManager mgr;
        public analyticsUploader(InsightsExternalData ied,List<String>rows,IntegratedDatasetConfig__c idc,reportRunner runner){
            ied=insertIed(ied);
            this.mgr=new Five9ReportManager(ied.Id,runner);
            idc.InsightsExternalDataId__c=ied.Id;
            Integer critColX=(AnalyticsUtility.extractHeadersFromConfigColumns(idc.Columns__c).indexOf(idc.OrderedColumn__c));
            idc.LastRunLowestCriteria__c=rows[1].split(',')[critColX];
            idc.LastRunHighestCriteria__c=rows[rows.size()-1].split(',')[critColX];
            this.mgr.uploader=new AnalyticsUtility(idc);
            System.debug('\nied.Id='+ied.Id+'\nidc='+JSON.serializePretty(idc)+'\nthis.mgr.uploader='+this.mgr.uploader);
            doUpload(ied,rows);
            this.mgr.iedId=ied.Id;//we have to set these initials to make sure Status isn't an old errored out complete value.
            this.mgr.polls=0;
        }
        global analyticsUploader(Five9ReportManager mgr){
            this.mgr=mgr; //POLLING CONSTRUCTOR
        }
        public InsightsExternalData insertIed(InsightsExternalData ied) {
            System.debug('\n\nSTARTING ——analyticsUploader-Constructor–—>\n\t analyticsUploader.insertIed(ied)...Starting iedId: '+ied.Id+'...\n\tall fields:\n'+JSON.serialize(ied));
            if(ied.Id==null){
                insert ied;
            } else {
                InsightsExternalData nuIed=new InsightsExternalData(EdgemartAlias=ied.EdgemartAlias,EdgemartLabel=ied.EdgemartLabel,EdgemartContainer=ied.EdgemartContainer,Format='Csv',Operation=ied.Operation,NotificationSent='Always',NotificationEmail='benr@bristolwindows.org');
                nuIed.MetadataJson=ied.MetadataJson;
                System.debug('\n\tAnalyticsUploader.insertIed—>pre-Insert old ied:\n'+JSON.serialize(ied));
                System.debug('\n\tAnalyticsUploader.insertIed—>pre-Insert new ied:\n'+JSON.serialize(nuIed));
                insert nuIed;
                ied=nuIed;
                System.debug('\n\tAnalyticsUploader.insertIed—>post-Insert new iedId:'+ied.Id);
            }
            System.debug('\n——analyticsUploader-Constructor–—>\n\tnewly inserted/updated ied...\n'+JSON.serialize(ied)+'\n');
            return ied;
        }
        public void doUpload(InsightsExternalData ied,List<String>rows) {
            AnalyticsUtility.uploadDataParts(String.join(rows,'\r\n'),ied,7000000); //~utf-8 can contain 2,500,000 to 10,000,000 chars in 10 MB
            System.debug('\n\n\t-——Uploaded–Data–Parts–—>\n\n\t–—analyticsUploader-Constructor–—>\n\nied.Id='+ied.Id);
            ied.Action='Process';
            update ied;
        }
        global void execute(QueueableContext qc){
            this.mgr.polls++;
            InsightsExternalData ied=AnalyticsUtility.queryDataset(this.mgr.iedId);
            System.debug('\n\t\t——Post-Upload-Obvservation—Poll-#'+this.mgr.polls+'–—>\n\n\t\t( ied: Status='+ied.Status+', StatusMessage='+ied.StatusMessage+')');
//            Boolean isProcessing=(!ied.Status.startsWith('Completed'));
            if(!ied.Status.startsWith('Completed')){ System.enqueueJob(new analyticsUploader(this.mgr),1);//FIRST OPERATION...polling analytics
                System.debug('—RE-QUEUEING–>\n\tied.Status='+ied.Status+'\n\this.mgr='+this.mgr); //SELF-REQUEUEING AFTER 1 MINUTE
            } else {
                System.debug('\n\t\t\t_–{{–>WE\'RE DONE SON!!_⌐-}}¬>\n');
                System.debug('Preserved Runner:\n'+this.mgr.runner); //on false, be done-->
                String jobName=ied.Operation+' '+ied.EdgemartLabel+': '+this.mgr.uploader.idc.NextRunTime__c.format('EE, M/d h:mma');
                String cron=this.mgr.uploader.idc.NextRunTime__c.format('s m H d M ? yyyy');
                System.debug('RESCHEDULING FOR '+this.mgr.uploader.idc.NextRunTime__c+' actual cronstring='+cron);
                this.mgr.uploader.idc.InsightsExternalDataId__c=ied.Id;
                upsert this.mgr.uploader.idc; //System.debug('\n\tpost-upsert...this.mgr.uploader.icd:\n'+JSON.serialize(this.mgr.uploader.idc)+'\n');
                System.schedule(jobName,cron,new Five9ReportScheduler(ied.Id)); //eventually replace above with this.
            }
        }
    }
    public static Boolean checkCsvHeaders(List<String>headers,List<Map<String,Object>>fieldMetas,Map<String,String>aliasMap){
        Boolean checkPassed=false;
        if(headers.size()==fieldMetas.size()){
            List<Boolean>headerChecks=new List<Boolean>();
            for(Integer hX=0;hX<headers.size();hX++){
                headerChecks.add(fieldMetas[hX].get('label')==headers[hX]);
            }
            if(headerChecks.contains(false)){
                List<String>badHeaders=new List<String>();
                for(Integer hX=0;hX<headerChecks.size();hX++){
                    if(!headerChecks[hX]){
                        badHeaders.add('#'+hX+',   '+headers[hX]);
                    }
                }
                System.debug('Had some mismatched Headers...\n'+String.join(badHeaders,'\n'));
            } else { checkPassed=true; }
        } else {
            if(headers.size()>fieldMetas.size()){ System.debug('—(–>( HEADER ERROR! CSV HAS HEADERS OUTSIDE FIELDMETA!)<–)—'); }
            else { System.debug('—(–>( HEADER ERROR! CSV HAS OMITTED FIELDMETA HEADERS!)<–)—'); }
        }
        return checkPassed;
    }
    public static List<String>reformatRows(List<String>headers,List<String>rows){
        System.debug('\n\t-––—[STARTING]—Five9ReportManager.reformatRows—–>\n');
        List<String>rowsReformatted=new List<String>();
        List<Integer>durIndexes=new List<Integer>();
        rows.remove(0);
        for(String durationLabel:DURATION_LABELS){
            String standardDurationName=AnalyticsUtility.getStandardName(durationLabel);
            if(headers.contains(standardDurationName)){ durIndexes.add(headers.indexOf(standardDurationName)); }
        }
        List<Integer>stampIndexes=new List<Integer>();
        for(String stamp:TIMESTAMP_LABELS){
            String standardStampName=AnalyticsUtility.getStandardName(stamp);
            if(headers.contains(standardStampName)){
                stampIndexes.add(headers.indexOf(standardStampName));
            }
        }
        System.debug('\nDuration Header Indexes='+durIndexes+' ... \nStamp Header Indexes='+stampIndexes);
        for(String row:rows){
            if(row.contains('\uFEFF')){
                System.debug('FOUND A NOBREAK SPACE!!!\n'+row.replace('\uFEFF','\\[uFEFF]'));
                row=row.replace('\uFEFF','');
            }
            row=row.replaceAll('"[A-Z][a-z]{2}, ','');
            row=row.replaceAll('",',',');
            List<Object>rowVals=row.split(',');
            if(!stampIndexes.isEmpty()){
                for(Integer stampIndex:stampIndexes){
                    String formattedDate=formatDate(rowVals.get(stampIndex));
                    rowVals.set(stampIndex,formattedDate);
                }
            }
            if(!durIndexes.isEmpty()){
                for(Integer durIndex:durIndexes){
                    String formattedDuration=formatDuration(rowVals.get(durIndex));
                    rowVals.set(durIndex,formattedDuration);// System.debug('rowVals postSet(durLabel='+durLabel+', durX='+durIndex+', reformatted='+reformatted+')');
                }
            }
            rowsReformatted.add(String.join(rowVals,','));
        }
        System.debug('\n\t-––—[ENDING]—Five9ReportManager.reformatRows—–>\n\t\tPrejoined reformatted rows->\n\t\t\tFive9ReportManager.rowsReformatted[0,1,2]=\n\t\t\tRow#0'+rowsReformatted[0]+'\n\t\t\tRow#1'+rowsReformatted[1]);
        List<String>returnRows=new List<String>{String.join(headers,',')};
        returnRows.addAll(rowsReformatted);
        return returnRows;
    }
    public static String formatDate(Object dString){//eventually returns timestamp as yyyy-MM-dd\'T\'hh(+5 or +6):mm:ss.SSSZ datetime string from (EEE, d MMM yyyy hh:mm:ss.SSS) formatted timestamps
        String dStr=String.valueOf(dString); // ADD 2 HOURS TO EVERYTHING BECAUSE THE DATA GETS SENT IN PACIFIC TIME
        String formatStr;
        if(dStr!=null){
            List<String>dtParts=dStr.split(' ');
            System.debug('date parts: '+dtParts+'\n');
            String reformattedDtString=dtParts[2]+'-'+AnalyticsUtility.MONTH_MAP.get(dtParts[1])+'-'+dtParts[0]+' '+dtParts[3];
            formatStr=(Datetime.valueOf(reformattedDtString).addHours(2)).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
            formatStr=formatStr.substringBefore('.')+'.'+dStr.substringAfter('.')+'Z';
        }
        return formatStr;
    }
    public static String formatDuration(Object tString){ //gets a decimal or integer value as a string for the amount of elapsed seconds represented in hh:mm:ss.SSS or mm:ss.SSS formated duration fields
        String tStr=String.valueOf(tString);
        Decimal seconds;
        if(tStr!=null){
            List<String>tps=tStr.split(':');
            if(tps.size()==3){//[hh, mm, ss.SSS]
                seconds = Decimal.valueOf(tps[2])
                        + (60*Decimal.valueOf(tps[1]))
                        + (3600*Decimal.valueOf(tps[0])
                );
                System.debug('\n\ttStr='+tString+'\n\t\tDecimal.valueOf(ss: '+tps[2]+')='+Decimal.valueOf(tps[2])+'\n\t\t(60*Integer.valueOf(mm: '+tps[1]+'))='+(60*Integer.valueOf(tps[1]))+'\n\t\t(3600*Integer.valueOf(hh: '+tps[0]+'))='+(3600*Integer.valueOf(tps[0]))+'\n\ttotal='+seconds);
            }else if(tps.size()==2){//[mm, ss.SSS]
                seconds = (Decimal.valueOf(tps[1])
                        + (60*Decimal.valueOf(tps[0])));
                System.debug('\n\ttStr='+tString+'\n\t\tDecimal.valueOf(ss.SSS: '+tps[1]+')='+Decimal.valueOf(tps[1])+'\n\t\t(60*Integer.valueOf(mm: '+tps[0]+'))='+(60*Integer.valueOf(tps[0]))+'\n\ttotal='+seconds);
            }
        }
        tStr='';
        if(seconds!=null){
            tStr=String.valueOf((seconds.stripTrailingZeros()));
        }
        return tStr;
    }
    public static final Map<String,Map<String,Object>>labelMap=new Map<String,Map<String,Object>>{ //this can go in an sobject, different records can specify different fieldmeta for
            'Disposition'=>new Map<String,Object>{'name'=>'LeadDisposition','label'=>'Lead Disposition','fullyQualifiedName'=>'Disposition'},
            'CALL ID'=>new Map<String,Object>{'type'=>'Text','label'=>'CALL ID','name'=>'CallId','fullyQualifiedName'=>'CallId'},
            'TIMESTAMP MILLISECOND'=>new Map<String,Object>{'type'=>'DateTime','format'=>'yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'','fiscalMonthOffset'=>0,'label'=>'TIMESTAMP MILLISECOND','name'=>'TimestampMillisecond','fullyQualifiedName'=>'TimestampMillisecond'},
            'BILL TIME (ROUNDED)'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'BILL TIME (ROUNDED)','name'=>'BillTimeRounded','fullyQualifiedName'=>'BillTimeRounded'},
            'CALL TIME'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'CALL TIME','name'=>'CallTime','fullyQualifiedName'=>'CallTime'},
            'HANDLE TIME'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'HANDLE TIME','name'=>'HandleTime','fullyQualifiedName'=>'HandleTime'},
            'TALK TIME'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'TALK TIME','name'=>'TalkTime','fullyQualifiedName'=>'TalkTime'},
            'MANUAL TIME'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'MANUAL TIME','name'=>'ManualTime','fullyQualifiedName'=>'ManualTime'},
            'DIAL TIME'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'DIAL TIME','name'=>'DialTime','fullyQualifiedName'=>'DialTime'},
            'PREVIEW TIME'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'PREVIEW TIME','name'=>'PreviewTime','fullyQualifiedName'=>'PreviewTime'},
            'RING TIME'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'RING TIME','name'=>'RingTime','fullyQualifiedName'=>'RingTime'},
            'IVR TIME'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'IVR TIME','name'=>'IvrTime','fullyQualifiedName'=>'IvrTime'},
            'TALK TIME LESS HOLD AND PARK'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'TALK TIME LESS HOLD AND PARK','name'=>'TalkTimeLessHoldAndPark','fullyQualifiedName'=>'TalkTimeLessHoldAndPark'},
            'HOLD TIME'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'HOLD TIME','name'=>'HoldTime','fullyQualifiedName'=>'HoldTime'},
            'PARK TIME'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'PARK TIME','name'=>'ParkTime','fullyQualifiedName'=>'ParkTime'},
            'AFTER CALL WORK TIME'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'AFTER CALL WORK TIME','name'=>'AfterCallWorkTime','fullyQualifiedName'=>'AfterCallWorkTime'},
            'QUEUE WAIT TIME'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'QUEUE WAIT TIME','name'=>'QueueWaitTime','fullyQualifiedName'=>'QueueWaitTime'},
            'TOTAL QUEUE TIME'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'TOTAL QUEUE TIME','name'=>'TotalQueueTime','fullyQualifiedName'=>'TotalQueueTime'},
            'QUEUE CALLBACK WAIT TIME'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'QUEUE CALLBACK WAIT TIME','name'=>'QueueCallbackWaitTime','fullyQualifiedName'=>'QueueCallbackWaitTime'},
            'SPEED OF ANSWER'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'SPEED OF ANSWER','name'=>'SpeedOfAnswer','fullyQualifiedName'=>'SpeedOfAnswer'},
            'TIME TO ABANDON'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'TIME TO ABANDON','name'=>'TimeToAbandon','fullyQualifiedName'=>'TimeToAbandon'},
            'RATE'=>new Map<String,Object>{'type'=>'Numeric','scale'=>4,'precision'=>18,'defaultValue'=>0,'format'=>'0.0000','label'=>'RATE','name'=>'Rate','fullyQualifiedName'=>'Rate'},
            'COST'=>new Map<String,Object>{'type'=>'Numeric','scale'=>4,'precision'=>18,'defaultValue'=>0,'format'=>'0.0000','label'=>'COST','name'=>'Cost','fullyQualifiedName'=>'Cost'},
            'LIVE CONNECT'=>new Map<String,Object>{'type'=>'Numeric','scale'=>0,'precision'=>1,'defaultValue'=>0,'format'=>'0','label'=>'LIVE CONNECT','name'=>'LiveConnect','fullyQualifiedName'=>'LiveConnect'},
            'NO PARTY CONTACT'=>new Map<String,Object>{'type'=>'Numeric','scale'=>0,'precision'=>1,'defaultValue'=>0,'format'=>'0','label'=>'NO PARTY CONTACT','name'=>'NoPartyContact','fullyQualifiedName'=>'NoPartyContact'},
            'CALLS TIMED OUT IN IVR'=>new Map<String,Object>{'type'=>'Numeric','scale'=>0,'precision'=>1,'defaultValue'=>0,'format'=>'0','label'=>'CALLS TIMED OUT IN IVR','name'=>'CallsTimedOutInIvr','fullyQualifiedName'=>'CallsTimedOutInIvr'},
            'CALLS COMPLETED IN IVR'=>new Map<String,Object>{'type'=>'Numeric','scale'=>0,'precision'=>1,'defaultValue'=>0,'format'=>'0','label'=>'CALLS COMPLETED IN IVR','name'=>'CallsCompletedInIvr','fullyQualifiedName'=>'CallsCompletedInIvr'},
            'DIAL RESULT'=>new Map<String,Object>{'type'=>'Text','label'=>'DIAL RESULT','name'=>'DialResult','fullyQualifiedName'=>'DialResult'},
            'f9_last_campaign_attempts'=>new Map<String,Object>{'type'=>'Numeric','precision'=>1,'scale'=>0,'defaultValue'=>0,'format'=>'0','label'=>'f9_last_campaign_attempts','name'=>'F9LastCampaignAttempts','fullyQualifiedName'=>'F9LastCampaignAttempts'},
            'Last_Campaign'=>new Map<String,Object>{'type'=>'Text','label'=>'Last_Campaign','name'=>'LastCampaign','fullyQualifiedName'=>'LastCampaign'},
            'f9_last_list'=>new Map<String,Object>{'type'=>'Text','label'=>'f9_last_list','name'=>'F9LastList','fullyQualifiedName'=>'F9LastList'},
            'LIST NAME'=>new Map<String,Object>{'type'=>'Text','label'=>'LIST NAME','name'=>'ListName','fullyQualifiedName'=>'ListName'},
            'SKILL'=>new Map<String,Object>{'type'=>'Text','label'=>'SKILL','name'=>'Skill','fullyQualifiedName'=>'Skill'},
            'IVR PATH'=>new Map<String,Object>{'type'=>'Text','label'=>'IVR PATH','name'=>'IvrPath','fullyQualifiedName'=>'IvrPath'},
            'DISCONNECTED FROM HOLD'=>new Map<String,Object>{'type'=>'Numeric','precision'=>1,'scale'=>0,'defaultValue'=>0,'format'=>'0','label'=>'DISCONNECTED FROM HOLD','name'=>'DisconnectedFromHold','fullyQualifiedName'=>'DisconnectedFromHold'},
            'QUEUE CALLBACK PROCESSING'=>new Map<String,Object>{'type'=>'Numeric','precision'=>1,'scale'=>0,'defaultValue'=>0,'format'=>'0','label'=>'QUEUE CALLBACK PROCESSING','name'=>'QueueCallbackProcessing','fullyQualifiedName'=>'QueueCallbackProcessing'},
            'QUEUE CALLBACK REGISTERED'=>new Map<String,Object>{'type'=>'Numeric','precision'=>1,'scale'=>0,'defaultValue'=>0,'format'=>'0','label'=>'QUEUE CALLBACK REGISTERED','name'=>'QueueCallbackRegistered','fullyQualifiedName'=>'QueueCallbackRegistered'},
            'PREVIEW INTERRUPTED BY SKILL VM'=>new Map<String,Object>{'type'=>'Numeric','precision'=>1,'scale'=>0,'defaultValue'=>0,'format'=>'0','label'=>'PREVIEW INTERRUPTED BY SKILL VM','name'=>'PreviewInterruptedBySkillVm','fullyQualifiedName'=>'PreviewInterruptedBySkillVm'},
            'PREVIEW INTERRUPTED BY CALL'=>new Map<String,Object>{'type'=>'Numeric','precision'=>1,'scale'=>0,'defaultValue'=>0,'format'=>'0','label'=>'PREVIEW INTERRUPTED BY CALL','name'=>'PreviewInterruptedByCall','fullyQualifiedName'=>'PreviewInterruptedByCall'},
            'PREVIEW INTERRUPTED'=>new Map<String,Object>{'type'=>'Numeric','precision'=>1,'scale'=>0,'defaultValue'=>0,'format'=>'0','label'=>'PREVIEW INTERRUPTED','name'=>'PreviewInterrupted','fullyQualifiedName'=>'PreviewInterrupted'},
            'CALLS'=>new Map<String,Object>{'type'=>'Numeric','precision'=>1,'scale'=>0,'defaultValue'=>0,'format'=>'0','label'=>'CALLS','name'=>'Calls','fullyQualifiedName'=>'Calls'},
            'Last_Dispo'=>new Map<String,Object>{'type'=>'Text','label'=>'Last_Dispo','name'=>'LastDispo','fullyQualifiedName'=>'LastDispo'},
            'DISPOSITION'=>new Map<String,Object>{'type'=>'Text','label'=>'DISPOSITION','name'=>'Disposition','fullyQualifiedName'=>'Disposition'},
            'Lead_Status'=>new Map<String,Object>{'type'=>'Text','label'=>'Lead_Status','name'=>'LeadStatus','fullyQualifiedName'=>'LeadStatus'},
            'DNIS'=>new Map<String,Object>{'type'=>'Text','label'=>'DNIS','name'=>'Dnis','fullyQualifiedName'=>'Dnis'},
            'ANI'=>new Map<String,Object>{'type'=>'Text','label'=>'ANI','name'=>'Ani','fullyQualifiedName'=>'Ani'},
            'email'=>new Map<String,Object>{'type'=>'Text','label'=>'EMAIL','name'=>'EMAIL','fullyQualifiedName'=>'EMAIL'},
            'CUSTOMER NAME'=>new Map<String,Object>{'type'=>'Text','label'=>'CUSTOMER NAME','name'=>'CustomerName','fullyQualifiedName'=>'CustomerName'},
            'first_name'=>new Map<String,Object>{'type'=>'Text','label'=>'First Name','name'=>'FirstName','fullyQualifiedName'=>'First Name'},
            'last_name'=>new Map<String,Object>{'type'=>'Text','label'=>'Last Name','name'=>'CustomerName','LastName'=>'LastName'},
            'AGENT'=>new Map<String,Object>{'type'=>'Text','label'=>'AGENT','name'=>'Agent','fullyQualifiedName'=>'Agent'},
            'CALL TYPE'=>new Map<String,Object>{'type'=>'Text','label'=>'CALL TYPE','name'=>'CallType','fullyQualifiedName'=>'CallType'},
            'CAMPAIGN'=>new Map<String,Object>{'type'=>'Text','label'=>'CAMPAIGN','name'=>'Campaign','fullyQualifiedName'=>'Campaign'},
            'CAMPAIGN TYPE'=>new Map<String,Object>{'type'=>'Text','label'=>'CAMPAIGN TYPE','name'=>'CampaignType','fullyQualifiedName'=>'CampaignType'},
            'CONTACT ID'=>new Map<String,Object>{'type'=>'Text','label'=>'CONTACT ID','name'=>'ContactId','fullyQualifiedName'=>'ContactId'},
            'salesforce_id'=>new Map<String,Object>{'type'=>'Text','label'=>'salesforce_id','name'=>'SalesforceId','fullyQualifiedName'=>'SalesforceId'},
            'CONTACTED'=>new Map<String,Object>{'type'=>'Numeric','scale'=>0,'precision'=>1,'defaultValue'=>0,'format'=>'0','label'=>'CONTACTED','name'=>'Contacted','fullyQualifiedName'=>'Contacted'},
            'ABANDONED'=>new Map<String,Object>{'type'=>'Numeric','scale'=>0,'precision'=>1,'defaultValue'=>0,'format'=>'0','label'=>'ABANDONED','name'=>'Abandoned','fullyQualifiedName'=>'Abandoned'},
            'HOLDS'=>new Map<String,Object>{'type'=>'Numeric','scale'=>0,'precision'=>1,'defaultValue'=>0,'format'=>'0','label'=>'HOLDS','name'=>'Holds','fullyQualifiedName'=>'Holds'},
            'PARKS'=>new Map<String,Object>{'type'=>'Numeric','scale'=>0,'precision'=>1,'defaultValue'=>0,'format'=>'0','label'=>'PARKS','name'=>'Parks','fullyQualifiedName'=>'Parks'},
            'TRANSFERS'=>new Map<String,Object>{'type'=>'Numeric','scale'=>0,'precision'=>1,'defaultValue'=>0,'format'=>'0','label'=>'TRANSFERS','name'=>'Transfers','fullyQualifiedName'=>'Transfers'},
            'SESSION ID'=>new Map<String,Object>{'type'=>'Text','label'=>'SESSION ID','name'=>'SessionId','fullyQualifiedName'=>'SessionId'},
            '3RD PARTY TALK TIME'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'3RD PARTY TALK TIME','name'=>'X3rdPartyTalkTime','fullyQualifiedName'=>'X3rdPartyTalkTime'},
            'VOICEMAILS'=>new Map<String,Object>{'type'=>'Numeric','scale'=>0,'precision'=>1,'defaultValue'=>0,'format'=>'0','label'=>'VOICEMAILS','name'=>'Voicemails','fullyQualifiedName'=>'Voicemails'},
            'VOICEMAILS RETURNED CALL'=>new Map<String,Object>{'type'=>'Numeric','scale'=>0,'precision'=>1,'defaultValue'=>0,'format'=>'0','label'=>'VOICEMAILS RETURNED CALL','name'=>'VoicemailsReturnedCall','fullyQualifiedName'=>'VoicemailsReturnedCall'},
            'VOICEMAILS HANDLED'=>new Map<String,Object>{'type'=>'Numeric','scale'=>0,'precision'=>1,'defaultValue'=>0,'format'=>'0','label'=>'VOICEMAILS HANDLED','name'=>'VoicemailsHandled','fullyQualifiedName'=>'VoicemailsHandled'},
            'VOICEMAILS HANDLE TIME'=>new Map<String,Object>{'type'=>'Numeric','scale'=>3,'precision'=>18,'defaultValue'=>0.000,'format'=>'0.000','label'=>'VOICEMAILS HANDLE TIME','name'=>'VoicemailsHandleTime','fullyQualifiedName'=>'VoicemailsHandleTime'}
    };

    public static final Set<String>TIMESTAMP_LABELS=new Set<String>{
            'TIMESTAMP MILLISECOND','TIMESTAMP'
    };
    public static final Set<String>DURATION_LABELS=new Set<String>{
            'BILL TIME (ROUNDED)','CALL TIME',
            'HANDLE TIME','TALK TIME',
            'MANUAL TIME','DIAL TIME',
            'PREVIEW TIME','RING TIME',
            'IVR TIME','TALK TIME LESS HOLD AND PARK',
            'HOLD TIME','PARK TIME',
            'AFTER CALL WORK TIME',
            'QUEUE WAIT TIME','TOTAL QUEUE TIME',
            'QUEUE CALLBACK WAIT TIME','VOICEMAILS HANDLE TIME',
            'SPEED OF ANSWER','TIME TO ABANDON',
            '3RD PARTY TALK TIME'
    };
    //i. Rerun via queue offsets, get timeframe params from a custom mdt, cmdt.schedStartTime,cmdt.schedStopTime,cmdt interval Minutes?
    //ii.Rerun via schedulable wrapper. get timeframe from the initial params. copy what you did in reciperunner & reciperunnerschedulable
}

/*
public class datasetSettings{
    String fieldsDelimitedBy;
    String linesTerminatedBy;
    Integer numberOfLinesToIgnore;
    String fullyQualifiedName;
    String name;
    String label;
    List<String>supportedTimezones;
    datasetSettings(Boolean useDefaults){
        this.fieldsDelimitedBy=',';
        this.linesTerminatedBy='\r\n';
        this.numberOfLinesToIgnore=1;
        this.supportedTimezones=new List<String>{'America/Chicago'};
    }
    private Map<String,String>populatedFieldMap(){
        Object o=this;
        String thisSrlz=JSON.serialize(this);
        Map<String,String>fMap=(Map<String,String>)JSON.deserializeUntyped(o.toString());
        System.debug('o=this ... '+o);
        System.debug('this ... '+this);
        System.debug('fMap ... '+fMap);
        System.debug('flip(fMap) ... '+AnalyticsUtility.flipMapPairs(fMap));
        System.debug('flip(flip(fMap)) ... '+AnalyticsUtility.flipMapPairs(AnalyticsUtility.flipMapPairs(fMap)));
        return AnalyticsUtility.flipMapPairs(AnalyticsUtility.flipMapPairs(fMap));
    }
}

*/
/*testDebugs---> (put into the reportRetriver class execute method)
List<Map<String,Object>>extrFieldMeta=new List<Map<String,Object>>();
Integer oX=0;
List<Object>fieldMetaObjs=(List<Object>)((Map<String,Object>)(((List<Object>)((Map<String,Object>)JSON.deserializeUntyped(this.mgr.uploader.ied.MetadataJson.toString())).get('objects'))[0])).get('fields');
for(Object fieldMetaObj:fieldMetaObjs){
    Map<String,Object>fieldMeta=(Map<String,Object>)fieldMetaObj;
    System.debug('\n\treportRetriever extrFieldMeta #'+oX+' ... \n\t\t'+JSON.serialize(fieldMeta)+'\n\t\tkeyset='+fieldMeta.keySet());
    String label='';
    if(fieldMeta.containsKey('label')){ label=fieldMeta.get('label').toString(); }
    else if(fieldMeta.containsKey('name')){ label=fieldMeta.get('name').toString(); }
    System.debug('\n\tStarting extrFieldMeta matches for '+label+'...');
    for(String key:fieldMeta.keySet()){
        Map<String,Object>thisMgrAdjMap=this.mgr.AdjMap.get(label);
        Map<String,Object>thisMgrUploaderAdjMap=this.mgr.uploader.AdjMap.get(label);
        System.debug('\n\tMatches {\n\t\t\t  extrFieldMeta.get('+key+')='+fieldMeta.get(key)+';\n\t\tmgr.uploader.AdjMap.get('+key+')='+this.mgr.uploader.AdjMap.get(key)+';\n\t\t\t\t mgr.AdjMap.get('+key+')='+thisMgrAdjMap.get(key)+'\n\t\t\t}');
    }
    extrFieldMeta.add(fieldMeta);
    oX++;

} <---testDebugs

    public void setOperationDependents(String operation,InsightsExternalData ied){
        if(operation!=null){
            if(ied==null){
                operation='Overwrite';
                this.startTime=(startTime??this.endTime.addDays(-60));
            } else {
                switch on operation.left(1).toUpperCase(){
                    when 'A'{operation='Append';}
                    when 'U'{operation='Upsert';}
                    when 'O'{operation='Overwrite';}
                    when 'D'{operation='Delete';}
                    when else {operation='Overwrite';}
                }
            }
        } else {
            if(ied!=null && (ied.Operation!=null && ied.Operation!='Delete')){
                operation=ied.Operation;
            } else { //operation param==null and ied==null, set to 'overwrite'
                operation='Overwrite';
            }
        }
        this.operation=operation;
    }
*/
/* OLD analyticsUploader Queueuable class:
global class analyticsUploader implements Queueable,Database.AllowsCallouts{
        public List<Datetime>pollTimes=new List<Datetime>();
        public List<Integer>pollDurations=new List<Integer>();//in seconds
        public analyticsUploader(InsightsExternalData ied,List<String>rows){
            System.debug('\n\nSTARTING ——analyticsUploader-Constructor–—>\n\tinitial ied='+JSON.serializePretty(ied)+'\n\n');
            if(ied.Id==null){
                insert ied;
            } else {
                update ied;//not super necessary, just so i remember what this split is
                System.debug('——analyticsUploader-Constructor–—>\n\tnewly updated mgr.uploader.ied...\n'+ied);
            }
            AnalyticsUtility.uploadDataParts(String.join(rows,'\r\n'),ied,1000000);
            System.debug('\n\n\t-——Uploaded–Data–Parts–—>\n\n\t–—analyticsUploader-Constructor–—>\n\nied.Id='+ied.Id);
            ied.Action='Process';
            update ied;     //ied=pollQueryIed(ied.Id);
            this.iedId=ied.Id;//we have to set these initials to make sure Status isn't an old errored out complete value.
            this.Status=ied.Status;
            this.polls=1;
        }
        public analyticsUploader(Id iedId,Integer polls){
            this.polls=(polls++);
            this.pollTimes.add(System.now());
            System.debug('\n\t——Constructing—Poll-#'+this.polls+'–—>');
            InsightsExternalData ied=pollQueryIed(iedId);
            this.Status=ied.Status;
            this.iedId=ied.Id;
            System.debug('\nied:\t'+JSON.serialize(ied.getPopulatedFieldsAsMap()));
        }
        global void execute(QueueableContext qc){
            System.debug('\nPost Upload Obvservation\n\t—Poll-#'+this.polls+'–—> \n');
            if(this.Status=='Completed'){
                InsightsExternalData ied=pollQueryIed(this.iedId);
                System.debug('_–{{–>WERE DONE SON!!_⌐-}}¬>'+this.Status);
            } else {
                  System.debug('...[..HAVE ANOTHER POLL..]...(Status='+this.Status+')');//all testfields
                  System.debug('Normal = System.now.getTime()='+System.now().getTime()+' pollTimes[prev].getTime()='+this.pollTimes[this.pollTimes.size()-1].getTime());
                  System.debug('subtractionTest: Times='+(System.now().getTime()-(this.pollTimes[this.pollTimes.size()-1].getTime())));
                  System.debug('d/1000 = System.now.getTime()='+(System.now().getTime()/1000)+' pollTimes[prev].getTime()='+(this.pollTimes[pollTimes.size()-1].getTime()/1000));
                  Integer durationStringValEnd=Integer.valueOf((System.now().getTime()-this.pollTimes[this.pollTimes.size()-1].getTime()).toString());
                  Integer durationStringValMid=(Integer.valueOf((System.now().getTime()).toString()) - Integer.valueOf((this.pollTimes[this.pollTimes.size()-1].getTime()).toString()));
                  Integer durationLongIntEnd=Integer.valueOf((System.now().getTime()-this.pollTimes[this.pollTimes.size()-1].getTime().intValue()).intValue());
                  Integer durationLongIntMid=Integer.valueOf((System.now().getTime().intValue()-this.pollTimes[this.pollTimes.size()-1].getTime().intValue()));
                  System.debug('POLL DURATION = '+durationStringValEnd+' Seconds...\n\t\t\ttesting ( duration='+durationStringValEnd+' / 1000 ) = '+(durationStringValEnd/1000)+' ...\n\t\t\ttesting ( (durationStringValEnd='+durationStringValEnd+' + ( 1000 - 1) ) / 1000 ) = '+((durationStringValEnd+999)/1000));
                  System.debug('POLL DURATION = '+durationStringValMid+' Seconds...\n\t\t\ttesting ( duration='+durationStringValMid+' / 1000 ) = '+(durationStringValMid/1000)+' ...\n\t\t\ttesting ( (durationStringValMid='+durationStringValMid+' + ( 1000 - 1) ) / 1000 ) = '+((durationStringValMid+999)/1000));
                  System.debug('POLL DURATION = '+durationLongIntEnd+' Seconds...\n\t\t\ttesting ( duration='+durationLongIntEnd+' / 1000 ) = '+(durationLongIntEnd/1000)+' ...\n\t\t\ttesting ( (durationLongIntEnd='+durationLongIntEnd+' + ( 1000 - 1) ) / 1000 ) = '+((durationLongIntEnd+999)/1000));
                  System.debug('POLL DURATION = '+durationLongIntMid+' Seconds...\n\t\t\ttesting ( duration='+durationLongIntMid+' / 1000 ) = '+(durationLongIntMid/1000)+' ...\n\t\t\ttesting ( (durationLongIntMid='+durationLongIntMid+' + ( 1000 - 1) ) / 1000 ) = '+((durationLongIntMid+999)/1000));
                  System.debug('\nPoll took'+'\n\t[\n\t\t\tdurationStringValEnd : '+durationStringValEnd+',\n\t\t\tdurationStringValMid : '+durationStringValMid+',\n\t\t\tdurationLongIntEnd : '+durationLongIntEnd+',\n\t\t\tdurationLongIntMid : '+durationLongIntMid+'\n\t]');
                  this.pollDurations.add(((durationStringValEnd+durationStringValMid+durationLongIntEnd+durationLongIntMid)+3)/4);
                System.enqueueJob(new analyticsUploader(this.iedId,this.polls),1);
            }
        }
        public InsightsExternalData pollQueryIed(Id iedId){
            return[SELECT Id,EdgemartAlias,Status,StatusMessage,Action,LastModifiedDate FROM InsightsExternalData WHERE (Id=:iedId OR Id=:iedId.toString() OR Id=:iedId.to15()) ORDER BY CreatedDate DESC LIMIT 1];
        }
    }

 */
//—PARSER-FIELDS–> All params needed to Transform(Read,Reformat) retrieved data
//List<String>columns=>new List<String>{'CALL ID','TIMESTAMP MILLISECOND','salesforce_id',/*...etc (retrieved header names (IN ORDER))*/}, //RETRIEVED COLUMN NAMES unaliased
//Map<String,Map<String,Object>>formats=>new Map<String,Map<String,Object>>{//ei

//Map<String,Object>formats=>new Map<String,Map<String,Object>>{/* final adjmap */},
//Map<String,String>aliases=>new Map<String,String>{/*map from retrieved column to formatted header value*/},

//'fieldFormats'=>new List<Map<String,Object>>{/* The final adjMap value on the initial run (post-consolidateMaps) */},
//'AliasMap'=>new Map<String,String>{/* The map between retrieved headers & transformed headers value on the initial run (post-consolidateMaps) */},