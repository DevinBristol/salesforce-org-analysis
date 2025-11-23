/**
 * Created by BENJAMIN on 1/14/2025.
 */

public with sharing class SfMapsRetriever {
    public static String level_id;//'attom-1'
    public static String file_id;//'usa_property_sfdc';
    public static String streetTopic;//'propertyaddressfull';
    public static String cityTopic;
    public static Boolean isRouteSplitting;
    public static String badChars='().,"—–';
    public static String tabId='1499862699443';
    public static final Map<String,String> streetTypeMap=new Map<String,String>{//ROAD IS BACKWARDS,
            'STREET'=>'ST','AVENUE'=>'AVE','DRIVE'=>'DR','LANE'=>'LN','RD'=>'ROAD','BOULEVARD'=>'BLVD',
            'COURT'=>'CT','CIRCLE'=>'CIR','PLACE'=>'PL','PLAZA'=>'PLZ','TERRACE'=>'TER','ROUTE'=>'RTE',
            'HIGHWAY'=>'HWY','ROADWAY'=>'RDWY','PARKWAY'=>'PKWY','BYWAY'=>'BYWY','EXPRESSWAY'=>'EXPY'
    };
    public static final Map<String,String> exStreetTypeMap=new Map<String,String>{ //these cause ISSUES. Dont FUCK with me on this.
            'EXTENSION'=>'EXT','ESTATE'=>'EST','RUN'=>'RUN','WAY'=>'WAY','CORSO'=>'CORSO','RUE'=>'RUE','KNOLL'=>'KNL','SQUARE'=>'SQ','VILLAGE'=>'VLG','PASSAGE'=>'PSGE',
            'CANYON'=>'CYN','LAKE'=>'LK','CAMP'=>'CMP','BEACH'=>'BCH','POINT'=>'PT','POINTE'=>'PTE','SHORE'=>'SHR','LANDING'=>'LNDG','CAY'=>'CAY','BAY'=>'BAY',
            'CORRAL'=>'COR','WALK'=>'WLK','TRAIL'=>'TRL','RIDGE'=>'RDG','HILLS'=>'HLS','HEIGHTS'=>'HTS','HOLLOW'=>'HLW','TRACE'=>'TRCE','BEND'=>'BND'
    };  //   public static final Set<String>constantTypes=new Set<String>{'RUE','CORSO','RUN','WAY'};
    public static final Map<String,String> dirMap=new Map<String,String>{
            'NORTH'=>'N','EAST'=>'E','SOUTH'=>'S','WEST'=>'W'
    };
    public static final Set<String> mailingOnlyTypes =new Set<String>{'APT','STE','UNIT','LOT','#','PO BOX','TRLR','DRWY'}; //replace 'DR##' with 'DRWY##'
    public static final List<String>allSuffixes=new List<String>{
    'STREET','ST','AVENUE','AVE','DRIVE','DR','LANE','LN','RD','ROAD','BOULEVARD','BLVD','COURT','CT','CIRCLE','CIR','PLACE','PL','PLAZA','PLZ','EXTENSION','EXT',
    'HIGHWAY','HWY','ROADWAY','RDWY','PARKWAY','PKWY','BYWAY','BYWY','EXPRESSWAY','EXPY','ROUTE','RTE','TERRACE','TER','ESTATE','EST','RUN','WAY','SQUARE','SQ',
    'TRAIL','TRL','KNOLL','KNL','WALK','WLK','RIDGE','RDG','HILL','HL','HEIGHTS','HTS','CORRAL','COR','CANYON','CYN','BEACH','POINT','SHORE','HOLLOW','HLW',
    'LAKE','LK','CAMP','CMP','POINT','PT','POINTE','PTE','TRACE','TRCE','PASSAGE','PSGE','LANDING','BAY','CAY','BEND','BND','VILLAGE','VLG','CORSO','RUE'
    };//   static final Set<String>authTypes=new Set<String>{'US','STATE','COUNTY'};   //    public static Map<Id,Map<String,String>>stateIdToRouteMap=new Map<Id,Map<String,String>>();//    public static Map<String,Map<String,Map<String,Set<String>>>> cityStreetMap=new Map<String,Map<String,Map<String,Set<String>>>>();
    public static final Set<String> x2ndryDirs=new Set<String>{'NE','NW','SE','SW'};
    public static final Set<String>splitterTopics=new Set<String>{'propertyaddressfull','contactownermailaddressfull'};
    public static final Boolean splitting=(splitterTopics.contains(streetTopic));
    public static Map<String,Id> keyMap;        //Map<filterStreet,p.Id> we can use string keyset instead of filterStreets variable
    public static Map<String,List<String>>searchMap;    //Map<prop city Names(caps),List<filterStreets in city>>
    public String reqString{get;set;}
    public Map<String,Object> response{get;set;}

    public static void setInitials(String streetTop,String cityTop,String source,Boolean isRouteSplit,String preCleanChars){
        keyMap=new Map<String,Id>();
        searchMap=new Map<String,List<String>>();
        cityTopic=cityTop;
        streetTopic=streetTop;
        isRouteSplitting=isRouteSplit;
        badChars=(preCleanChars??'().,"—–');
        Map<String,List<String>> layerModeMap = new Map<String,List<String>>{
                'levelId'=>new List<String>{'attom-1','42','census'},
                'fileId'=>new List<String>{'usa_property_sfdc','business','lvl'}};
        Integer fieldIndex = (new List<String>{'property','business','census'}).indexOf(source);
        file_id=layerModeMap.get('fileId').get(fieldIndex);
        level_id=layerModeMap.get('levelId').get(fieldIndex);
    }//  ↙⎻⎻⎻⎻CONSTRUCTOR⎻⎻#1⎻-⎽‗(sets up static class)//
    public SfMapsRetriever(String source,String streetTopic,String cityTopic,Boolean isRouteSplitting,String badChars){
        setInitials(streetTopic,cityTopic,source,isRouteSplitting,badChars);
    }
    //  ↙⎻⎻⎻⎻CONSTRUCTOR⎻⎻#2⎻-⎽‗(gets Geographic Ids)//
    public SfMapsRetriever(List<Property__c>props,String searchKey){ //(unified)—>
        if(isRouteSplitting){
            this.reqString=makeRouteGeoIdReqString(props,searchKey);
        } else {
            this.reqString=makeCityGeoIdReqString(props,searchKey);
        }
        System.debug('sfmr(2['+searchKey+']): REQUEST:\r'+this.reqString);
        this.response=getGeoIdResponse(this.reqString);
        System.debug('sfmr(2['+searchKey+']): RESPONSE:\r'+this.response);
    } //  ↙⎻⎻⎻⎻CONSTRUCTOR⎻⎻#3⎻-⎽‗(gets hosted data)//
    public SfMapsRetriever(List<Property__c> props,List<String>topics,List<Integer>geographicIds){
        this.reqString=makeHostedDataReqString(props,topics,geographicIds);
        this.response=getHostedDataResponse(reqString);
        System.debug('sfmr(3): REQUEST:\r'+this.reqString);
        System.debug('sfmr(3): RESPONSE:\r'+this.response);
    }
    public static void makeFilterMaps(List<Property__c>props){
        if(isRouteSplitting){
            makeRouteFilterMaps(props);
        } else {
            makeCityFilterMaps(props);
        }
    }
    public static Map<String,String> getRouteMap(String street,String city){
        Map<String,String>routeMap=new Map<String,String>{'route'=>'','numb'=>'','suffx'=>''};
        List<String>orderList=new List<String>();
        Set<String> streetTypeSet = new Set<String>(streetTypeMap.keySet());
        streetTypeSet.addAll(streetTypeMap.values());
        routeMap.put('city',city.toUpperCase());
        if(street.endsWith(']')){
            routeMap.put('subunit',street.substringBetween('[',']'));
            street=street.substringBefore('[');
        }
        if(street.substringAfter(' ').substringBefore(' ').contains('/')&&street.substringBefore('/').right(1).isNumeric()&&street.substringAfter('/').left(1).isNumeric()){
            routeMap.put('numb',street.substringBefore('/')+'/'+street.substringAfter('/').substringBefore(' '));
            orderList.add('numb');
        } else if(street.contains(' ')&&street.substringBefore(' ').left(1).isNumeric()){
            routeMap.put('numb',street.substringBefore(' '));
            orderList.add('numb');
        }
        if(routeMap.get('numb')!=null){
            Integer ssX=0;
            List<String>ssList=street.substringAfter(routeMap.get('numb')+' ').split(' ');
            for(String ss : ssList){      //can remove first ss cause we checked its a number
                String ssU = ss.toUpperCase();
                if(ssU.contains('OLD-')){
                    routeMap.put('suffx','OLD,');
                    ssU=ssU.remove('OLD-');
                    orderList.add('OLD');//put somewhere better later.
                }
                if(ssU.contains('—')){
                    routeMap.put('auth',ssU.substringBefore('—'));
                    routeMap.put('suffx',routeMap.get('suffx')+ssU.substringAfter('—')+',');
                    orderList.add('auth');
                    orderList.add('suffx');
                }
                else if(streetTypeSet.contains(ssU)||streetTypeSet.contains(ssU.removeEnd('S'))||exStreetTypeMap.values().contains(ssU)|| ((exStreetTypeMap.containsKey(ssU)||exStreetTypeMap.containsKey(ssU.removeEnd('S')))&&((ssX==(ssList.size()-1))||ssX<(ssList.size()-1)&&!streetTypeSet.contains(ssList[ssX+1].toUpperCase())))){
                    if(streetTypeMap.containsKey(ssU)){
                        ssU=streetTypeMap.get(ssU);
                    }
                    routeMap.put('suffx',routeMap.get('suffx')+ssU+',');
                    orderList.add('suffx');
                } else if((dirMap.containsKey(ssU) && !(ssX<(ssList.size()-1)&&streetTypeMap.containsKey(ssList[ssX+1].toUpperCase())) || dirMap.values().contains(ssU) || x2ndryDirs.contains(ssU))) {
                    if(dirMap.containsKey(ssU)){
                        ssU=dirMap.get(ssU);
                    }
                    routeMap.put('dir',ssU);
                    orderList.add('dir');
                } else {
                    routeMap.put('route',routeMap.get('route')+ssU+' ');
                    orderList.add('route');
                }
                ssX++;
            }
        }
        routeMap.put('suffx',routeMap.get('suffx').removeEnd(','));
        routeMap.put('route',routeMap.get('route').removeEnd(' '));
        if((!orderList.contains('route'))&&routeMap.get('suffx').contains(',')){ //things like circles st, plaza road, streets dr
            routeMap.put('route',routeMap.get('suffx').substringBefore(','));
            orderList.set(orderList.indexOf('suffx'),'route');
        }
        routeMap.put('order',String.join(orderList,','));

        String keychain=city.toUpperCase()+','+routeMap.get('route');
        if(routeMap.containsKey('dir')){
            keychain=keychain+','+routeMap.get('dir');
        }
        routeMap.put('keychain',keychain);
        return routeMap;
    }
    public static Property__c presplit(Property__c p){
        p.Mailing_Only_Address__c=p.Address__Street__s.substringBetween('[',']');
        p.Address__Street__s=p.Address__Street__s.substringBefore('[');
        System.debug('mailing Found:(new Street='+p.Address__Street__s+', new MailingOnly='+p.Mailing_Only_Address__c+')');
        return p;
    }
    public static void makeRouteFilterMaps(List<Property__c>props){
        //TODO SEE IF MAILING ONLY ADDRESSES ARE TYPICALLY EXCLUDED FROM propertyaddressfull & contactownermailaddressfull OR the bizLayer fields//  whether or not we cut out mailingOnly stubs we find & assign to Mailing_Only_Address__c
        for(Property__c p : props){
            p.Address__Street__s=cursoryStreetCleaning(p.Address__Street__s);
            //redundant but it works for now. if our data isn't already split,
            if(p.Address__Street__s.endsWith(']')&&splitting){
                p=presplit(p);
            }
            p.Address__Street__s=authEval(p.Address__Street__s,p.Address__StateCode__s);
            String street=p.Address__Street__s;
            if(p.Mailing_Only_Address__c!=null){
                street=street+'['+p.Mailing_Only_Address__c+']';
            }
            System.debug('SfMapsRetriever:makeRouteFilterMaps: All Precleaning done. (street='+p.Address__Street__s+' ... mailing_only='+p.Mailing_Only_Address__c);
            Map<String,String>routeMap=getRouteMap(street,p.Address__City__s);
            Set<String>searchValues=new Set<String>{routeMap.get('numb')};
            System.debug('\rroutemap=\r'+routeMap);
            keyMap.put(routeMap.get('keychain')+','+routeMap.get('numb'),p.Id);
            if(routeMap.containsKey('subunit')){
                keyMap.put(routeMap.get('keychain')+routeMap.get('numb')+','+routeMap.get('subunit'),p.Id);
            }
            System.debug('FilterMap Keys[ searchMap : \''+routeMap.get('keychain')+'\', keyMap\''+routeMap.get('keychain')+','+routeMap.get('numb')+'\' ]');
            if(searchMap.containsKey(routeMap.get('keychain'))){
                searchValues.addAll(searchMap.get(routeMap.get('keychain')));
            }
            searchMap.put(routeMap.get('keychain'),new List<String>(searchValues));
        }
    }
    //ONLY FOR reqstring construction here... then used
    public static void makeCityFilterMaps(List<Property__c> props){ // this can stay static since each transaction of upto 200 needs it for all 200 items in the 3 maps?
        Set<String> streetTypeSet = new Set<String>();
        streetTypeSet.addAll(streetTypeMap.keySet());
        streetTypeSet.addAll(streetTypeMap.values());
        for(Property__c p : props){
            Boolean isSubunit=false;
            p.Address__Street__s=cursoryStreetCleaning(p.Address__Street__s);
            if(p.Address__Street__s.endsWith(']')&&splitting){
                p=presplit(p);
                System.debug('presplit street: '+p.Address__Street__s);
            }
            if(p.Mailing_Only_Address__c!=null){isSubunit=true;}
            String searchStreet;
            if(p.Address__Street__s.substringAfter(' ').substringBefore(' ').contains('/')&&p.Address__Street__s.substringBefore('/').right(1).isNumeric()&&p.Address__Street__s.substringAfter('/').left(1).isNumeric()){
                searchStreet=p.Address__Street__s.substringBefore('/')+'/'+p.Address__Street__s.substringAfter('/').substringBefore(' ')+' ';
            } else if(p.Address__Street__s.contains(' ')&&p.Address__Street__s.substringBefore(' ').left(1).isNumeric()){
                searchStreet=p.Address__Street__s.substringBefore(' ')+' ';
            }
            if(searchStreet!=null){
                searchStreet=p.Address__Street__s.substringBefore(' ')+' ';
                Set<String> extraSearchStreets = new Set<String>();
                List<String> ssList = p.Address__Street__s.substringAfter(' ').split(' ');
                Integer ssX=0;
                for(String ss : ssList){      //can remove first ss cause we checked its a number
                    String ssU = ss.toUpperCase();
                    if(streetTypeMap.containsKey(ssU)){//–—SUFFIX-EVAL–—>
                        if(ssU=='HIGHWAY'||ssU.left(3)==p.Address__StateCode__s.toUpperCase()+'-'){
                            //HIGHWAYS HERE
                            System.debug('HERES A GODDAM HIWAY:'+p.Address__Street__s);
                        } else if(ssX<ssList.size()-1){//—–dubble-suff–noSwap–—> //(i.e. RIDGE ROAD ... CIRCLE STREET ... LAKE STREET)
                            if(streetTypeSet.contains(ssList[ssX+1].toUpperCase())){
                                if(ssX==0){
                                    System.debug('For: '+p.Address__Street__s+'NOT Replacing '+ss+' with '+streetTypeMap.get(ssU));
                                } else if(dirMap.containsKey(ssList[ssX+(-1)].toUpperCase())){
                                    System.debug('For: '+p.Address__Street__s+'NOT Replacing '+ss+' with '+streetTypeMap.get(ssU));
                                } else if(!dirMap.containsKey(ssList[ssX+(-1)].toUpperCase())&&!streetTypeSet.contains(ssList[ssX+(-1)].toUpperCase())){
                                    System.debug('For: '+p.Address__Street__s+'NOT Replacing '+ss+' with '+streetTypeMap.get(ssU));
                                }
                            } else {
                                System.debug('For: '+p.Address__Street__s+'...Replacing '+ss+' with '+streetTypeMap.get(ssU));
                                ss=streetTypeMap.get(ssU);
                            }
                        } else {
                            System.debug('For: '+p.Address__Street__s+'...Replacing '+ss+' with '+streetTypeMap.get(ssU));
                            ss=streetTypeMap.get(ssU);
                        }
                    } else if(streetTypeMap.containsKey(ssU.removeEnd('S'))){
                        System.debug('For: '+p.Address__Street__s+'...(+"S" FOUND!)Replacing '+ss+' with '+streetTypeMap.get(ssU+'S'));
                        ss=streetTypeMap.get(ssU.removeEnd('S'))+'S';//ESTATE=>EST//(vs)//ESTATES=>ESTS//LAKE=>LK//(vs)//LAKES=>LKS
                    } else if(dirMap.containsKey(ssU)){       //–—DIRECTION-EVAL–—>
                        if(ssX<(ssList.size()-1)){ //–—(mid)DIR-EVAL–—>
                            if(streetTypeMap.containsKey(ssList[ssX+1].toUpperCase()) || streetTypeMap.values().contains(ssList[ssX+1].toUpperCase())){ //not changing dir values withing "SOUTH ST" type addresses
                                System.debug('For: '+p.Address__Street__s+'...NOT!!! replacing Directional routeName '+ss+' with '+dirMap.get(ssU));//only for when the next ss is suffix.
                            } else if(ssX>=2&&ssX<ssList.size()-1&&(dirMap.containsKey(ssList[ssX+(-1)].toUpperCase())||dirMap.values().contains(ssList[ssX+(-1)].toUpperCase()))){ // for the cases like '2608 WEST NORTH FRONT STREET' where 'NORTH FRONT' is probably the routename
                                System.debug('...NOT!!! replacing Direction-Including? routeName '+ss+' with '+dirMap.get(ssU)); //only for when the next ss is routename.
                            } else {//–—(end)DIR-EVAL–—>
                                System.debug('For: '+p.Address__Street__s+'...Replacing '+ss+' with '+dirMap.get(ssU));
                                ss=dirMap.get(ssU);
                            }
                        } else {
                            System.debug('For: '+p.Address__Street__s+'...Replacing '+ss+' with '+dirMap.get(ssU)); //last ss is full dir.
                            ss=dirMap.get(ssU);
                        }
                    }
                    searchStreet=searchStreet+ss.toUpperCase()+ ' ';
                    ssX++;
                }
                searchStreet=searchStreet.trim();
                if(isSubunit){
                    extraSearchStreets.add(searchStreet);//adding a version without mailingonly to extra.
                    searchStreet=searchStreet+' '+(p.Mailing_Only_Address__c.trim().toUpperCase());
                }
                keyMap.put(searchStreet,p.Id);
                System.debug('searchable Street --> '+searchStreet);
                if(!searchMap.containsKey(p.Address__City__s.toUpperCase())){
                    searchMap.put(p.Address__City__s.toUpperCase(),new List<String>{searchStreet});
                } else {
                    List<String> citySearchStreets = searchMap.get(p.Address__City__s.toUpperCase());
                    citySearchStreets.add(searchStreet);
                    searchMap.put(p.Address__City__s.toUpperCase(),citySearchStreets);
                }
// ADDITIONAL SEARCHSTREETS FOR AMBIGUITIES, HIGHWAYS & ROADS (HIGHER JURIS ADDRESSES)...searchMap and cityFilterPropMap should have appropriate lists instantiated for each city.
                if((searchStreet.contains(' NORTH ')&&(streetTypeMap.containsKey(searchStreet.substringAfter(' NORTH '))||streetTypeMap.values().contains(searchStreet.substringAfter(' NORTH ')))) ||
                    (searchStreet.contains(' N ')&&(streetTypeMap.containsKey(searchStreet.substringAfter(' N '))||streetTypeMap.values().contains(searchStreet.substringAfter(' N ')))) ||
                    (searchStreet.contains(' SOUTH ')&&(streetTypeMap.containsKey(searchStreet.substringAfter(' SOUTH '))||streetTypeMap.values().contains(searchStreet.substringAfter(' SOUTH ')))) ||
                    (searchStreet.contains(' S ')&&(streetTypeMap.containsKey(searchStreet.substringAfter(' S '))||streetTypeMap.values().contains(searchStreet.substringAfter(' S ')))) ||
                    (searchStreet.contains(' EAST ')&&(streetTypeMap.containsKey(searchStreet.substringAfter(' EAST '))||streetTypeMap.values().contains(searchStreet.substringAfter(' EAST ')))) ||
                    (searchStreet.contains(' E ')&&(streetTypeMap.containsKey(searchStreet.substringAfter(' E '))||streetTypeMap.values().contains(searchStreet.substringAfter(' E ')))) ||
                    (searchStreet.contains(' WEST ')&&(streetTypeMap.containsKey(searchStreet.substringAfter(' WEST '))||streetTypeMap.values().contains(searchStreet.substringAfter(' WEST ')))) ||
                    (searchStreet.contains(' W ')&&(streetTypeMap.containsKey(searchStreet.substringAfter(' W '))||streetTypeMap.values().contains(searchStreet.substringAfter(' W '))))
                ){
                    System.debug('[EXTRA] Road searchStreets for(direction&routename ambiguity): '+searchStreet);
                    extraSearchStreets.add(searchStreet.replace(' N ',' NORTH ').replace(' E ',' EAST ').replace(' S ',' SOUTH ').replace(' W ',' WEST ').replace(' NORTH ',' N ').replace(' EAST ',' E ').replace(' SOUTH ',' S ').replace(' WEST ',' W '));
                }
                if(searchStreet.contains(' ROAD ')||searchStreet.right(5)==' ROAD'){ //bonus round for ROAD and HWY type addresses;
                    System.debug('[EXTRA] Road searchStreets for: '+searchStreet);
                    extraSearchStreets.add(searchStreet.replace(' ROAD',' RD'));
                    extraSearchStreets.add(searchStreet.replace(' ROAD',' RD'));
                    extraSearchStreets.add(searchStreet.replace(' ROAD',''));
                } else if(searchStreet.contains(' HWY ') ||
                        searchStreet.contains(' HIGHWAY ') ||
                        (searchStreet.contains(' US ')&&searchStreet.substringAfter(' US ').left(1).isNumeric()) ||
                        searchStreet.contains(' '+p.Address__StateCode__s+'-') ||
                        (searchStreet.contains(p.Address__c.getState()) &&
                                searchStreet.substringAfter(p.Address__c.getState()+' ').left(1).isNumeric())){
                    if(searchStreet.contains(' US HIGHWAY ')){ //put different search street possibilities for US hwy addresses
                        System.debug('[EXTRA] US Highway searchStreets for: '+searchStreet);
                        extraSearchStreets.add(searchStreet.replace(' US HIGHWAY',' HIGHWAY'));
                        extraSearchStreets.add(searchStreet.replace(' US HIGHWAY',' HWY'));
                    } else if(searchStreet.contains(' US ')){
                        System.debug('[EXTRA] US ## (Highway?) searchStreets for: '+searchStreet);
                        extraSearchStreets.add(searchStreet.replace(' US ',' US HIGHWAY '));
                        extraSearchStreets.add(searchStreet.replace(' US ',' US HWY '));
                        extraSearchStreets.add(searchStreet.replace(' US ',' HIGHWAY '));
                        extraSearchStreets.add(searchStreet.replace(' US ',' HWY '));
                    } else if(searchStreet.contains(' STATE HIGHWAY')){
                        System.debug('[EXTRA] STATE HIGHWAY searchStreets for: '+searchStreet);
                        extraSearchStreets.add(searchStreet.replace(' STATE HIGHWAY',' HIGHWAY'));
                        extraSearchStreets.add(searchStreet.replace(' STATE HIGHWAY',' HWY'));
                    } else if(searchStreet.contains(' '+p.Address__StateCode__s+'-')){//i.e. 14141 NE-2
                        System.debug('[EXTRA] StateCode-## highway searchStreets for: '+searchStreet);
                        extraSearchStreets.add(searchStreet.replace(' '+p.Address__StateCode__s+'-',' STATE HIGHWAY '));
                        extraSearchStreets.add(searchStreet.replace(' '+p.Address__StateCode__s+'-',' HIGHWAY '));
                        extraSearchStreets.add(searchStreet.replace(' '+p.Address__StateCode__s+'-',' HWY '));
                    } else if( searchStreet.contains(p.Address__c.getState())) {//i.e. 14141 Nebraska 2
                        System.debug('[EXTRA] getState ## highway searchStreets for: '+searchStreet);
                        extraSearchStreets.add(searchStreet.replace(' '+p.Address__c.getState()+' ',' STATE HIGHWAY '));
                        extraSearchStreets.add(searchStreet.replace(' '+p.Address__c.getState()+' ',' HIGHWAY '));
                        extraSearchStreets.add(searchStreet.replace(' '+p.Address__c.getState()+' ',' HWY '));
                    } else if(searchStreet.contains('HIGHWAY')){ //generic fucking highway... do em all I guess.
                        System.debug('[EXTRA] Generic Highway searchStreets for: '+searchStreet);
                        extraSearchStreets.add(searchStreet.replace('HIGHWAY','US HIGHWAY'));
                        extraSearchStreets.add(searchStreet.replace('HIGHWAY','US HIGHWAY'));
                        extraSearchStreets.add(searchStreet.replace('HIGHWAY','STATE HIGHWAY'));
                        extraSearchStreets.add(searchStreet.replace('HIGHWAY','HWY'));
                    } else if(searchStreet.contains('HWY')){ //generic fucking highway... do em all I guess.
                        System.debug('[EXTRA] Generic Highway searchStreets for: '+searchStreet);
                        extraSearchStreets.add(searchStreet.replace('HWY','US HIGHWAY'));
                        extraSearchStreets.add(searchStreet.replace('HWY','STATE HIGHWAY'));
                        extraSearchStreets.add(searchStreet.replace('HWY','HIGHWAY'));
                    }
                }
                for(String extraSearchStreet : extraSearchStreets){
                    keyMap.put(extraSearchStreet,p.Id);
                }
                extraSearchStreets.addAll(searchMap.get(p.Address__City__s.toUpperCase()));
                List<String> citySearchStreets = new List<String>(extraSearchStreets);
                searchMap.put(p.Address__City__s.toUpperCase(),citySearchStreets);
            } else {
                System.debug('\t–—[GARBAGE]—>'+p.Address__Street__s+'\r\t\t\tREMOVED!! SEE YA! ');
            }
        }
        System.debug('\r\r-––—[SfMapsRetriever:makeCityFilterMaps]–finished–keyMap–—>\r'+JSON.serializePretty(keyMap));
        System.debug('\r\r-––—[SfMapsRetriever:makeCityFilterMaps]–finished–searchMap–—>\r'+JSON.serializePretty(searchMap));
    }

    public String makeCityGeoIdReqString(List<Property__c> cityProps,String city){//nonstatic because it will only be used once per instance,we could instantiate this class twice per batch
        List<Map<String,Object>> filters=new List<Map<String,Object>>{
                new Map<String,Object>{'operator'=>'equals','topic_id'=>streetTopic,'values'=>searchMap.get(city)},
                new Map<String,Object>{'operator'=>'equals','topic_id'=>cityTopic,'values'=>city}
        };
        Map<String,Object> dataMap=new Map<String,Object>{
                'filters'=>filters,'defaultMarkerColor'=>'D31A28:Circle','level_id'=>level_id,'file_id'=>file_id
        };
        Map<String,Object>request=new Map<String,Object>{'data'=>dataMap,'mapinfo'=>getGroupMapInfo(cityProps)};
        String cityReqGeoIdString=JSON.serialize(request);
        return cityReqGeoIdString;
    }
    public String makeRouteGeoIdReqString(List<Property__c> props,String keychain){
        String city;
        String route;
        String dir='';
        List<String>keys=keychain.split(',');
        if(keys.size()>1){
            city=keys[0];
            route=keys[1];
            if(keys.size()>2){
                dir=keys[2];
            }
        } else {
            System.debug('this fucker: '+keychain);
        }
        Set<String>numbs=new Set<String>(searchMap.get(keychain));

        Map<String,Object> dataMap=new Map<String,Object>{
                'filters'=>layerFilterBitch(city,route,dir,numbs),'defaultMarkerColor'=>'D31A28:Circle','level_id'=>level_id,'file_id'=>file_id
        };
        Map<String,Object>request=new Map<String,Object>{'data'=>dataMap,'mapinfo'=>getGroupMapInfo(props)};
        String routeReqGeoIdString=JSON.serialize(request);
        return routeReqGeoIdString;
    }
    public Map<String,Object> getGeoIdResponse(String requestString) { //properties gotta have geocodes AND be split into city specific lists;
        return maps.API.GetHostedData(requestString);
    }
    public List<Integer> procGeoIdResponse(Map<String,Object> response){ //make this return a stub
        Map<String,Object> resData = (Map<String,Object>)response.get('data');
        List<Integer> geoIds = new List<Integer>();
        List<Object> resObjs = (List<Object>)resData.get('ids');
        for(Object o : resObjs){
            geoIds.add((Integer)o);
        }
        return geoIds;
    }
    //constructor #2 methods...
    public String makeHostedDataReqString(List<Property__c> props,List<String>topics,List<Integer>geographicIds) {
        Integer tabSize = 10;
        Integer headerSize = 2;
        Decimal tabCountDecimal = ((topics.size() - headerSize) / tabSize) + (.9);
        Integer tabCount = tabCountDecimal.round().intValue();
        //HEADER
        if (topics.size() < headerSize) {
            headerSize = topics.size() - 1;
        }
        List<Map<String,String>> header = new List<Map<String,String>>();
        System.debug('topics.size = ' + topics.size());
        header.add(new Map<String,String>{'file_id'=>file_id,'topic_id'=>'parcelnumberformatted'});
        System.debug('header = ' + header);
        //ROWS
        List<Map<String,Object>> tabs = new List<Map<String,Object>>();
        for (Integer tabX = 0; tabX < tabCount; tabX++) {
            List<Map<String,String>> tabData = new List<Map<String,String>>();
            System.debug('starting tabX-->' + tabX);
            if (tabX == (tabCount - 1)) {
                tabSize = (topics.size()) - (tabX * tabSize);
                System.debug('topics size = ' + topics.size() + ',remainder size = ' + tabSize + ' ... check math --> ' + Math.mod((topics.size() - headerSize),5));
            }
            for (Integer rowX = 0; rowX < tabSize; rowX++) {
                Integer topicX = (tabX * 10) + rowX;
                System.debug('topicX = ' + topicX + ' ...topic = ' + topics[topicX]);
                tabData.add(new Map<String,String>{'file_id'=>file_id,'topic_id'=>topics[topicX]});
            }
            Map<String,Object> tab = new Map<String,Object>{
                    'tab_id'=>tabId.left(11) + String.valueOf((Integer.valueOf(tabId.right(2)) + (tabX + 1))),
                    'tab_label'=>'tabX' + tabX,
                    'data'=>tabData
            };
            tabs.add(tab);
            System.debug('ending tabX-->' + tabX + ' ...tab = ' + tabData);
        }
        Map<String,Object> popup = new Map<String,Object>{
                'header'=>header,'tabs'=>tabs
        };
        Map<String, Object> row = new Map<String, Object>{
                'topic_id'=>streetTopic, 'operator'=>'not equal to', 'values'=>new List<String>{
                        ''
                }, 'color'=>'46E71B:Circle'
        };
        List<Map<String, Object>> legendRows = new List<Map<String, Object>>();
        legendRows.add(row);
        Map<String, Object> legend = new Map<String, Object>{
                'title'=>'XXX', 'subTitle'=>'', 'rows'=>legendRows
        };
        Map<String,Object> data = new Map<String,Object>{
                'file_id'=>file_id,'level_id'=>level_id,
                'defaultMarkerColor'=>'46E71B:Circle',
                'legend'=>legend,'popup'=>popup
        };
        Map<String,Object> request = new Map<String,Object>{
                'ids'=>geographicIds,
                'details'=>true,'aggregates'=>true,
                'data'=>data, 'mapinfo'=>getGroupMapInfo(props)//this can now take all the cities because we already filtered false geoIds;
        };
        String reqString = JSON.serialize(request);
        return reqString;
    }
    public Map<String,Object> getHostedDataResponse(String reqString){
        Map<String,Object> response = maps.API.GetHostedData(reqString);
        System.debug(JSON.serializePretty(response));
        return response;
    }
    public List<Property__c> procHostedDataResponse(Map<String,Object>response){
        List<Property__c> foundProps=new List<Property__c>();
        Set<Id>foundIds=new Set<Id>();
//        Map<String,List<Object>>foundMap=new Map<String,List<Object>>();
        List<Property__c> missedProps=new List<Property__c>();
        List<Object>markers=((List<Object>)((Map<String,Object>)response.get('data')).get('markers'));
        System.debug('\rmarkers (size='+markers.size()+')');
        for(Object marker : markers){
            Map<String,Object> popup=(Map<String,Object>)((Map<String,Object>)marker).get('popup');
            Map<String,Object>popupData=new Map<String,Object>();
            for(Object tab : (List<Object>)popup.get('tabs')) {
                List<Object>tData=(List<Object>)(((Map<String,Object>)tab).get('data'));
                for(Object data : tData){
                    Map<String,Object>dataMap=(Map<String,Object>)data;
                    Object value=dataMap.get('value');
                    if(value!='null'&&value!=null&&value!=''){
                        popupData.put((String)dataMap.get('topic_id')+'__c',dataMap.get('value'));
                    }
                }
            }
            Id foundPropId;
            if(popupData.containsKey(streetTopic+'__c')){
                if(isRouteSplitting&&popupData.containsKey(cityTopic+'__c')){//System.debug('popupData='+JSON.serializePretty(popupData));
                    Map<String,String>routeMap=getRouteMap(String.valueOf(popupData.get(streetTopic+'__c')),String.valueOf(popupData.get(cityTopic+'__c')));//gets the parsed responsemaps cityTopic topic object cast to string
                    System.debug('KEYCHAIN: '+routeMap.get('keychain')+','+routeMap.get('numb'));
                    foundPropId=keyMap.get(routeMap.get('keychain')+','+routeMap.get('numb'));
                } else {
                    foundPropId=keyMap.get((String)popupData.get(streetTopic+'__c'));
                }
            }
            if(foundPropId!=null){
                popupData.put('Id',foundPropId);
                if(popupData.containsKey('currentsecondpositionopenloaninterestrate__c')){
                    popupData.put('current2ndpositionopenloaninterestrate__c',popupData.get('currentsecondpositionopenloaninterestrate__c'));
                    popupData.remove('currentsecondpositionopenloaninterestrate__c');
                }
                foundProps.add((Property__c)JSON.deserializeStrict(JSON.serialize(popupData),Property__c.class));
            } else {
                missedProps.add((Property__c)JSON.deserializeStrict(JSON.serialize(popupData),Property__c.class));
            }
        }
        System.debug('\rFOUND PROPS(size='+foundProps.size()+')\r'+JSON.serializePretty(foundProps));
        System.debug('MISSED PROPS—>\r'+JSON.serializePretty(missedProps));
        return foundProps;
    }
    public List<Property__c>nameMatcher(List<Property__c>foundProps,Map<Id,Property__c>scopeMap){ //make sure we're getting the lead & account names off these somehow
        Map<Id,Integer>scoreMap=new Map<Id,Integer>();
        Map<Id,Property__c>bestMatchMap=new Map<Id,Property__c>();
        for(Property__c p : foundProps){
            if(!scoreMap.containsKey(p.Id)){ scoreMap.put(p.Id,0); }
            Integer score=0;
            if((p.partyowner1namefull__c!=null|p.partyowner2namefull__c!=null)){
                Set<String>foundNameChunks=new Set<String>(String.join(new List<String>{(p.partyowner1namefull__c??''),(p.partyowner2namefull__c??'')},' ').split(' '));
                System.debug('NAMEMATCH: PREP: foundNameChunks = '+foundNameChunks+'\tp1namefull='+p.partyowner1namefull__c+'...p2namefull='+p.partyowner2namefull__c);
                if(scopeMap.get(p.Id).Account_Property_Relationships__r.size()>0){
                    List<Account_Property_Relationship__c>aprs=scopeMap.get(p.Id).Account_Property_Relationships__r;
                    System.debug('NAMEMATCH: Start: (APR Count='+aprs.size()+' )');
                    for(Account_Property_Relationship__c apr : aprs){
                        Set<String>subnames=new Set<String>(String.join(new Set<String>(apr.Account__r.Name.split(' & ')),' ').split(' '));
                        subnames.remove('');
                        System.debug('matchGuideChunks: APR: (Account Name='+apr.Account__r.Name+' ... subnames='+subnames+' )');
                        for(String subname : subnames){
                            subname=subname.toUpperCase();
                            System.debug('current sub='+subname+' boolTest(foundNameChunks.contains('+subname+') = '+foundNameChunks.contains(subname));
                            if(foundNameChunks.contains(subname)){
                                System.debug('Score hit: start Score='+score);
                                score=score+1;
                                System.debug('Score hit: cur Score='+score);
                            }
                        }

                        if(score>=scoreMap.get(p.Id)){
                            scoreMap.put(p.Id,score);
                            bestMatchMap.put(p.Id,p);
                        }
                    }
                }
                if(score==0&&scopeMap.get(p.Id).Leads__r.size()>0){
                    List<Lead>leads=scopeMap.get(p.Id).Leads__r;
                    System.debug('NAMEMATCH: Lead Start: (Lead Count='+leads.size()+' )');
                    for(Lead l : leads){
                        Set<String>subnames=new Set<String>{(l.FirstName??'').toUpperCase(),(l.LastName??'').toUpperCase(),(l.SecondaryContactFirstName__c??'').toUpperCase(),(l.Secondary_Contact_Last_Name__c??'').toUpperCase()};
                        subnames.remove('');
                        System.debug('matchGuideChunks: Lead: (Lead Name[f:'+l.FirstName+', l:'+l.LastName+', 2f:'+l.SecondaryContactFirstName__c+', 2l'+l.Secondary_Contact_Last_Name__c+' ] ... subnames = '+subnames+' )');
                        for(String subname : subnames){
                            subname=subname.toUpperCase();
                            System.debug('current sub='+subname+' boolTest(foundNameChunks.contains('+subname+') = '+foundNameChunks.contains(subname));
                            if(foundNameChunks.contains(subname)){
                                System.debug('Score hit: start Score='+score);
                                score=score+1;
                                System.debug('Score hit: cur Score='+score);
                            }
                        }
                        if(score>=scoreMap.get(p.Id)){ //could maybe dedupe with this.
                            scoreMap.put(p.Id,score);
                            bestMatchMap.put(p.Id,p);
                        }
                    }
                }
            } else { System.debug('THIS FOUND PROP HAD NO OWNER NAMES: \r'+JSON.serializePretty(p)); }
        }
        System.debug('\r\tNamematcher: SCOREMAP :\r'+JSON.serializePretty(scoreMap));
        System.debug('\r\tNamematcher: BESTMATCHES :\r'+JSON.serializePretty(bestMatchMap));

        return bestMatchMap.values();
    }
    public Map<String,Decimal> getGroupMapInfo(List<Property__c> props){
        final Decimal radius=0.01;
        Decimal maxLat=-90; //these are just initial values so all members get measured
        Decimal maxLng=-180;
        Decimal minLat=90;
        Decimal minLng=180;
        Decimal sumLat=0;
        Decimal sumLng=0;
        for(Property__c p : props){
            if(p.Address__Latitude__s>maxLat){
                maxLat=p.Address__Latitude__s;
            }
            if(p.Address__Longitude__s>maxLng){
                maxLng=p.Address__Longitude__s;
            }
            if(p.Address__Latitude__s<minLat){
                minLat=p.Address__Latitude__s;
            }
            if(p.Address__Longitude__s<minLng){
                minLng=p.Address__Longitude__s;
            }
            sumLat=sumLat+p.Address__Latitude__s;
            sumLng=sumLng+p.Address__Longitude__s;
        }
        Map<String,Decimal>groupMapInfo=new Map<String,Decimal>{
                'nelat'=>maxLat+radius,'nelng'=>maxLng+radius,
                'swlat'=>minLat-radius,'swlng'=>minLng-radius,'celat'=>(sumLat/props.size()),'celng'=>(sumLng/props.size()),
                'limit'=>props.size(),'offset'=>0
        };
        System.debug('getGroupMapInfo ... ('+props.size()+' props processed) End values:::{  '+groupMapInfo+'  }');
        return groupMapInfo;
    }
    public static String cursoryStreetCleaning(String street){
        String preCleaned=street.replaceAll('#(N/A|VALUE!|REF!|NAME\\?)','');
        //TODO See if this fucks it up by deleting the emdash.
        preCleaned=street.replaceAll('['+Pattern.quote(badChars)+']','');
        // Only proceed if there is NOT a known suffix in the string
        List<String>spacedSuffixes=(' '+(String.join(SfMapsRetriever.allSuffixes,' , '))+' ').split(',');
        Boolean hasSuffix=false;
        String actingStreet=(street.toUpperCase()).remove(' DR');
        for(String sufx:spacedSuffixes){
            if(actingStreet.toUpperCase().contains(sufx)){
                hasSuffix=true;
            }
        }
        if(hasSuffix&&street.toUpperCase().contains(' DR')&&
                ((street.toUpperCase().substringAfterLast(' DR ').isAlphanumeric()&&street.toUpperCase().substringAfterLast(' DR ').length()<=4&&street.toUpperCase().substringAfterLast(' DR ').length()>0) ||
                (street.toUpperCase().substringAfterLast(' DR').isAlphanumeric()&&street.toUpperCase().substringAfterLast(' DR').length()<=4&&street.toUpperCase().substringAfterLast(' DR').length()>0))){
            // Replace ' DR' followed optionally by space, then 1-2 letters OR any number of digits
            preCleaned=street.replaceAll(' DR\\s*([A-Za-z0-9]{1,4})$','[DRWY $1]'); //the 1 space leftpad is a mailingFound flag;
            System.debug(' ——–[–DRWY–FOUND!–]——> ( Original : '+street+', Preclean : '+preCleaned+' )');
        }
        return preCleaned;
    }
    public static String authEval(String street,String statecode){
        String state=PropertyPirateShip.stateFulls.get(statecode);
        street=street.toUpperCase();
        System.debug('authlevelCheck: street='+street+', state='+state);
        if(street.contains(' US-')||street.contains(' '+statecode+'-')||street.contains(' '+state+'-')){
            street=street.substringBefore('-')+'—HWY '+street.substringAfter('-');
        }
        if(street.contains('HIGHWAY')){
            street=street.replace('HIGHWAY','HWY');
        }
        if(street.contains(' OLD ')){
            street=street.replace(' OLD ',' OLD-');
        }
        if(street.contains(' RD ')){
            street=street.replace(' RD ',' ROAD ');
        }
        Map<String,String>authCheckMap=new Map<String,String>{'US'=>'US—HWY','STATE'=>'STATE—HWY','ST'=>'STATE—HWY',
                        state=>statecode+'—HWY',statecode=>statecode+'—HWY','COUNTY'=>'COUNTY—HWY'
        };
        if(street.contains(' HWY ')){
            String sPrior=(street.substringBefore(' HWY ')).substringAfterLast(' ');
            if(authCheckMap.containsKey(sPrior)){
                System.debug('SPRIOR—> '+sPrior);
                street=street.replace(sPrior+' HWY',authCheckMap.get(sPrior));
            } else {
                System.debug('SLIPPED THROUGH!~> '+street);
            }

        } else {
            if(street.contains('COUNTY ROAD')){
                street=street.replace('COUNTY ROAD','COUNTY_ROAD');
            } else if (street.contains(' US ')) {
                street = street.replace(' US ', ' US—HWY ');
            } else if (street.contains(' ' + state + ' ')) {
                street = street.replace(' ' + state + ' ', ' ' + statecode + '—HWY ');
            } else if ((street.contains(' ' + statecode + ' ')) && street.substringAfter(' ' + statecode + ' ').isNumeric()) {
                street = street.replace(' ' + statecode + ' ', ' ' + statecode + '—HWY ');
            }
        }
        return street;
    }
    public static List<Map<String,Object>> layerFilterBitch(String city,String dir,String route,Set<String>numbs){ // ,String mode,List<Map<String,Object>> returning later
        List<Map<String,Object>>routeFilters=new List<Map<String,Object>>();
//        Map<String,String>modulationMap=new Map<String,String>{
//                'D'=>dir,'R'=>route,'S'=>''
//        };
//        String modalStreet;
//        if(mode.contains('A')){
//            for(String modeTerm : mode.split('')){
//                modalStreet=modalStreet+modulationMap.get(modeTerm);
//            }
//        } else {
//            for(String modeTerm : mode.split('')){
//                modalStreet=modalStreet+modulationMap.get(modeTerm);
//            }
//        }
        List<String>vals=new List<String>(numbs);
        routeFilters.add(new Map<String,Object>{'operator'=>'equals','topic_id'=>cityTopic,'values'=>city});
        if(dir!=''){
            vals.add(dir+' '+route); //maybe figure out how to do 123 Rd 25 E
        }
        if(route!=''){
            vals.add(' '+route+' ');
            if(route.isNumeric()){
                if(route.right(2)=='13'||route.right(2)=='12'||route.right(2)=='11'||(route.right(1)!='1'&&route.right(1)!='2'&&route.right(1)!='3')){
                    vals.add(route+'TH');
                } else if(route.right(1)=='3'){
                    route=route+'RD';
                } else if(route.right(1)=='2'){
                    route=route+'ND';
                } else if(route.right(1)=='1'){
                    route=route+'ST';
                }
                vals.add(' '+route+' ');
            }
        }
        routeFilters.add(new Map<String,Object>{'operator'=>'contains','topic_id'=>streetTopic,'values'=>vals});
        return routeFilters;
    }

//    public class nebraskaRules{        //generally marked in the format of S-x-Y or L-x-Y, where S or L indicates whether it is a spur or a link, x is the county the highway is in, ranks alphabetically (1 is Adams County,93 is York County)
//        final Map<String,Integer> neCountyRdNumbs = new Map<String,Integer>{
//                'Adams'=>1,'Antelope'=>2,'Arthur'=>3,'Banner'=>4,'Blaine'=>5,'Boone'=>6,'Box Butte'=>7,'Boyd'=>8,'Brown'=>9,'Buffalo'=>10,'Burt'=>11,'Butler'=>12,
//                'Cass'=>13,'Cedar'=>14,'Chase'=>15,'Cherry'=>16,'Cheyenne'=>17,'Clay'=>18,'Colfax'=>19,'Cuming'=>20,'Custer'=>21,
//                'Dakota'=>22,'Dawes'=>23,'Dawson'=>24,'Deuel'=>25,'Dixon'=>26,'Dodge'=>27,'Douglas'=>28,'Dundy'=>29,
//                'Fillmore'=>30,'Franklin'=>31,'Frontier'=>32,'Furnas'=>33,'Gage'=>34,'Garden'=>35,'Garfield'=>36,'Gosper'=>37,'Grant'=>38,'Greeley'=>39,
//                'Hall'=>40,'Hamilton'=>41,'Harlan'=>42,'Hayes'=>43,'Hitchcock'=>44,'Holt'=>45,'Hooker'=>46,'Howard'=>47,'Jefferson'=>48,'Johnson'=>49,
//                'Kearney'=>50,'Keith'=>51,'Keya Paha'=>52,'Kimball'=>53,'Knox'=>54,'Lancaster'=>55,'Lincoln'=>56,'Logan'=>57,'Loup'=>58,
//                'Madison'=>59,'McPherson'=>60,'Merrick'=>61,'Morrill'=>62,'Nance'=>63,'Nemaha'=>64,'Nuckolls'=>65,'Otoe'=>66,
//                'Pawnee'=>67,'Perkins'=>68,'Phelps'=>69,'Pierce'=>70,'Platte'=>71,'Polk'=>72,'Red Willow'=>73,'Richardson'=>74,'Rock'=>75,
//                'Saline'=>76,'Sarpy'=>77,'Saunders'=>78,'Scotts Bluff'=>79,'Seward'=>80,'Sheridan'=>81,'Sherman'=>82,'Sioux'=>83,'Stanton'=>84,
//                'Thayer'=>85,'Thomas'=>86,'Thurston'=>87,'Valley'=>88,'Washington'=>89,'Wayne'=>90,'Webster'=>91,'Wheeler'=>92,'York'=>93
//        };
//        Map<String,Integer> reqMap = new Map<String,Integer>{
//                'Adams'=>1,'Antelope'=>3,'Arthur'=>5,'Banner'=>7,'Blaine'=>9,'Boone'=>11,'Box Butte'=>13,'Boyd'=>15,'Brown'=>17,'Buffalo'=>19,'Burt'=>21,'Butler'=>23,
//                'Cass'=>25,'Cedar'=>27,'Chase'=>29,'Cherry'=>31,'Cheyenne'=>33,'Clay'=>35,'Colfax'=>37,'Cuming'=>39,'Custer'=>41,'Dakota'=>43,'Dawes'=>45,'Dawson'=>47,'Deuel'=>49,'Dixon'=>51,'Dodge'=>53,'Douglas'=>55,'Dundy'=>57,
//                'Fillmore'=>59,'Franklin'=>61,'Frontier'=>63,'Furnas'=>65,'Gage'=>67,'Garden'=>69,'Garfield'=>71,'Gosper'=>73,'Grant'=>75,'Greeley'=>77,
//                'Hall'=>79,'Hamilton'=>81,'Harlan'=>83,'Hayes'=>85,'Hitchcock'=>87,'Holt'=>89,'Hooker'=>91,'Howard'=>93,'Jefferson'=>95,'Johnson'=>97,
//                'Kearney'=>99,'Keith'=>101,'Keya Paha'=>103,'Kimball'=>105,'Knox'=>107,'Lancaster'=>109,'Lincoln'=>111,'Logan'=>113,'Loup'=>115,
//                'Madison'=>117,'McPherson'=>119,'Merrick'=>121,'Morrill'=>123,'Nance'=>125,'Nemaha'=>127,'Nuckolls'=>129,'Otoe'=>131,
//                'Pawnee'=>133,'Perkins'=>135,'Phelps'=>137,'Pierce'=>139,'Platte'=>141,'Polk'=>143,'Red Willow'=>145,'Richardson'=>147,'Rock'=>149,
//                'Saline'=>151,'Sarpy'=>153,'Saunders'=>155,'Scotts Bluff'=>157,'Seward'=>159,'Sheridan'=>161,'Sherman'=>163,'Sioux'=>165,'Stanton'=>167,
//                'Thayer'=>169,'Thomas'=>171,'Thurston'=>173,'Valley'=>175,'Washington'=>177,'Wayne'=>179,'Webster'=>181,'Wheeler'=>183,'York'=>185
//        };
//    }
}