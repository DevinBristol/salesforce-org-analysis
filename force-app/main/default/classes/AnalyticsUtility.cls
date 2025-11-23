/**
 * Created by Ben on 9/5/2025.
 */


global with sharing class AnalyticsUtility {  //this would have to be aan interface or abstract to be useful
    public Map<String,Map<String,Object>>AdjMap; //for validation and two way parsing. Lives on this object through the chain
//    public List<String>headers{get;set;}
    public InsightsExternalData ied{get;set;}
    public IntegratedDatasetConfig__c idc{get;set;}
    public Map<String,String>AliasMap{get;set;}//works pretty well with the flipMapPairs method. Covers most cases of reformatting.
    //Constructor for Existing/Constructed IEDs to (insert first if Id==null) take Id to make&insert stack of parts
    // single update at the end covers any operation change(append,upsert,delete,overwrite) plus Action change to Processing
    public AnalyticsUtility(InsightsExternalData ied,Map<String,Map<String,Object>>adjMap,IntegratedDatasetConfig__c idc,Map<String,String>aliasMap){
        this.ied=ied;
        this.AdjMap=adjMap;
        this.idc=idc;
        this.AliasMap=aliasMap;
    }
    public AnalyticsUtility(IntegratedDatasetConfig__c idc){
        this.idc=idc; //for carrying the state of the upsert value for the very end
    }
    public static InsightsExternalData createNewDataset(String datasetName,String datasetLabel,String datasetApp,String operation){ //operation is optional
        if(datasetLabel!=null|datasetName!=null){
            if(datasetName==null&&datasetLabel!=null){ datasetName=getStandardName(datasetLabel); }
            else if(datasetLabel==null&&datasetName!=null){ datasetLabel=normalizeDatasetLabel(datasetLabel,datasetName); }
            List<InsightsExternalData>dupeIeds=[SELECT Id,EdgemartAlias,EdgemartLabel,EdgemartContainer,Operation,Action,Status,StatusMessage,CreatedDate,LastModifiedDate FROM InsightsExternalData WHERE EdgemartAlias=:datasetName ORDER BY LastModifiedDate DESC];
            if(dupeIeds.size()>0){ System.debug('\n\tYou\'re not gonna overwrite this dataset.\n\t——Duplicate–—>\n'+JSON.serialize(dupeIeds[0])+'\n\t——END–OF–CHAIN—–>'); return null;
            } else { //( we have both a dataset label & alias )AND( we have no dupe named or labeled datasets )
                return new InsightsExternalData(EdgemartAlias=datasetName,EdgemartLabel=datasetLabel,EdgemartContainer=datasetApp,Format='Csv',Operation=operation,NotificationSent='Always',NotificationEmail='benr@bristolwindows.org');
            }
        } else { System.debug('Maybe put some fucking parameters in next time.'); return null; }
    }
    public static InsightsExternalData updateOldDataset(InsightsExternalData ied,String operation){
        Boolean prevUniqueId=(ied.MetadataJson.toString()).contains('"isUniqueId":true');
        if(operation==null){
            if(prevUniqueId){ ied.Operation='Upsert'; } else { ied.Operation='Append'; }
        } else {
            ied.Operation=operation;
        }
        return ied;
    }
    public static InsightsExternalData queryDataset(String iedNameOrId){
        System.debug('datasetName='+iedNameOrId);
        String qFilter;
        if(iedNameOrId!=null){//scheduler emergency offramp

        }
        if(iedNameOrId.startsWith('06V')){
            qFilter='Id=\''+Id.valueOf(iedNameOrId)+'\'';
        } else {
            qFilter='EdgemartAlias=\''+iedNameOrId+'\'';
        }
        String queryString='SELECT Id,EdgemartAlias,EdgemartLabel,EdgemartContainer,Mode,Operation,Action,Status,StatusMessage,MetadataJson,Description,LastModifiedDate,CreatedDate,SubmittedDate FROM InsightsExternalData WHERE '+qFilter+' ORDER BY LastModifiedDate DESC';
        List<InsightsExternalData>ieds=Database.query(queryString);
        InsightsExternalData returnIed;
        if(!ieds.isEmpty()){
            returnIed=ieds[0];
        }
        return returnIed;
    }
    public static IntegratedDatasetConfig__c queryDatasetConfig(String iedId){
        System.debug('queryDatasetConfig: iedId='+iedId);
        return [SELECT Id,InsightsExternalDataId__c,DatasetName__c,MetadataJson__c,
                Alias_Storage__c,Runner__c,Columns__c,OrderedColumn__c,OrderedColumnDirection__c,
                LastRunTime__c,NextRunTime__c,LastRunHighestCriteria__c,LastRunLowestCriteria__c,
                AllRunsHighestCriteria__c,AllRunsLowestCriteria__c,MinuteInterval__c,Weekdays_Running__c
        FROM IntegratedDatasetConfig__c WHERE (InsightsExternalDataId__c=:iedId) ORDER BY CreatedDate LIMIT 1];
    }
    public static void uploadDataParts(String csv,InsightsExternalData ied,Integer maxChunkChars){
        System.debug('\n\t\t-––—AnalyticsUtility—uploadDataParts—–> \n\t\t\tPre-Upload CSV Check...\n\tHEADER='+csv.substringBefore('\n')+'\n\t1stROW='+(csv.substringAfter('\n')).substringBefore('\n'));
        List<InsightsExternalDataPart>parts=makeExternalDataParts(ied.Id,csv,maxChunkChars);
        System.debug('\n\t\t-––—AnalyticsUtility—uploadDataParts—–> \n\t\t\t[ Operation='+ied.Operation+', # of Parts='+ied.ExternalDataIds.size()+'\n\tCurrent ied values( Action='+ied.Action+', Status='+ied.Status+', StatusMessage='+ied.StatusMessage+', SubmittedDate='+ied.SubmittedDate+', CreatedDate='+ied.CreatedDate+', LastModifiedDate='+ied.LastModifiedDate+' )\n]');
        insert parts;
        System.debug('\n\t new Parts: '+JSON.serialize(parts));
    }
    public static List<String>extractHeadersFromConfigColumns(String columnsJson){
        List<String>headers=new List<String>();
        for(Object o:(List<Object>)JSON.deserializeUntyped(columnsJson)){
            headers.add(String.valueOf(o));
        }
        return headers;
    }
    public static Map<String,String>takeAliasesFromStartAdjMap(Map<String,Map<String,Object>>startAdjMap){
        Map<String,String>aliasMap=new Map<String,String>();
        for(String adjKey:startAdjMap.keySet()){ //this is only collecting from the selective param adjMap
            if(startAdjMap.get(adjKey).containsKey('label')){
                aliasMap.put(adjKey,startAdjMap.get(adjKey).get('label').toString());
            }
        }
        return aliasMap;
    }
    public static Map<String,String>refreshAliasStorage(Map<String,String>newAliasMap,String idcStoredAliases){
        Map<String,String>storageMap=new Map<String,String>();
        if(idcStoredAliases!=null&&idcStoredAliases!=''){
            Map<String,Object>pulledMap=((Map<String,Object>)JSON.deserializeUntyped(idcStoredAliases));
            System.debug('—AliasInventoryManager–>refreshAliasStorage: pulled AliasMap...\n'+JSON.serializePretty(pulledMap));
            for(String key:pulledMap.keySet()){
                storageMap.put(key,pulledMap.get(key).toString());
            }
        }
        for(String newAlias:newAliasMap.keySet()){ //for now just overwrite them and see what happens
            System.debug('\trefreshAliasStorage: putting "'+newAlias+'" into storageMap');
            storageMap.put(newAlias,newAliasMap.get(newAlias));
        }
        System.debug('—AliasInventoryManager–>refreshAliasStorage: storageMap(new aliasMap put into pulledMap)...\n'+JSON.serializePretty(storageMap));
        return storageMap;
    }
    public static Map<String,String>flipMapPairs(Map<String,String>flippableMap){
        Map<String,String>flippedMap=new Map<String,String>();
        for(String flipKey:flippableMap.keySet()){
            flippedMap.put(flippableMap.get(flipKey),flipKey);
        }
        return flippedMap;
    }
    public static Map<String,Map<String,Object>>ConsolidateAdjMaps(Map<String,Map<String,Object>>adjMap,Map<String,Map<String,Object>>defaultLabelMap,List<String>headers,Map<String,String>manualRelabels){
        Map<String,Map<String,Object>>returnAdjMap=new Map<String,Map<String,Object>>();
        if(adjMap!=null&&adjMap.size()>0){
            System.debug('\n\n—START–>AnalyticsUtility.ConsolidateAdjMaps...\n\t\tadjMap(keyset.size='+adjMap.keySet().size()+')\n\t\tdefaultLabelMap(keyset.size='+defaultLabelMap.keySet().size()+')\n\t\theaders(size='+headers.size()+')\n\nStarting adjMap=\n'+JSON.serialize(adjMap)+'\n\nStarting defaultLabelMap=\n'+JSON.serialize(defaultLabelMap)+'\n\nStarting headers=\n'+JSON.serialize(headers)+'\n\n');
            adjMap=mergeMaps(adjMap,defaultLabelMap);
            System.debug('adjMap(merged): '+JSON.serialize(adjMap));
            returnAdjMap=filterMapToMatchKeyList(adjMap,headers,manualRelabels);
            System.debug('returnAdjMap: '+JSON.serialize(returnAdjMap));
        } else { returnAdjMap=filterMapToMatchKeyList(defaultLabelMap,headers,manualRelabels);
            System.debug('PROBLEM CHECK ON Reschedule F9Manager Constructor-->PreExecutor...\nConsolidateAdjMaps params...\nheaders='+headers+'\nmanualRelabels='+manualRelabels);
            System.debug('returnAdjMap: '+JSON.serialize(returnAdjMap));
        }
        System.debug('\n\tmanualRelabels: '+JSON.serializePretty(manualRelabels));
        for(String header:returnAdjMap.keySet()){
            Map<String,Object>keyMetaMap=returnAdjMap.get(header);//adjMap.get(header);
            System.debug('header='+header+'...'+returnAdjMap.get(header));
            keyMetaMap.putAll(returnAdjMap.get(header));
            System.debug('header='+header+'\tcurrent keyMetaMap='+JSON.serialize(keyMetaMap));
            if(!keyMetaMap.containsKey('label')){ keyMetaMap.put('label',header); }
            if(!keyMetaMap.containsKey('name')){ keyMetaMap.putAll(new Map<String,Object>{'name'=>getStandardName(header),'fullyQualifiedName'=>getStandardName(header)}); }
            returnAdjMap.put(header,keyMetaMap);
        }
        System.debug('—END–>AnalyticsUtility.ConsolidateAdjMaps...\n\t\treturnAdjMap should have standard Names&Labels now...\nreturnAdjMap=\n'+JSON.serialize(returnAdjMap));
        return returnAdjMap;
    }
    public static List<Map<String,Object>>extractFieldMetas(String metadataJson){
        List<Map<String,Object>>fieldMetas=new List<Map<String,Object>>();
        for(Object o:(List<Object>)((Map<String,Object>)((List<Object>)((Map<String,Object>)JSON.deserializeUntyped(metadataJson.toString())).get('objects'))[0]).get('fields')){
            fieldMetas.add((Map<String,Object>)o);
        }
        return fieldMetas;
    }
    public static Map<String,Map<String,Object>>filterMapToMatchKeyList(Map<String,Map<String,Object>>unfilteredMap,List<String>headers,Map<String,String>altMap){
        Map<String,Map<String,Object>>filteredMap=new Map<String,Map<String,Object>>(); //also filters down to fields we can find meta for
        altMap=flipMapPairs(altMap);
        System.debug('using flipped altMap:'+JSON.serializePretty(altMap));
        System.debug('unfiltered adjMap keyset='+unfilteredMap.keySet());
        for(String header:headers){
            System.debug('\t\tfilterMapToMatchKeyList cur header: '+header);
            if(altMap.containsKey(header)){
                header=altMap.get(header);
                System.debug('altKey found: '+unfilteredMap.get(header));
            }
            filteredMap.put(header,unfilteredMap.get(header));
        }
        return filteredMap;
    }
    public static List<String>splitLargeCsv(String csv){ // has to also remove/reformat away extra delimeters per row.
        String rowDelimiter='\n';
        csv=csv.trim();
        System.debug('\n\t\t-––—AnalyticsUtility.splitLargeCsv—–>\n\t');
        if(csv.substringBefore('\n').right(1)=='\r'){
            rowDelimiter='\r\n';
        }
        List<String>rows=new List<String>();//data too big for a .split('\n') or any other regex-based method so gotta do something else
        while(csv.length()>0){
            if(csv.contains(rowDelimiter)){
                String row=(csv.substringBefore(rowDelimiter));
                rows.add(row.trim());
                csv=csv.substringAfter(rowDelimiter);
            } else {
                if(csv.trim()==''||csv.trim().length()==0) {
                    System.debug('last row not adding. Check this weird remainder out though ... \n'+csv);
                } else {
                    rows.add(csv);
                    csv='';
                }
            }
        }
        return rows;
    }
    public static List<Map<String,Object>>makeFieldsMeta(List<String>headers,Map<String,Map<String,Object>>adjMap) {
        System.debug('AnalyticsUtility: makeFieldsMeta\n\t(headers)='+headers+'\n\t(adjMap)\n'+JSON.serializePretty(adjMap));
        List<Map<String,Object>>fieldsMetaData=new List<Map<String,Object>>();
        for (String header:headers){ //csv headers updated to match names, this is after
            if(adjMap.containsKey(header)){
                fieldsMetaData.add(adjMap.get(header));
            } else {
                System.debug('NO EXISTING METADATA FOUND FOR HEADER '+header);
            }
        }
        return fieldsMetaData;
    }
    public static String getMetadataJson(String datasetLabel,String datasetName,List<String>headers,Map<String,Map<String,Object>>adjMap){
        System.debug('finished adjMap=\n'+JSON.serializePretty(adjMap));
        Map<String,Object>metadata=new Map<String,Object>{
                'fileFormat'=>new Map<String,Object>{'charsetName'=>'UTF-8','fieldsDelimitedBy'=>',','linesTerminatedBy'=>'\r\n','numberOfLinesToIgnore'=>1},
                'timezoneInfo'=>new Map<String,Object>{'sourceTimezone'=>'GMT','supportedTimezones'=>new List<String>{'America/Chicago'}},
                'objects'=>new List<Object>{
                        new Map<String,Object>{'connector'=>'CSV',
                                'fullyQualifiedName'=>datasetName,'label'=>datasetLabel,'name'=>datasetName,
                                'fields'=>makeFieldsMeta(headers,adjMap)
                        }
                }
        };
        String metaDataJsonStr=JSON.serialize(metadata);
        System.debug('\n\nAnalyticsUtility: getMetadataJson —returning–>\n'+metaDataJsonStr);
        return metaDataJsonStr;
    }
    public static List<InsightsExternalDataPart>makeExternalDataParts(Id iedId,String csv,Integer maxChunkChars){
        Integer chunkMax=(maxChunkChars??8000000);String f='\n\t\t'+'_'.repeat(9)+'\n';
        Integer bytesMax=10000000;//10Million / 10 MB
        Integer csvStartChars=csv.length();
        Integer csvStartBytes=Blob.valueOf(csv).size();
        System.debug(f+'\t| STARTING | makeExternalDataParts ...\n\t\tExpected Loads: ( csvStartChars: '+csvStartChars+' / chunkMax: '+chunkMax+' ) = '+((csvStartChars+(chunkMax-1))/chunkMax)+' Loads.\n\n');
        System.debug('\n\t|_BYTESIZE_|  makeExternalDataParts...\n\t\tExpected Loads: ( csvStartBytes: '+csvStartBytes+' / bytesMax: '+bytesMax+' ) = '+((csvStartBytes+(bytesMax-1))/bytesMax)+' Loads.\n\n');
        List<InsightsExternalDataPart>parts=new List<InsightsExternalDataPart>();
        List<List<Integer>>partStartsAndStops=new List<List<Integer>>();
        List<Integer>partLengths=new List<Integer>();
        List<Integer>partBlobSizes=new List<Integer>();
        Integer pX=0;
        String chunk;
        while(csv.length()>chunkMax){ pX++;
            List<Integer>partStartStop=new List<Integer>{pX,csvStartChars-csv.length()};
            chunk=csv.substring(0,chunkMax);
            chunk=chunk.substringBeforeLast('\r\n');
            csv=csv.substring(chunk.length());
            partStartStop.add(csvStartChars-csv.length());
            parts.add(new InsightsExternalDataPart(PartNumber=pX,InsightsExternalDataId=iedId,DataFile=Blob.valueOf(chunk)));
            partLengths.add(chunk.length());
            partBlobSizes.add(Blob.valueOf(chunk).size());
            partStartsAndStops.add(partStartStop);
        }
        if(csv.length()>0){ pX++;
            chunk=csv;
            partLengths.add(chunk.length());
            partBlobSizes.add(Blob.valueOf(chunk).size());
            partStartsAndStops.add(new List<Integer>{pX,csvStartChars-csv.length(),csvStartChars});
            csv='';
            parts.add(new InsightsExternalDataPart(PartNumber=pX,InsightsExternalDataId=iedId,DataFile=Blob.valueOf(chunk)));
        }
        System.debug('\n\n\t——MakeExternalDataPartsRedo—–> FINAL TALLIES ...\n\t\t—–partLengths—>\n'+JSON.serializePretty(partLengths)+'\n\t\t—–partBlobSizes—>\n'+JSON.serializePretty(partBlobSizes)+'\n\t\t—–partStartsAndStops—>\n'+JSON.serializePretty(partStartsAndStops)+'\n\n');
        System.debug('\n\n\t——MakeExternalDataPartsRedo—–> DATAPARTS ...\n\n'+JSON.serializePretty(parts)+'\n\n');
        return parts;
    }
    public static String getStandardName(String label){
        String name='';
        Integer ssX=0;
        List<String>subs=(label.splitByCharacterType()??new List<String>{name});
        Boolean capLast=false;
        for(String ss:subs){
            Boolean thisCap=false;
            if(ssX>0){
                if(ss.isAlphanumeric()){
                    if(!capLast){
                        name=name+(ss.toLowerCase().capitalize());
                        thisCap=true;
                    } else { name=name+ss.toLowerCase(); }
                }
            } else {
                if(ss.isAlphanumeric()){
                    if(label.left(1).isNumeric()){ name='X'+ss.toLowerCase();
                    } else {
                        name=name+ss.toLowerCase().capitalize();
                    }
                    thisCap=true;
                }
            }
            ssX++;
            capLast=thisCap;
        }
        return name;
    }
    public static String normalizeDatasetLabel(String datasetLabel,String datasetName){
        List<String>datasetLabelParts=datasetName.splitByCharacterTypeCamelCase();
        if(datasetLabel==null){
            datasetLabel='';
            for(String datasetLabelPart:datasetLabelParts){ datasetLabel=datasetLabel+' '+datasetLabelPart.capitalize(); }
            datasetLabel=datasetLabel.trim();
        }
        return datasetLabel;
    }
//    public static String getDatasetRowTerminator(String metadataJson){
//        String delimiter='\r\n';
//        Map<String,Object>fileFormat=(Map<String,Object>)((Map<String,Object>)JSON.deserializeUntyped(metadataJson)).get('fileFormat');
//        if(fileFormat.containsKey('linesTerminatedBy')){
//            delimiter=fileFormat.get('linesTerminatedBy').toString();
//        }
//        return delimiter;
//    }
    public static String makeFormatGmtStr(Datetime dt){
        String returnTime=dt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS')+'-00:00';
        return returnTime;
    }
        public static final Map<String,String>MONTH_MAP=new Map<String,String>{
            'Jan'=>'01','Feb'=>'02','Mar'=>'03','Apr'=>'04',
            'May'=>'05','Jun'=>'06','Jul'=>'07','Aug'=>'08',
            'Sep'=>'09','Oct'=>'10','Nov'=>'11','Dec'=>'12'
        };
        public static final List<String>weekdays=new List<String>{
            'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'
        };
        final Map<String,Object>META_DEFAULT=new Map<String,Object>{
            'description'=>'','isSystemField'=>false,'isUniqueId'=>false
        };
        final Map<String,Object>META_DEFAULT_NUM_INTEGER=new Map<String,Object>{
            'type'=>'Numeric','scale'=>0,'precision'=>18,'defaultValue'=>0,'format'=>'0'
        };
        public static final Map<String,Object>META_DEFAULT_NUM_DECIMAL=new Map<String,Object>{
            'type'=>'Numeric','scale'=>4,'precision'=>18,'defaultValue'=>0,'format'=>'0.00'
        };
        final Map<String,Object>META_DEFAULT_DATE=new Map<String,Object>{
            'type'=>'Date','format'=>'MM/dd/yyyy','fiscalMonthOffset'=>0
        };
        public static final Map<String,Object>META_DEFAULT_DATETIME=new Map<String,Object>{
            'type'=>'DateTime','format'=>'yyyy-MM-dd\'T\'hh:mm:ss.SSS\'Z\''
        };
        final Map<String,Map<String,Object>>META_DEFAULT_TYPES=new Map<String,Map<String,Object>>{
            'Date'=>META_DEFAULT_DATETIME,'Number'=>META_DEFAULT_NUM_DECIMAL
        };
        final Map<String,String>DATE_FORMAT_SOLVER=new Map<String,String>{
            '--\'T\'::.\'Z\''=>'yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'','-- ::.'=>'yyyy-MM-dd HH:mm:ss.SSS'
        };
    public static Map<String,Map<String,Object>>mergeMaps(Map<String,Map<String,Object>>overMap,Map<String,Map<String,Object>>underMap){
        //the overMap is the one overwriting whatever the undermap has.
        // If they match an outside key, overmap puts all its contents at that key into underMap
        // if underMap doesnt have the outside key, overMap adds a completely new Map on that key,
        // underMap is the one to return as it holds all the overwrites while retaining previous unmatched data
        Map<String,Map<String,Object>>mergedMaps=new Map<String,Map<String,Object>>(underMap);
        for(String overKey:overMap.keySet()){
            Map<String,Object>matchMap=new Map<String,Object>(underMap.get(overKey));
            matchMap.putAll(overMap.get(overKey));
            mergedMaps.put(overKey,matchMap);
        }
        return mergedMaps;
    }
//    public static Datetime getNextRescheduleTime(Datetime thisRunTime,Integer minuteInterval,Time dailyStart,Time dailyEnd,String weekdaysRunning){
//        Datetime nextRunTime;
//        if(Datetime.newInstance(System.today(),dailyEnd)<thisRunTime.addMinutes(minuteInterval)){
//            List<String>weekdays=new List<String>{'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'};
//            Integer addDays=0;
//            List<String>selectedWeekdays=weekdaysRunning.split(';');
//            String curWeekday=thisRunTime.format('EEEE');
//            Integer curDayFullWeekIndex=weekdays.indexOf(curWeekday);
//            Integer weekdayStartIndex=selectedWeekdays.indexOf(curWeekday);
//            Integer weekdayNextIndex=weekdayStartIndex+1;
//            System.debug('selectedWeekdays: weekdayStartIndex='+weekdayStartIndex+'...'+curWeekday);
//            System.debug('weekdays indexOf curWeekday'+curDayFullWeekIndex);
//            if(weekdayStartIndex==selectedWeekdays.size()-1){
//                weekdayNextIndex=0;
//                addDays=(weekdays.indexOf(selectedWeekdays[0])+1)+(weekdays.size()-(weekdays.indexOf(curWeekday)+1));
//            } else {
//                addDays=(weekdays.indexOf(selectedWeekdays[weekdayNextIndex])-curDayFullWeekIndex);
//            }
//            System.debug('adddays='+addDays+' ... selected weekdayNext='+selectedWeekdays[weekdayNextIndex]);
//            nextRunTime=Datetime.newInstance(thisRunTime.date().addDays(addDays),dailyStart);
//        } else {
//            nextRunTime=thisRunTime.addMinutes(minuteInterval);
//        }
//        System.debug('NEXT RUN TIME='+nextRunTime);
//        return nextRunTime;
//    }
}

    //    public static Map<String,Map<String,Object>>putAdjustmentsIntoDefaultsMap(Map<String,Map<String,Object>>adjMap,Map<String,Map<String,Object>>defaultMap){
//        for(String adjKey:adjMap.keySet()){
//            Map<String,Object>adjMeta=adjMap.get(adjKey);
//            if(defaultMap.containsKey(adjKey)){
//                Map<String,Object>defaultMeta=defaultMap.get(adjKey);
//                defaultMeta.putAll(adjMeta); //the adjMeta maps should replace any corresponding default label metamaps
//                adjMeta=defaultMeta;//put it back into labelmap
//            }
//            defaultMap.put(adjKey,adjMeta);
//        }
//        return defaultMap;
//    }
//    public static List<String>extractHeadersFromPriorUpload(Id iedId){
//        InsightsExternalDataPart iedPart=[SELECT Id,CreatedDate,PartNumber,DataFile FROM InsightsExternalDataPart WHERE InsightsExternalDataId=:iedId AND PartNumber=1 ORDER BY CreatedDate DESC LIMIT 1];
//        System.debug('iedPart='+JSON.serialize(iedPart));
//        System.debug(iedPart.DataFile.toString().substringBefore('\r\n'));
//        return iedPart.DataFile.toString().substringBefore('\r\n').split(',');
//    }
//    public static IntegratedDatasetConfig__c prepConfig(InsightsExternalData ied,List<String>columns,Map<String,String>aliasMap,Object runner){
//        IntegratedDatasetConfig__c idc=new IntegratedDatasetConfig__c(
//                InsightsExternalDataId__c=ied.Id,DatasetName__c=ied.EdgemartAlias,
//                Columns__c=JSON.serialize(columns),Runner__c=JSON.serialize(runner),
//                Alias_Storage__c=JSON.serialize(aliasMap)
//        );
//        return idc;
//    }

//    public class boundary{
//        public String colName;//TIMESTAMP MILLISECOND or CALL ID
//        private String altFilterName;//for TIMESTAMP MILLISECOND startTime
//        private String operator;
//        public Object args;
//        private String orderDir;
//        public Boolean isOrdered=(this.orderDir!=null&&(this.orderDir.equalsIgnoreCase('ASC')|this.orderDir.equalsIgnoreCase('DESC')));
//        private String typeName;
//        public Map<String,Object>filterMap;
//        public boundary(String colName,String operator,Object args,String orderDir,String altFilterName){ //serialize into return map
//            setupBoundary(colName,operator,args,orderDir,altFilterName);
//        }
//        public boundary(String colName,String operator,Object args){ //serialize into return map
//            setupBoundary(colName,operator,args,null,null);
//        }
//        private void setupBoundary(String colName,String operator,Object args,String orderDir,String altFilterName){
//            this.colName=colName;
//            this.operator=operator;
//            this.args=args;
//            this.orderDir=orderDir;
//            this.altFilterName=altFilterName;
//            this.typeName=getApexType(args);
//        }
//        public boundary rotateBoundaryArgs(List<String>headers,List<String>rows){
//            return new boundary(this.colName,this.operator,setArgVal(headers,rows),this.orderDir,this.altFilterName);
//        }
//        public Map<String,Object>toFilterMap(Object arg,Integer colX,String filterName){
//            return new Map<String,Object>{(altFilterName??this.colName)=>this.args};
//        }
//        public Object setArgVal(List<String>headers,List<String>rows){
//            Integer rowX; //set next argVal after we get the rows
//            if(this.isOrdered){
//                if(this.orderDir.equalsIgnoreCase('ASC')){ rowX=0; }
//                else if(this.orderDir.equalsIgnoreCase('DESC')){ rowX=rows.size()-1; }
//            }
//            return rows[rowX].split(',')[headers.indexOf(this.colName)];
//        }
//        public String getApexType(Object val) {
//            String typeName;
//            if(val==null){ typeName='Null';}
//            else if(val instanceof String) { typeName='String'; }
//            else if(val instanceof Integer) { typeName='Integer'; }
//            else if(val instanceof Decimal){ typeName='Decimal'; }
//            else if(val instanceof Datetime){ typeName='Datetime'; }
//            else if(val instanceof Date){ typeName='Date'; }
//            else if(val instanceof Time){ typeName='Time'; }
//            else if(val instanceof Boolean){ typeName='Boolean'; }
//            else{ typeName='Null'; }
//            return typeName;
//        }
//    }

//        public Integer
//        Map<Type,Boolean>typeMap=new Map<Type,Boolean>{ //
//                Type.forName('String')=>false,
//                Type.forName('Datetime')=>true,
//                Type.forName('Date')=>true,
//                Type.forName('Integer')=>true,
//                Type.forName('Decimal')=>true,
//                Type.forName('Double')=>true,
//                Type.forName('Long')=>true
//        };
//    public class columnOrder{
//        private String direction;
//        private String colName;
//    }
//    public class criteria{
//        public List<boundary>boundaries;
//        public List<Integer>boundaryColumnIndex;
//        public criteria(List<boundary>bounds,String orderedCol,String orderDirection){
//            this.ordering=orderDirection;
//        }
//        public criteria(List<boundary>bounds){
//
//        }
//        Map<String,Type>numberClueMap=new Map<String,Type>{'.$'=>Type.forName('Decimal')};
//        Boolean calcLIKE(){ return value.toString().contains(this.evaluator.toString()); }
//        Boolean calcEQUAL(){ return this.value==this.evaluator; }
//        Boolean calcLESSTHAN(Boolean includeEqual,String typeName){ //just make this return values instead
//            Boolean returner;
//            switch on typeName{
//                when'Integer'{
//                    if(includeEqual){ returner=(Integer.valueOf(this.value)>=Integer.valueOf(this.evaluator));
//                    } else { returner=(Integer.valueOf(this.value)>Integer.valueOf(this.evaluator)); }
//                }
//                when'Decimal'{
//                    if(includeEqual){ returner=(Decimal.valueOf(this.value.toString())>=Decimal.valueOf(this.evaluator.toString()));
//                    } else { returner=(Decimal.valueOf(this.value.toString())>Decimal.valueOf(this.evaluator.toString())); }
//                }
//                when'Datetime'{
//                    if(this.value.toString().contains('/')){ returner=(Datetime.parse(this.value.toString())<=Datetime.parse(this.evaluator.toString()));
//                    } else { returner=(Datetime.valueOf(this.value)<Datetime.valueOf(this.evaluator)); }
//                }
//                when'Date'{ if(this.value.toString().contains('/')){ returner=(Date.parse(this.value.toString())<=Date.parse(this.evaluator.toString()));
//                    } else { returner=(Date.valueOf(this.value)<Date.valueOf(this.evaluator)); }
//                }
//                when'Time'{
//                    List<String>valSubs=this.value.toString().split(':');
//                    List<String>evalSubs=this.evaluator.toString().split(':');
//                    Time valTime=Time.newInstance(Integer.valueOf(valSubs[0]),Integer.valueOf(valSubs[1]),Integer.valueOf(valSubs[2].substringBefore('.')),Integer.valueOf(valSubs[2].substringAfter('.')));
//                    Time evalTime=Time.newInstance(Integer.valueOf(evalSubs[0]),Integer.valueOf(evalSubs[1]),Integer.valueOf(evalSubs[2].substringBefore('.')),Integer.valueOf(evalSubs[2].substringAfter('.')));
//                    returner=(valTime<evalTime);
//                }
//            }
//            return returner;
//        }
//    }
//}
//    public static List<InsightsExternalDataPart>makeExternalDataParts_OLD(Id iedId,String csv){
//        Integer chunkMax=10000000;
//        csv=csv+'\r\n';//so we dont clip the last row if
//        List<InsightsExternalDataPart>parts=new List<InsightsExternalDataPart>{
//                new InsightsExternalDataPart(InsightsExternalDataId=iedId,PartNumber=1,DataFile=Blob.valueOf(csv.substringBefore('\r\n')+'\r\n'))
//        };
//        csv=(csv.substringAfter('\r\n'))+'\r\n';
//        Integer partNumber=2;
//        System.debug('\n\t... START OF CHUNKING\n\t\t... Expecting '+((csv.length()+chunkMax-1)/chunkMax)+' Chunks from csv(length='+csv.length()+')');
//        while(csv.length()>0){
//            Integer chunkSize=Math.min(chunkMax,csv.length());
//
//            String chunk=csv.substring(0,chunkSize).substringBeforeLast('\r\n')+'\r\n';
//            System.debug('Start of part #'+partNumber+', parts.size='+parts.size()+' ... chunk.length='+chunk.length()+' ... chunk.length='+chunk.length()+' ... \n\t1st Row='+csv.substringBefore('\r\n'));
//            csv=csv.substring(chunk.length());
//            System.debug('End of part #'+partNumber+' ... chunk.length='+chunk.length()+' ... remaining csv.length='+csv.length()+' ... ');
//            parts.add(new InsightsExternalDataPart(InsightsExternalDataId=iedId,PartNumber=partNumber,DataFile=Blob.valueOf(chunk)));
//            partNumber++;
//        }
//        return parts;
//    }
//    public void setMetadataJsonOnIED(List<String>headers,Map<String,Map<String,Object>>adjMap){ //creation only
//        String metadataJsonStr=buildMetadataJson(makeFieldsMeta(headers,adjMap),ied.EdgemartLabel,ied.EdgemartAlias);
//        this.ied.MetadataJson=Blob.valueOf(metadataJsonStr);
//        System.debug('\n\t\t-––—pre-Insert—InsightsExternalData—–>\n'+JSON.serializePretty(this.ied));
//    }
//    public static InsightsExternalData uploadPartFiles(String csv,InsightsExternalData ied){
//        Blob dataBlob = Blob.valueOf(csv.substringAfter('\r\n'));
//        InsightsExternalDataPart part=new InsightsExternalDataPart(
//                InsightsExternalDataId=ied.Id,
//                DataFile = dataBlob,
//                PartNumber=2
//        );
//        System.debug('\nAnalyticsUtility: Pre-Upload CSV Check...\n\tHEADER='+csv.substringBefore('\n')+'\n\t1stROW='+(csv.substringAfter('\n')).substringBefore('\n'));
//        insert part;
//        return ied;
//    }
//    public static List<String>chunkCsv(String csv){
//        List<String>chunks=new List<String>();
//        Integer chunkMax=10000000;
//        Integer cursor=0;
//        while(csv.length()>0){
//            String chunk=csv.substring(cursor,chunkMax).substringBeforeLast('\r\n')+'\r\n';
//            System.debug('Start of chunk #'+chunks.size()+' ... cursor='+cursor+' ... chunk.length='+chunk.length()+' ... ');
//            cursor=cursor+chunk.length();
//            csv=csv.substring(cursor);
//            System.debug('End of chunk #'+chunks.size()+' ... cursor='+cursor+' ... remaining csv.length='+csv.length()+' ... ');
//            chunks.add(chunk);
//        }
//        return chunks;
//
//    }
//    public static List<InsightsExternalDataPart>makeExternalDataPartsAfterHeader(Id iedId,String csv){
//        csv=csv+'\r\n';//so we dont clip the last row if
//        List<InsightsExternalDataPart>parts=new List<InsightsExternalDataPart>();
//        Integer chunkMax=10000000;
//        Integer cursor=0;
//        Integer partNumber=2;
//        System.debug('\n\t... START OF CHUNKING\n\t\t... Expecting '+((csv.length()+chunkMax-1)/chunkMax)+' Chunks from csv(length='+csv.length()+')');
//        while(csv.length()>0){
//            String chunk=csv.substring(0,chunkMax).substringBeforeLast('\r\n')+'\r\n';
//            System.debug('Start of part #'+partNumber+', parts.size='+parts.size()+' ... chunk.length='+chunk.length()+' ... chunk.length='+chunk.length()+' ... \n\t1st Row='+csv.substringBefore('\r\n'));
//            cursor=cursor+chunk.length();
//            csv=csv.substring(chunk.length());
//            System.debug('End of part #'+partNumber+' ... chunk.length='+chunk.length()+' ... remaining csv.length='+csv.length()+' ... ');
//            parts.add(new InsightsExternalDataPart(InsightsExternalDataId=iedId,PartNumber=partNumber,DataFile=Blob.valueOf(chunk)));
//            partNumber++;
//        }
//        return parts;
//    }
//public class csvReplacer{
//    String stringToFind{get;set;}
//    String replacer{get;set;}
//    Boolean onAll=false;
//    public csvReplacer(String stringToFind,String replacement,Boolean onAll){
//        this.stringToFind=stringToFind;
//        this.replacer=replacement;
//        this.onAll=onAll;
//    }
//    public csvReplacer(String stringToFind,String replacement){
//        this.stringToFind=stringToFind;
//        this.replacer=replacement;
//    }
//}

//    public static List<String>splitLargeCsvParameterized(String csv,List<csvReplacer>replacers){
//        //give list like this: List<AnalyticsUtility.csvReplacer>replacers=new List<AnalyticsUtility.csvReplacer>{ new AnalyticsUtility.csvReplacer('"[A-Z][a-z]{2}, ','',true),new AnalyticsUtility.csvReplacer('",',',',true), };
//        System.debug('\n\t\t-––—AnalyticsUtility.splitLargeCsv—–>\n\t');
//        List<String>rows=new List<String>();//data too big for a .split('\n') or any other regex-based method so gotta do something else
//        while(csv.length()>0){
//            if(csv.contains('\n')){
//                String row=(csv.substringBefore('\n'));
//                for(csvReplacer csvRp:replacers){
//                    if(row.contains(csvRp.stringToFind)){
//                        if(csvRp.onAll){ row.replaceAll(csvRp.stringToFind,csvRp.replacer); }
//                        else { row.replace(csvRp.stringToFind,csvRp.replacer); }
//                    }
//                }
//                rows.add(csv.substringBefore('\n'));
//                csv=csv.substringAfter('\n');
//            } else {
//                rows.add(csv.trim());
//                csv='';
//            }
//        }
//        return rows;
//    }