/**
 * Created by BENJAMIN on 1/20/2025.
 */
@IsTest
public with sharing class SfMapsAPITest {
    public static Map<String,Object> mockResMap=new Map<String,Object>{
            'endpoint'=>'https://internal.na.sfmapsapi.com/data/markers/3',
            'limitInfo'=>new Map<String,String>{
                    'QueryRows'=>'12 / 50000',
                    'Queries'=>'9 / 100',
                    'HeapSize'=>'87773 / 6000000','CPUTime'=>'165 / 10000'
            },
            'request'=>'mock',
            'params'=>new Map<String,Object>{
                    'data'=>new Map<String,Object>{
                            'filters'=>new List<Map<String,Object>>{
                                    new Map<String,Object>{
                                            'operator'=>'equals',
                                            'topic_id'=>'propertyaddressfull',
                                            'values'=>new List<String>{
                                                    '3430 N 63rd St','1400 W Washington St'
                                            }
                                    },
                                    new Map<String,Object>{
                                            'operator'=>'equals',
                                            'topic_id'=>'propertyaddresscity',
                                            'values'=>'LINCOLN'
                                    }
                            },
                            'defaultMarkerColor'=>'D31A28:Circle',
                            'level_id'=>'attom-1',
                            'file_id'=>'usa_property_sfdc'
                    },
                    'mapinfo'=>new Map<String,Decimal>{
                            'nelat'=>40.857168872017620,
                            'nelng'=>-96.624134159702750,
                            'swlat'=>40.788445304073184,
                            'swlng'=>-96.751897569694500,
                            'celat'=>40.822807088045402,
                            'celng'=>-96.688015864698625,
                            'limit'=>50,
                            'offset'=>0
                    }
            },
            'success'=>true,
            'data'=>new Map<String,List<Integer>>{
                    'ids'=>new List<Integer>{195672075,1925588}
            }
    };
    public static List<String> inTopics=new List<String>{
            'propertyaddresszip','propertyaddresscity','propertylatitude','propertylongitude','partyowner1namefull','partyowner2namefull','contactownermailaddressfull',
            'statusowneroccupiedflag','construction','structurestyle','legalsubdivision','situscounty','parcelnumberformatted','foundation','roofmaterial','roomscount',
            'batcount','bedroomscount','storiescount','unitscount','buildingscount','areabuilding','areagross','arealotsf','fireplacecount','fireplacecount'
    };
    @TestSetup
    static void setupTestData(){
        List<Property__c> propsIn=new List<Property__c>();
        propsIn.add(new Property__c(Name='3430 North 63rd Street Lincoln, NE',Address__Street__s='3430 North 63rd Street',Address__City__s='Lincoln',Address__StateCode__s='NE',Address__PostalCode__s='68507'
        ,Address__Latitude__s=40.84716887201762,Address__Longitude__s=-96.63413415970275
        ));
        propsIn.add(new Property__c(Name='1400 West Washington Street Lincoln, NE',Address__Street__s='1400 West Washington Street',Address__City__s='Lincoln',Address__StateCode__s='NE',Address__PostalCode__s='68522'
        ,Address__Latitude__s=40.798445304073184,Address__Longitude__s=-96.7418975696945
        ));
        propsIn.add(new Property__c(Name='xxx',Address__Street__s='xxx',Address__City__s='Hickman',Address__StateCode__s='NE',Address__PostalCode__s='68372'
        ));
        insert propsIn;
        System.debug('props in setup - '+propsIn);
    }
    public static List<Property__c> props=[SELECT Id,Name,Address__c,Address__Street__s,Mailing_Only_Address__c,Address__City__s,Address__StateCode__s,Address__CountryCode__s,Address__PostalCode__s,Address__Latitude__s,Address__Longitude__s FROM Property__c WHERE Address__Street__s!=NULL AND Address__City__s != NULL AND CreatedDate=TODAY ORDER BY LastModifiedDate ASC LIMIT 2];
    public static List<Property__c> aProp=[SELECT Id,Name,Address__c,Address__Street__s,Mailing_Only_Address__c,Address__City__s,Address__StateCode__s,Address__CountryCode__s,Address__PostalCode__s,Address__Latitude__s,Address__Longitude__s FROM Property__c WHERE Address__Street__s!=NULL AND Address__City__s != NULL AND Address__Street__s='3430 North 63rd Street' LIMIT 1];
    @IsTest
    static void testSetupAPI(){
        String source = 'property';
        String streetTopic = 'testStrTopic';
        String cityTopic = 'testCityTopic';
        Boolean routeFiltering = true;
        String badChars = '@#$%';
        List<PropertyPirateShip.pirateShipFilter>filts=new List<PropertyPirateShip.pirateShipFilter>();
        Test.startTest();
        PropertyPirateShip pps=new PropertyPirateShip(new Set<String>(inTopics),filts,20,source,streetTopic,cityTopic,routeFiltering,badChars,true,null);
        SFMapsAPI sfmapi = pps.setupAPI(props);
        Test.stopTest();
        System.debug(sfmapi);
        System.debug(SFMapsAPI.class);
        System.assertEquals(source,SFMapsAPI.source);
        System.assertEquals(streetTopic,SFMapsAPI.streetTopic);
        System.assertEquals(cityTopic,SFMapsAPI.cityTopic);
        System.assertEquals(routeFiltering,SFMapsAPI.isRouteSplitting);
        System.assertEquals(source,SFMapsAPI.source);
        System.assertEquals(badChars,SFMapsAPI.badChars);
    }
    @IsTest
    static void testPrepCleaners(){
        List<Property__c> cleaned = PropertyPirateShip.prepCleaners(props);
        System.assertEquals(props.size(),cleaned.size(),'Should return same number of records');
        Set<Id> originalIds = new Set<Id>();
        for (Property__c p : props) {
            originalIds.add(p.Id);
        }
        for (Property__c c : cleaned) {
            System.assert(originalIds.contains(c.Id), 'Returned record should match original Id');
            System.assertEquals(true, c.Pirateship_Checked__c, 'Pirateship_Checked__c should be true');
        }
    }
    @IsTest
    static void testSfMapsApiThirdConstructor() {
        List<PropertyPirateShip.pirateShipFilter> pirateFilters=new List<PropertyPirateShip.pirateShipFilter>{
                new PropertyPirateShip.pirateShipFilter('Name','=','')
        };
        PropertyPirateShip pps=new PropertyPirateShip(new Set<String>(inTopics),pirateFilters,2,'property','propertyaddressfull','propertyaddresscity',false,null,true,null);
        SFMapsAPI sfmapi = pps.setupAPI(props);
        SfMapsRetriever.makeFilterMaps(props);
        SFMapsAPI.geographicIds=(List<Integer>)((Map<String,Object>)mockResMap.get('data')).get('ids');
        System.debug('\r–——sfmapi1–topics——>\r'+sfmapi.topics);
        System.debug('\r–——sfmapi1–props——>\r'+sfmapi.props);
        System.debug('\r–——SFMapsAPI–Class——>\r'+SFMapsAPI.class);
        System.debug('\r–——sfmapi1–sfmr1——>\r'+JSON.serializePretty(sfmapi.sfmr));
        MockHttpResponse markermockres=new MockHttpResponse(
                new Map<String,Object>{'data'=>new Map<String,Object>{'markers'=>new List<Object>{'d'}}});
        Test.setMock(HttpCalloutMock.class,markermockres);
        Test.startTest();
        sfmapi = new SFMapsAPI(props,inTopics);
        sfmapi.sfmr.response=(Map<String,Object>)JSON.deserializeUntyped(JSON.serialize(markermockres));
        Test.stopTest();
        System.debug('\r–——sfmapi2–props——>\r'+sfmapi.props);
        System.debug('\r–——sfmapi2–insertProps——>\r'+sfmapi.insertProps);
        System.debug('\r–——sfmapi2–sfmr——>\r'+JSON.serializePretty(sfmapi.sfmr));
        System.debug('\r–——end-SFMapsAPI–Class——>\r'+SFMapsAPI.class);
        System.assertNotEquals(null, sfmapi, 'instance should be created');
        System.assertNotEquals(null, sfmapi.props, 'Props list should not be null');
        System.assert(sfmapi.props.size()<=2,'props size should be <= input size');
    }
    @IsTest
    static void testMakeFilterMaps(){
        List<Property__c> extraProps=new List<Property__c>{
                new Property__c(Name='1610 Lake Street Beatrice, NE',Address__Street__s='1610 Lake Street',Address__City__s='Beatrice',Address__StateCode__s='NE',Address__PostalCode__s='68310',Address__CountryCode__s='US',Address__Latitude__s=40.2489945,Address__Longitude__s= -96.7523966),
                new Property__c(Name='29107 U.S. 77 Beatrice, NE',Address__Street__s='29107 U.S. 77',Address__City__s='Beatrice',Address__StateCode__s='NE',Address__PostalCode__s='68310',Address__CountryCode__s='US',Address__Latitude__s=40.2365882,Address__Longitude__s=-96.7473018),
                new Property__c(Name='29107 US 77 Beatrice, NE',Address__Street__s='29107 US-77',Address__City__s='Beatrice',Address__StateCode__s='NE',Address__PostalCode__s='68310',Address__CountryCode__s='US',Address__Latitude__s=40.2365882,Address__Longitude__s=-96.7473018),
                new Property__c(Name='29107 US Highway 77 Beatrice, NE',Address__Street__s='29107 US Highway 77',Address__City__s='Beatrice',Address__StateCode__s='NE',Address__PostalCode__s='68310',Address__CountryCode__s='US',Address__Latitude__s=40.2365882,Address__Longitude__s=-96.7473018),
                new Property__c(Name='29107 Highway 77 Beatrice, NE',Address__Street__s='29107 Highway 77',Address__City__s='Beatrice',Address__StateCode__s='NE',Address__PostalCode__s='68310',Address__CountryCode__s='US',Address__Latitude__s=40.2365882,Address__Longitude__s=-96.7473018),
                new Property__c(Name='4239 NE-4 Beatrice, NE',Address__Street__s='4239 NE-4',Address__City__s='Beatrice',Address__StateCode__s='NE',Address__PostalCode__s='68310',Address__CountryCode__s='US',Address__Latitude__s=40.2755282,Address__Longitude__s=-96.7815948),
                new Property__c(Name='4239 Hwy 4 Beatrice, NE',Address__Street__s='4239 Hwy 4',Address__City__s='Beatrice',Address__StateCode__s='NE',Address__PostalCode__s='68310',Address__CountryCode__s='US',Address__Latitude__s=40.2755282,Address__Longitude__s=-96.7815948),
                new Property__c(Name='4239 Nebraska 4 Beatrice, NE',Address__Street__s='4239 Nebraska 4',Address__City__s='Beatrice',Address__StateCode__s='NE',Address__PostalCode__s='68310',Address__CountryCode__s='US',Address__Latitude__s=40.2755282,Address__Longitude__s=-96.7815948),
                new Property__c(Name='111 South \'5th\' Street Beatrice, NE',Address__Street__s='111 South \'5th\' Street',Address__City__s='Beatrice',Address__StateCode__s='NE',Address__PostalCode__s='68310',Address__CountryCode__s='US',Address__Latitude__s=40.2658,Address__Longitude__s=-96.7466),
                new Property__c(Name='#VALUE! Beatrice, NE',Address__Street__s='#VALUE!',Address__City__s='Beatrice',Address__StateCode__s='NE',Address__PostalCode__s='68310',Address__CountryCode__s='US',Address__Latitude__s=40.2658,Address__Longitude__s=-96.7466),
                new Property__c(Name='#REF! Beatrice, NE',Address__Street__s='#REF!',Address__City__s='Beatrice',Address__StateCode__s='NE',Address__PostalCode__s='68310',Address__CountryCode__s='US',Address__Latitude__s=40.2658,Address__Longitude__s=-96.7466),
                new Property__c(Name='#NAME? Beatrice, NE',Address__Street__s='#NAME?',Address__City__s='Beatrice',Address__StateCode__s='NE',Address__PostalCode__s='68310',Address__CountryCode__s='US',Address__Latitude__s=40.2658,Address__Longitude__s=-96.7466),
                new Property__c(Name='#N/A Beatrice, NE',Address__Street__s='#N/A',Address__City__s='Beatrice',Address__StateCode__s='NE',Address__PostalCode__s='68310',Address__CountryCode__s='US',Address__Latitude__s=40.2658,Address__Longitude__s=-96.7466)
        };
        insert extraProps;
        List<Property__c> qProps=[SELECT Id,Name,Address__c,Address__Street__s,Mailing_Only_Address__c,Address__City__s,Address__StateCode__s,Address__CountryCode__s,Address__PostalCode__s,Address__Latitude__s,Address__Longitude__s FROM Property__c WHERE Address__Street__s!=NULL AND Address__City__s != NULL AND CreatedDate=TODAY ORDER BY LastModifiedDate ASC];
        Map<String,List<String>>searchMapCity=new Map<String,List<String>>();
        Map<String,List<String>>searchMapRoute=new Map<String,List<String>>();
        Map<String,Id>keyMapCity=new Map<String,Id>();
        Map<String,Id>keyMapRoute=new Map<String,Id>();
        SfMapsRetriever sfmr=new SfMapsRetriever('property','propertyaddressfull','propertyaddresscity',false,null);
        Test.startTest();
        SfMapsRetriever.makeFilterMaps(qProps);
        searchMapCity=SfMapsRetriever.searchMap;
        keyMapCity=SfMapsRetriever.keyMap;

        sfmr=new SfMapsRetriever('property','propertyaddressfull','propertyaddresscity',true,null);
        SfMapsRetriever.makeFilterMaps(qProps);
        searchMapRoute=SfMapsRetriever.searchMap;
        keyMapRoute=SfMapsRetriever.keyMap;
        Test.stopTest();
        System.debug('City: searchMap—>'+JSON.serializePretty(searchMapCity));
        System.debug('City: keyMap—>'+JSON.serializePretty(keyMapCity));
        System.debug('Route: searchMap—>'+JSON.serializePretty(searchMapRoute));
        System.debug('Route: keyMap—>'+JSON.serializePretty(keyMapRoute));

        System.assertEquals(true,searchMapCity.get('LINCOLN').contains('3430 N 63RD ST'));
        System.assertEquals(true,searchMapCity.get('LINCOLN').contains('1400 W WASHINGTON ST'));
        System.assertEquals(2,searchMapCity.keySet().size());
        System.assertEquals(15,searchMapCity.get('BEATRICE').size());
        System.assertEquals(2,searchMapCity.get('LINCOLN').size());

        List<String>keychains=new List<String>();
        for(Property__c p : qProps){
            Map<String,String>routeMap=SfMapsRetriever.getRouteMap(p.Address__Street__s,p.Address__City__s);
            String keychain=routeMap.get('city')+','+routeMap.get('route')+','+routeMap.get('dir');
            keychains.add(keychain);
        }
        keychains.sort();
        System.debug('searchMapRoute.keySet—>'+searchMapRoute.keySet()+'\rAlphabetizedKeychains—>'+keychains);
//      System.assertEquals(searchMapRoute.keySet().size(),keychains.size());//System.assertEquals(searchMapRoute.keySet().size(),keyMapRoute.keySet().size());
        Integer keyX=searchMapRoute.keySet().size();
        for(String key : searchMapRoute.keySet()){
//      System.debug('[@'+keyX+'/'+searchMapRoute.keySet().size()+'] searchMap: '+key+' ,keychains: '+keychains[keyX]);
            keyX++;
        }
        keyX=0;
        for(String key : keyMapRoute.keySet()){
            System.debug('\r[@'+keyX+'/'+keyMapRoute.keySet().size()+'] searchMap: '+key+' ,keychains: '+keychains[keyX]);
            keyX++;
        }
    }
    @IsTest
    static void testMakeCityGeoIdReqString(){
        String expectedReqString='{"mapinfo":{"offset":0,"limit":2,"celng":-96.688015864698625,"celat":40.822807088045402,"swlng":-96.751897569694500,"swlat":40.788445304073184,"nelng":-96.624134159702750,"nelat":40.857168872017620},"data":{"file_id":"usa_property_sfdc","level_id":"attom-1","defaultMarkerColor":"D31A28:Circle","filters":[{"values":["3430 N 63RD ST","1400 W WASHINGTON ST"],"topic_id":"propertyaddressfull","operator":"equals"},{"values":"LINCOLN","topic_id":"propertyaddresscity","operator":"equals"}]}}';
        Test.startTest();
        SfMapsRetriever sfmr=new SfMapsRetriever('property','propertyaddressfull','propertyaddresscity',false,null);
        SfMapsRetriever.makeFilterMaps(props);
        System.debug('searchMap='+SfMapsRetriever.searchMap);
        String reqStringMethod=sfmr.makeCityGeoIdReqString(props,'LINCOLN');
        System.debug('reqStringMethod='+reqStringMethod);
        Test.stopTest();
        System.assertEquals(expectedReqString,reqStringMethod,'WE can do a different one later with 2 cities');
    }
    @IsTest
    static void testMakeRouteGeoIdReqString(){
//        String expectedReqString='{"mapinfo":{"offset":0,"limit":2,"celng":-96.688015864698625,"celat":40.822807088045402,"swlng":-96.751897569694500,"swlat":40.788445304073184,"nelng":-96.624134159702750,"nelat":40.857168872017620},"data":{"file_id":"usa_property_sfdc","level_id":"attom-1","defaultMarkerColor":"D31A28:Circle","filters":[{"values":["3430 N 63RD ST","1400 W WASHINGTON ST"],"topic_id":"propertyaddressfull","operator":"equals"},{"values":"LINCOLN","topic_id":"propertyaddresscity","operator":"equals"}]}}';
        SfMapsRetriever sfmr=new SfMapsRetriever('property','propertyaddressfull','propertyaddresscity',true,null);
        Test.startTest();
        SfMapsRetriever.makeFilterMaps(aProp);
        System.debug('searchMap='+SfMapsRetriever.searchMap);
        String reqStringMethod=sfmr.makeRouteGeoIdReqString(aProp,'LINCOLN,63RD,N');
        System.debug('reqStringMethod='+reqStringMethod);
        Test.stopTest();//System.assertEquals(expectedReqString,reqStringMethod,'WE can do a different one later with 2 cities');
    }
    @IsTest
    static void makeGeoIdRouteStringUNIFIED(){
        List<Property__c> props = [SELECT Id,Name, Address__c,Address__Street__s,Mailing_Only_Address__c,Address__City__s,Address__StateCode__s,Address__CountryCode__s,Address__PostalCode__s,Address__Latitude__s,Address__Longitude__s,attom_Id__c FROM Property__c WHERE Address__Street__s!=NULL AND Address__City__s != NULL AND
        Address__Street__s='3430 North 63rd Street' LIMIT 1];
        SFMapsAPI.geographicIds=(List<Integer>)((Map<String,Object>)mockResMap.get('data')).get('ids');
        SFMapsAPI sfmapi=new SFMapsAPI('property','propertyaddressfull','propertyaddresscity',false,null);
        SfMapsRetriever.makeFilterMaps(props);
        System.debug('SfMapsRetriever.streetTopic:\r'+SfMapsRetriever.streetTopic);
        System.debug('SfMapsRetriever.cityTopic:\r'+SfMapsRetriever.cityTopic);
        System.debug('SfMapsRetriever.searchMap:\r'+SfMapsRetriever.searchMap);
        System.debug('SfMapsRetriever.keyMap:\r'+SfMapsRetriever.keyMap);
        System.debug('SfMapsRetriever.streetTopic:\r'+SfMapsRetriever.streetTopic);
        System.debug('SfMapsRetriever.cityTopic:\r'+SfMapsRetriever.cityTopic);
        System.debug('SfMapsRetriever.searchMap:\r'+SfMapsRetriever.searchMap);
        System.debug('SfMapsRetriever.keyMap:\r'+SfMapsRetriever.keyMap);
        Test.startTest();
        SfMapsRetriever.makeFilterMaps(props);
        SFMapsAPI sfmapi2=new SFMapsAPI(props);
        System.debug('searchMap='+SfMapsRetriever.searchMap);
        String reqStringMethod = sfmapi.sfmr.makeCityGeoIdReqString(props,'LINCOLN, 63RD,N');
        System.debug('reqStringMethod='+reqStringMethod);
        Test.stopTest();
    }
    @IsTest
    static void testGetGeoIdsByCity(){
        SfMapsRetriever sfmr=new SfMapsRetriever('property','propertyaddressfull','propertyaddresscity',false,null);
        SfMapsRetriever.makeFilterMaps(props);
//        System.debug('test cityFilterPropMap='+SfMapsRetriever.cityFilterPropMap);
        System.debug('test searchMap='+SfMapsRetriever.searchMap);
        Test.startTest();
        sfmr=new SfMapsRetriever(props,'LINCOLN');
        Map<String,Object> methodRes=sfmr.getGeoIdResponse(sfmr.reqString);
        System.debug('sfmr.response='+sfmr.response);
        System.debug('methodRes='+methodRes);
        sfmr.response=mockResMap;
        Test.stopTest();
        List<Integer> geoIds=sfmr.procGeoIdResponse(sfmr.response);
        System.assertEquals(new List<Integer>{195672075,1925588},geoIds);
    }
    @IsTest
    static void testGetGeoIdsByRoute(){
        SfMapsRetriever sfmr=new SfMapsRetriever('property','propertyaddressfull','propertyaddresscity',true,null);
        SfMapsRetriever.makeFilterMaps(aProp);
        System.debug(SfMapsRetriever.isRouteSplitting);
        System.assertEquals(SfMapsRetriever.isRouteSplitting,true);
        System.debug('testing aProp[0].street='+aProp[0].Address__Street__s+'...testing aProp[0].city='+aProp[0].Address__City__s);
        Map<String,String>routeMap=SfMapsRetriever.getRouteMap(aProp[0].Address__Street__s,aProp[0].Address__City__s);
        System.debug('testing getRouteMap: '+SfMapsRetriever.getRouteMap(aProp[0].Address__Street__s,aProp[0].Address__City__s));
        String keychain=routeMap.get('city')+','+routeMap.get('route')+','+routeMap.get('dir');
        String reqString=sfmr.makeRouteGeoIdReqString(aProp,keychain);
        Test.startTest();
        Map<String,Object>response=sfmr.getGeoIdResponse(reqString);
        sfmr.response=mockResMap;
        Test.stopTest();
        System.assertNotEquals(null,JSON.serialize(response));
        List<Integer> geoIds=sfmr.procGeoIdResponse(sfmr.response);
        System.assertEquals(new List<Integer>{195672075,1925588},geoIds);
    }
    @IsTest
    static void testGetHostedDataReqString(){
        List<String> topics=new List<String>{'propertyaddressfull','propertyaddresszip','propertyaddresscity','propertylatitude','propertylongitude',
                'partyowner1namefull','partyowner2namefull','contactownermailaddressfull','statusowneroccupiedflag','construction','structurestyle',
                'legalsubdivision','situscounty','parcelnumberformatted','foundation','roofmaterial','roomscount','bathcount','bedroomscount','storiescount',
                'unitscount','buildingscount','areabuilding','areagross','arealotsf','fireplacecount','ownertypedescription1','ownertypedescription2',
                'currentfirstpositionmortgagetype','currentsecondpositionmortgagetype','availableequity','ltv','currentfirstpositionopenloaninterestrate',
                'currentsecondpositionopenloaninterestrate','ownershipvestingrelationcode','deedlastsaledate','taxyearassessed','taxassessedvaluetotal',
                'taxassessedvalueland','taxassessedvalueimprovements','previousassessedvalue','taxbilledamount','taxmarketvalueland','taxmarketvalueimprovements',
                'taxmarketvaluetotal','taxfiscalyear','yearbuilt','yearbuilteffective','propertyjurisdictionname','deedlastsaleprice','exterior1code',
                'propertyjurisdictionname'
        };

        String expectedReqString='{"mapinfo":{"offset":0,"limit":2,"celng":-96.688015864698625,"celat":40.822807088045402,"swlng":-96.751897569694500,"swlat":40.788445304073184,"nelng":-96.624134159702750,"nelat":40.857168872017620},"data":{"popup":{"tabs":[{"data":[{"topic_id":"propertyaddressfull","file_id":"usa_property_sfdc"},{"topic_id":"propertyaddresszip","file_id":"usa_property_sfdc"},{"topic_id":"propertyaddresscity","file_id":"usa_property_sfdc"},{"topic_id":"propertylatitude","file_id":"usa_property_sfdc"},{"topic_id":"propertylongitude","file_id":"usa_property_sfdc"},{"topic_id":"partyowner1namefull","file_id":"usa_property_sfdc"},{"topic_id":"partyowner2namefull","file_id":"usa_property_sfdc"},{"topic_id":"contactownermailaddressfull","file_id":"usa_property_sfdc"},{"topic_id":"statusowneroccupiedflag","file_id":"usa_property_sfdc"},{"topic_id":"construction","file_id":"usa_property_sfdc"}],"tab_label":"tabX0","tab_id":"1499862699444"},{"data":[{"topic_id":"structurestyle","file_id":"usa_property_sfdc"},{"topic_id":"legalsubdivision","file_id":"usa_property_sfdc"},{"topic_id":"situscounty","file_id":"usa_property_sfdc"},{"topic_id":"parcelnumberformatted","file_id":"usa_property_sfdc"},{"topic_id":"foundation","file_id":"usa_property_sfdc"},{"topic_id":"roofmaterial","file_id":"usa_property_sfdc"},{"topic_id":"roomscount","file_id":"usa_property_sfdc"},{"topic_id":"bathcount","file_id":"usa_property_sfdc"},{"topic_id":"bedroomscount","file_id":"usa_property_sfdc"},{"topic_id":"storiescount","file_id":"usa_property_sfdc"}],"tab_label":"tabX1","tab_id":"1499862699445"},{"data":[{"topic_id":"unitscount","file_id":"usa_property_sfdc"},{"topic_id":"buildingscount","file_id":"usa_property_sfdc"},{"topic_id":"areabuilding","file_id":"usa_property_sfdc"},{"topic_id":"areagross","file_id":"usa_property_sfdc"},{"topic_id":"arealotsf","file_id":"usa_property_sfdc"},{"topic_id":"fireplacecount","file_id":"usa_property_sfdc"},{"topic_id":"ownertypedescription1","file_id":"usa_property_sfdc"},{"topic_id":"ownertypedescription2","file_id":"usa_property_sfdc"},{"topic_id":"currentfirstpositionmortgagetype","file_id":"usa_property_sfdc"},{"topic_id":"currentsecondpositionmortgagetype","file_id":"usa_property_sfdc"}],"tab_label":"tabX2","tab_id":"1499862699446"},{"data":[{"topic_id":"availableequity","file_id":"usa_property_sfdc"},{"topic_id":"ltv","file_id":"usa_property_sfdc"},{"topic_id":"currentfirstpositionopenloaninterestrate","file_id":"usa_property_sfdc"},{"topic_id":"currentsecondpositionopenloaninterestrate","file_id":"usa_property_sfdc"},{"topic_id":"ownershipvestingrelationcode","file_id":"usa_property_sfdc"},{"topic_id":"deedlastsaledate","file_id":"usa_property_sfdc"},{"topic_id":"taxyearassessed","file_id":"usa_property_sfdc"},{"topic_id":"taxassessedvaluetotal","file_id":"usa_property_sfdc"},{"topic_id":"taxassessedvalueland","file_id":"usa_property_sfdc"},{"topic_id":"taxassessedvalueimprovements","file_id":"usa_property_sfdc"}],"tab_label":"tabX3","tab_id":"1499862699447"},{"data":[{"topic_id":"previousassessedvalue","file_id":"usa_property_sfdc"},{"topic_id":"taxbilledamount","file_id":"usa_property_sfdc"},{"topic_id":"taxmarketvalueland","file_id":"usa_property_sfdc"},{"topic_id":"taxmarketvalueimprovements","file_id":"usa_property_sfdc"},{"topic_id":"taxmarketvaluetotal","file_id":"usa_property_sfdc"},{"topic_id":"taxfiscalyear","file_id":"usa_property_sfdc"},{"topic_id":"yearbuilt","file_id":"usa_property_sfdc"},{"topic_id":"yearbuilteffective","file_id":"usa_property_sfdc"},{"topic_id":"propertyjurisdictionname","file_id":"usa_property_sfdc"},{"topic_id":"deedlastsaleprice","file_id":"usa_property_sfdc"}],"tab_label":"tabX4","tab_id":"1499862699448"},{"data":[{"topic_id":"exterior1code","file_id":"usa_property_sfdc"},{"topic_id":"propertyjurisdictionname","file_id":"usa_property_sfdc"}],"tab_label":"tabX5","tab_id":"1499862699449"}],"header":[{"topic_id":"parcelnumberformatted","file_id":"usa_property_sfdc"}]},"legend":{"rows":[{"color":"46E71B:Circle","values":[""],"operator":"not equal to","topic_id":"propertyaddressfull"}],"subTitle":"","title":"XXX"},"defaultMarkerColor":"46E71B:Circle","level_id":"attom-1","file_id":"usa_property_sfdc"},"aggregates":true,"details":true,"ids":[195672075,1925588]}';
        List<Integer> geographicIds=new List<Integer>{195672075,1925588};
        SfMapsRetriever sfmr=new SfMapsRetriever('property','propertyaddressfull','propertyaddresscity',false,null);
        Test.startTest();
        String constReqString=sfmr.makeHostedDataReqString(props,topics,geographicIds);
        //        sfmapi.sfmr.response=(Map<String,Object>)JSON.deserializeUntyped(expectedReqString);
        Test.stopTest();
        System.debug('Actual='+constReqString);
        System.debug('Expected='+expectedReqString);
        System.assertEquals(expectedReqString,constReqString);
    }
    @IsTest
    static void testProcHostedDataResponse(){
        SfMapsRetriever sfmr=new SfMapsRetriever('property','propertyaddressfull','propertyaddresscity',false,null);
        String resString='{"endPoint":"https://internal.na.sfmapsapi.com/data/markers/3","limitInfo":{"QueryRows":"16 / 50000","Queries":"10 / 100","HeapSize":"129394 / 6000000","CPUTime":"299 / 10000"},"request":"Not necessary","params":{"ids":[195672075,1925588],"details":true,"aggregates":true,"data":{"file_id":"usa_property_sfdc","level_id":"attom-1","defaultMarkerColor":"46E71B:Circle","legend":{"title":"XXX","subTitle":"","rows":[{"topic_id":"propertyaddressfull","operator":"not equal to","values":[""],"color":"46E71B:Circle"}]},"popup":{"header":[{"file_id":"usa_property_sfdc","topic_id":"parcelnumberformatted"}],"tabs":[{"tab_id":"1499862699444","tab_label":"tabX0","data":[{"file_id":"usa_property_sfdc","topic_id":"propertyaddressfull"},{"file_id":"usa_property_sfdc","topic_id":"propertyaddresszip"},{"file_id":"usa_property_sfdc","topic_id":"propertyaddresscity"},{"file_id":"usa_property_sfdc","topic_id":"propertylatitude"},{"file_id":"usa_property_sfdc","topic_id":"propertylongitude"},{"file_id":"usa_property_sfdc","topic_id":"partyowner1namefull"},{"file_id":"usa_property_sfdc","topic_id":"partyowner2namefull"},{"file_id":"usa_property_sfdc","topic_id":"contactownermailaddressfull"},{"file_id":"usa_property_sfdc","topic_id":"statusowneroccupiedflag"},{"file_id":"usa_property_sfdc","topic_id":"construction"}]},{"tab_id":"1499862699445","tab_label":"tabX1","data":[{"file_id":"usa_property_sfdc","topic_id":"structurestyle"},{"file_id":"usa_property_sfdc","topic_id":"legalsubdivision"},{"file_id":"usa_property_sfdc","topic_id":"situscounty"},{"file_id":"usa_property_sfdc","topic_id":"parcelnumberformatted"},{"file_id":"usa_property_sfdc","topic_id":"foundation"},{"file_id":"usa_property_sfdc","topic_id":"roofmaterial"},{"file_id":"usa_property_sfdc","topic_id":"roomscount"},{"file_id":"usa_property_sfdc","topic_id":"bathcount"},{"file_id":"usa_property_sfdc","topic_id":"bedroomscount"},{"file_id":"usa_property_sfdc","topic_id":"storiescount"}]},{"tab_id":"1499862699446","tab_label":"tabX2","data":[{"file_id":"usa_property_sfdc","topic_id":"unitscount"},{"file_id":"usa_property_sfdc","topic_id":"buildingscount"},{"file_id":"usa_property_sfdc","topic_id":"areabuilding"},{"file_id":"usa_property_sfdc","topic_id":"areagross"},{"file_id":"usa_property_sfdc","topic_id":"arealotsf"},{"file_id":"usa_property_sfdc","topic_id":"fireplacecount"},{"file_id":"usa_property_sfdc","topic_id":"ownertypedescription1"},{"file_id":"usa_property_sfdc","topic_id":"ownertypedescription2"},{"file_id":"usa_property_sfdc","topic_id":"currentfirstpositionmortgagetype"},{"file_id":"usa_property_sfdc","topic_id":"currentsecondpositionmortgagetype"}]},{"tab_id":"1499862699447","tab_label":"tabX3","data":[{"file_id":"usa_property_sfdc","topic_id":"availableequity"},{"file_id":"usa_property_sfdc","topic_id":"ltv"},{"file_id":"usa_property_sfdc","topic_id":"currentfirstpositionopenloaninterestrate"},{"file_id":"usa_property_sfdc","topic_id":"currentsecondpositionopenloaninterestrate"},{"file_id":"usa_property_sfdc","topic_id":"ownershipvestingrelationcode"},{"file_id":"usa_property_sfdc","topic_id":"deedlastsaledate"},{"file_id":"usa_property_sfdc","topic_id":"taxyearassessed"},{"file_id":"usa_property_sfdc","topic_id":"taxassessedvaluetotal"},{"file_id":"usa_property_sfdc","topic_id":"taxassessedvalueland"},{"file_id":"usa_property_sfdc","topic_id":"taxassessedvalueimprovements"}]},{"tab_id":"1499862699448","tab_label":"tabX4","data":[{"file_id":"usa_property_sfdc","topic_id":"previousassessedvalue"},{"file_id":"usa_property_sfdc","topic_id":"taxbilledamount"},{"file_id":"usa_property_sfdc","topic_id":"taxmarketvalueland"},{"file_id":"usa_property_sfdc","topic_id":"taxmarketvalueimprovements"},{"file_id":"usa_property_sfdc","topic_id":"taxmarketvaluetotal"},{"file_id":"usa_property_sfdc","topic_id":"taxfiscalyear"},{"file_id":"usa_property_sfdc","topic_id":"yearbuilt"},{"file_id":"usa_property_sfdc","topic_id":"yearbuilteffective"},{"file_id":"usa_property_sfdc","topic_id":"propertyjurisdictionname"},{"file_id":"usa_property_sfdc","topic_id":"deedlastsaleprice"}]},{"tab_id":"1499862699449","tab_label":"tabX5","data":[{"file_id":"usa_property_sfdc","topic_id":"exterior1code"},{"file_id":"usa_property_sfdc","topic_id":"propertyjurisdictionname"},{"file_id":"usa_property_sfdc","topic_id":"propertyusestandardized"}]}]}},"mapinfo":{"nelat":40.857168872017620,"nelng":-96.624134159702750,"swlat":40.788445304073184,"swlng":-96.751897569694500,"celat":40.822807088045402,"celng":-96.688015864698625,"limit":50,"offset":0}},"success":true,"data":{"aggregates":[{"avg":11.5,"sum":23,"max":12,"min":11,"label":"Structure Style Type"},{"avg":0,"sum":0,"max":0,"min":0,"label":"Count: Rooms"},{"avg":3,"sum":6,"max":4,"min":2,"label":"Count: Bathrooms"},{"avg":2.5,"sum":5,"max":3,"min":2,"label":"Count: Bedrooms"},{"avg":1.5,"sum":3,"max":2,"min":1,"label":"Count: Stories"},{"avg":0,"sum":0,"max":0,"min":0,"label":"Count: Units"},{"avg":0,"sum":0,"max":null,"min":null,"label":"Count: Buildings"},{"avg":1103.5,"sum":2207,"max":1432,"min":775,"label":"Area of Total Living Space (Square Feet)"},{"avg":2080,"sum":4160,"max":2610,"min":1550,"label":"Gross Area of All Structures (Square Footage)"},{"avg":8494.5,"sum":16989,"max":10019,"min":6970,"label":"Lot Area (Square Footage)"},{"avg":0.5,"sum":1,"max":1,"min":0,"label":"Count: Fireplace"},{"avg":0,"sum":0,"max":null,"min":null,"label":"Available Equity"},{"avg":0,"sum":0,"max":null,"min":null,"label":"Loan-to-Value Ratio (LTV)"},{"avg":0,"sum":0,"max":null,"min":null,"label":"Current First Position Open Loan Interest Rate"},{"avg":0,"sum":0,"max":null,"min":null,"label":"Current Second Position Open Loan Interest Rate"},{"avg":2023,"sum":4046,"max":2023,"min":2023,"label":"Tax: Year Assessed"},{"avg":222800,"sum":445600,"max":269700,"min":175900,"label":"Tax: Assessed Value Total"},{"avg":43500,"sum":87000,"max":52000,"min":35000,"label":"Tax: Assessed Value Land"},{"avg":179300,"sum":358600,"max":217700,"min":140900,"label":"Tax: Assessed Value Improvements"},{"avg":222800,"sum":445600,"max":269700,"min":175900,"label":"Previous Assessed Value"},{"avg":3734.13,"sum":7468.26,"max":4520.18,"min":2948.08,"label":"Tax: Billed Amount"},{"avg":43500,"sum":87000,"max":52000,"min":35000,"label":"Tax: Market Value Land"},{"avg":179300,"sum":358600,"max":217700,"min":140900,"label":"Tax: Market Value Improvements"},{"avg":222800,"sum":445600,"max":269700,"min":175900,"label":"Tax: Market Value Total"},{"avg":2023,"sum":4046,"max":2023,"min":2023,"label":"Tax: Fiscal Year"},{"avg":1974.5,"sum":3949,"max":1996,"min":1953,"label":"Year Built (Primary Structure)"},{"avg":0,"sum":0,"max":null,"min":null,"label":"Year Built (Adjusted for Structural Changes)"},{"avg":187500,"sum":375000,"max":240000,"min":135000,"label":"Deed Last Sale Price"}],"legend":{"rows":[{"values":[""],"row_id":"row-0","operator":"not equal to","color":"46E71B:Circle","topic_id":"propertyaddressfull"},{"values":["--Other--"],"row_id":"row-other","operator":"equals","color":"46E71B:Circle","topic_id":"propertyaddressfull"}],"subTitle":"","title":"XXX"},"markers":[{"popup":{"tabs":[{"data":[{"formatted_value":"1400 W WASHINGTON ST","value":"1400 W WASHINGTON ST","topic_id":"propertyaddressfull","label":"Property: Address Full"},{"formatted_value":"68522","value":"68522","topic_id":"propertyaddresszip","label":"Property: Address Zip"},{"formatted_value":"LINCOLN","value":"LINCOLN","topic_id":"propertyaddresscity","label":"Property: Address City"},{"formatted_value":"40.798","value":"40.798440","topic_id":"propertylatitude","label":"Property: Latitude"},{"formatted_value":"-96.742","value":"-96.741926","topic_id":"propertylongitude","label":"Property: Longitude"},{"formatted_value":"DRAMANE BOKO","value":"DRAMANE BOKO","topic_id":"partyowner1namefull","label":"Owner 1 Name Full"},{"formatted_value":"","value":"null","topic_id":"partyowner2namefull","label":"Owner 2 Name Full"},{"formatted_value":"1400 W WASHINGTON ST","value":"1400 W WASHINGTON ST","topic_id":"contactownermailaddressfull","label":"Contact: Owner Mailing Address Full"},{"formatted_value":"","value":"null","topic_id":"statusowneroccupiedflag","label":"Flag: Owner Occupied"},{"formatted_value":"FRAME","value":"FRAME","topic_id":"construction","label":"Construction Type"}],"tab_id":"1499862699444","tab_label":"tabX0"},{"data":[{"formatted_value":"OTHER","value":"OTHER","topic_id":"structurestyle","label":"Structure Style Type"},{"formatted_value":"HARTLAND ESTATES","value":"HARTLAND ESTATES","topic_id":"legalsubdivision","label":"Subdivision Name"},{"formatted_value":"Lancaster","value":"Lancaster","topic_id":"situscounty","label":"Property Address County"},{"formatted_value":"","value":"null","topic_id":"parcelnumberformatted","label":"Parcel Number Formatted"},{"formatted_value":"UNKNOWN OR NOT PROVIDED","value":"UNKNOWN OR NOT PROVIDED","topic_id":"foundation","label":"Foundation Type"},{"formatted_value":"Composition Shingle","value":"Composition Shingle","topic_id":"roofmaterial","label":"Roof Material"},{"formatted_value":"0","value":0,"topic_id":"roomscount","label":"Count: Rooms"},{"formatted_value":"4.00","value":"4.000","topic_id":"bathcount","label":"Count: Bathrooms"},{"formatted_value":"3","value":3,"topic_id":"bedroomscount","label":"Count: Bedrooms"},{"formatted_value":"2","value":2,"topic_id":"storiescount","label":"Count: Stories"}],"tab_id":"1499862699445","tab_label":"tabX1"},{"data":[{"formatted_value":"0","value":0,"topic_id":"unitscount","label":"Count: Units"},{"formatted_value":"","value":"null","topic_id":"buildingscount","label":"Count: Buildings"},{"formatted_value":"1,432","value":1432,"topic_id":"areabuilding","label":"Area of Total Living Space (Square Feet)"},{"formatted_value":"2,610","value":2610,"topic_id":"areagross","label":"Gross Area of All Structures (Square Footage)"},{"formatted_value":"10,019.00","value":"10019.0000000","topic_id":"arealotsf","label":"Lot Area (Square Footage)"},{"formatted_value":"1","value":1,"topic_id":"fireplacecount","label":"Count: Fireplace"},{"formatted_value":"Individual","value":"Individual","topic_id":"ownertypedescription1","label":"First Owner Type"},{"formatted_value":"Individual","value":"Individual","topic_id":"ownertypedescription2","label":"Second Owner Type"},{"formatted_value":"UNKNOWN OR NOT PROVIDED","value":"UNKNOWN OR NOT PROVIDED","topic_id":"currentfirstpositionmortgagetype","label":"Current First Position Mortgage Type"},{"formatted_value":"UNKNOWN OR NOT PROVIDED","value":"UNKNOWN OR NOT PROVIDED","topic_id":"currentsecondpositionmortgagetype","label":"Current Second Position Mortgage Type"}],"tab_id":"1499862699446","tab_label":"tabX2"},{"data":[{"formatted_value":"","value":"null","topic_id":"availableequity","label":"Available Equity"},{"formatted_value":"","value":"null","topic_id":"ltv","label":"Loan-to-Value Ratio (LTV)"},{"formatted_value":"","value":"null","topic_id":"currentfirstpositionopenloaninterestrate","label":"Current First Position Open Loan Interest Rate"},{"formatted_value":"","value":"null","topic_id":"currentsecondpositionopenloaninterestrate","label":"Current Second Position Open Loan Interest Rate"},{"formatted_value":"UNKNOWN OR NOT PROVIDED","value":"UNKNOWN OR NOT PROVIDED","topic_id":"ownershipvestingrelationcode","label":"Ownership Vesting Type"},{"formatted_value":"2021-04-22T00:00:00.000Z","value":"2021-04-22T00:00:00.000Z","topic_id":"deedlastsaledate","label":"Deed Last Sale Date"},{"formatted_value":2023,"value":2023,"topic_id":"taxyearassessed","label":"Tax: Year Assessed"},{"formatted_value":"$269,700.00","value":269700,"topic_id":"taxassessedvaluetotal","label":"Tax: Assessed Value Total"},{"formatted_value":"$52,000.00","value":52000,"topic_id":"taxassessedvalueland","label":"Tax: Assessed Value Land"},{"formatted_value":"$217,700.00","value":217700,"topic_id":"taxassessedvalueimprovements","label":"Tax: Assessed Value Improvements"}],"tab_id":"1499862699447","tab_label":"tabX3"},{"data":[{"formatted_value":"$269,700.00","value":269700,"topic_id":"previousassessedvalue","label":"Previous Assessed Value"},{"formatted_value":"$4,520.18","value":"4520.18","topic_id":"taxbilledamount","label":"Tax: Billed Amount"},{"formatted_value":"$52,000.00","value":52000,"topic_id":"taxmarketvalueland","label":"Tax: Market Value Land"},{"formatted_value":"$217,700.00","value":217700,"topic_id":"taxmarketvalueimprovements","label":"Tax: Market Value Improvements"},{"formatted_value":"$269,700.00","value":269700,"topic_id":"taxmarketvaluetotal","label":"Tax: Market Value Total"},{"formatted_value":2023,"value":2023,"topic_id":"taxfiscalyear","label":"Tax: Fiscal Year"},{"formatted_value":1996,"value":1996,"topic_id":"yearbuilt","label":"Year Built (Primary Structure)"},{"formatted_value":"","value":"null","topic_id":"yearbuilteffective","label":"Year Built (Adjusted for Structural Changes)"},{"formatted_value":"LANCASTER","value":"LANCASTER","topic_id":"propertyjurisdictionname","label":"Property: Jurisdiction Name"},{"formatted_value":"$240,000.00","value":240000,"topic_id":"deedlastsaleprice","label":"Deed Last Sale Price"}],"tab_id":"1499862699448","tab_label":"tabX4"},{"data":[{"formatted_value":"SIDING","value":"SIDING","topic_id":"exterior1code","label":"Primary Exterior Wall Covering Material"},{"formatted_value":"LANCASTER","value":"LANCASTER","topic_id":"propertyjurisdictionname","label":"Property: Jurisdiction Name"},{"formatted_value":"SINGLE FAMILY RESIDENCE","value":"SINGLE FAMILY RESIDENCE","topic_id":"propertyusestandardized","label":"Property: Use (Detail)"}],"tab_id":"1499862699449","tab_label":"tabX5"}],"header":[{"formatted_value":"","value":"null","topic_id":"parcelnumberformatted","label":"Parcel Number Formatted"}]},"position":{"lng":"-96.741926","lat":"40.798440"},"color":"46E71B:Circle","rowid":"row-0","datatype":"usa_property_sfdc","c2c":true,"uid":195672075,"geoid":195672075,"label":"1400 W WASHINGTON ST"},{"popup":{"tabs":[{"data":[{"formatted_value":"3430 N 63RD ST","value":"3430 N 63RD ST","topic_id":"propertyaddressfull","label":"Property: Address Full"},{"formatted_value":"68507","value":"68507","topic_id":"propertyaddresszip","label":"Property: Address Zip"},{"formatted_value":"LINCOLN","value":"LINCOLN","topic_id":"propertyaddresscity","label":"Property: Address City"},{"formatted_value":"40.847","value":"40.847188","topic_id":"propertylatitude","label":"Property: Latitude"},{"formatted_value":"-96.634","value":"-96.634106","topic_id":"propertylongitude","label":"Property: Longitude"},{"formatted_value":"BOSTOCK RENTAL 2 LLC","value":"BOSTOCK RENTAL 2 LLC","topic_id":"partyowner1namefull","label":"Owner 1 Name Full"},{"formatted_value":"","value":"null","topic_id":"partyowner2namefull","label":"Owner 2 Name Full"},{"formatted_value":"1607 NW 51ST ST","value":"1607 NW 51ST ST","topic_id":"contactownermailaddressfull","label":"Contact: Owner Mailing Address Full"},{"formatted_value":true,"value":true,"topic_id":"statusowneroccupiedflag","label":"Flag: Owner Occupied"},{"formatted_value":"NONE STATED","value":"NONE STATED","topic_id":"construction","label":"Construction Type"}],"tab_id":"1499862699444","tab_label":"tabX0"},{"data":[{"formatted_value":"RANCH","value":"RANCH","topic_id":"structurestyle","label":"Structure Style Type"},{"formatted_value":"HAVELOCK","value":"HAVELOCK","topic_id":"legalsubdivision","label":"Subdivision Name"},{"formatted_value":"Lancaster","value":"Lancaster","topic_id":"situscounty","label":"Property Address County"},{"formatted_value":"","value":"null","topic_id":"parcelnumberformatted","label":"Parcel Number Formatted"},{"formatted_value":"BLOCK (UNSPECIFIED)","value":"BLOCK (UNSPECIFIED)","topic_id":"foundation","label":"Foundation Type"},{"formatted_value":"Composition Shingle","value":"Composition Shingle","topic_id":"roofmaterial","label":"Roof Material"},{"formatted_value":"0","value":0,"topic_id":"roomscount","label":"Count: Rooms"},{"formatted_value":"2.00","value":"2.000","topic_id":"bathcount","label":"Count: Bathrooms"},{"formatted_value":"2","value":2,"topic_id":"bedroomscount","label":"Count: Bedrooms"},{"formatted_value":"1","value":1,"topic_id":"storiescount","label":"Count: Stories"}],"tab_id":"1499862699445","tab_label":"tabX1"},{"data":[{"formatted_value":"0","value":0,"topic_id":"unitscount","label":"Count: Units"},{"formatted_value":"","value":"null","topic_id":"buildingscount","label":"Count: Buildings"},{"formatted_value":"775","value":775,"topic_id":"areabuilding","label":"Area of Total Living Space (Square Feet)"},{"formatted_value":"1,550","value":1550,"topic_id":"areagross","label":"Gross Area of All Structures (Square Footage)"},{"formatted_value":"6,970.00","value":"6970.0000000","topic_id":"arealotsf","label":"Lot Area (Square Footage)"},{"formatted_value":"0","value":0,"topic_id":"fireplacecount","label":"Count: Fireplace"},{"formatted_value":"Company","value":"Company","topic_id":"ownertypedescription1","label":"First Owner Type"},{"formatted_value":"UNKNOWN OR NOT PROVIDED","value":"UNKNOWN OR NOT PROVIDED","topic_id":"ownertypedescription2","label":"Second Owner Type"},{"formatted_value":"UNKNOWN OR NOT PROVIDED","value":"UNKNOWN OR NOT PROVIDED","topic_id":"currentfirstpositionmortgagetype","label":"Current First Position Mortgage Type"},{"formatted_value":"UNKNOWN OR NOT PROVIDED","value":"UNKNOWN OR NOT PROVIDED","topic_id":"currentsecondpositionmortgagetype","label":"Current Second Position Mortgage Type"}],"tab_id":"1499862699446","tab_label":"tabX2"},{"data":[{"formatted_value":"","value":"null","topic_id":"availableequity","label":"Available Equity"},{"formatted_value":"","value":"null","topic_id":"ltv","label":"Loan-to-Value Ratio (LTV)"},{"formatted_value":"","value":"null","topic_id":"currentfirstpositionopenloaninterestrate","label":"Current First Position Open Loan Interest Rate"},{"formatted_value":"","value":"null","topic_id":"currentsecondpositionopenloaninterestrate","label":"Current Second Position Open Loan Interest Rate"},{"formatted_value":"UNKNOWN OR NOT PROVIDED","value":"UNKNOWN OR NOT PROVIDED","topic_id":"ownershipvestingrelationcode","label":"Ownership Vesting Type"},{"formatted_value":"2018-10-31T00:00:00.000Z","value":"2018-10-31T00:00:00.000Z","topic_id":"deedlastsaledate","label":"Deed Last Sale Date"},{"formatted_value":2023,"value":2023,"topic_id":"taxyearassessed","label":"Tax: Year Assessed"},{"formatted_value":"$175,900.00","value":175900,"topic_id":"taxassessedvaluetotal","label":"Tax: Assessed Value Total"},{"formatted_value":"$35,000.00","value":35000,"topic_id":"taxassessedvalueland","label":"Tax: Assessed Value Land"},{"formatted_value":"$140,900.00","value":140900,"topic_id":"taxassessedvalueimprovements","label":"Tax: Assessed Value Improvements"}],"tab_id":"1499862699447","tab_label":"tabX3"},{"data":[{"formatted_value":"$175,900.00","value":175900,"topic_id":"previousassessedvalue","label":"Previous Assessed Value"},{"formatted_value":"$2,948.08","value":"2948.08","topic_id":"taxbilledamount","label":"Tax: Billed Amount"},{"formatted_value":"$35,000.00","value":35000,"topic_id":"taxmarketvalueland","label":"Tax: Market Value Land"},{"formatted_value":"$140,900.00","value":140900,"topic_id":"taxmarketvalueimprovements","label":"Tax: Market Value Improvements"},{"formatted_value":"$175,900.00","value":175900,"topic_id":"taxmarketvaluetotal","label":"Tax: Market Value Total"},{"formatted_value":2023,"value":2023,"topic_id":"taxfiscalyear","label":"Tax: Fiscal Year"},{"formatted_value":1953,"value":1953,"topic_id":"yearbuilt","label":"Year Built (Primary Structure)"},{"formatted_value":"","value":"null","topic_id":"yearbuilteffective","label":"Year Built (Adjusted for Structural Changes)"},{"formatted_value":"LANCASTER","value":"LANCASTER","topic_id":"propertyjurisdictionname","label":"Property: Jurisdiction Name"},{"formatted_value":"$135,000.00","value":135000,"topic_id":"deedlastsaleprice","label":"Deed Last Sale Price"}],"tab_id":"1499862699448","tab_label":"tabX4"},{"data":[{"formatted_value":"BRICK/STONE (BRICK AND/OR STONE)","value":"BRICK/STONE (BRICK AND/OR STONE)","topic_id":"exterior1code","label":"Primary Exterior Wall Covering Material"},{"formatted_value":"LANCASTER","value":"LANCASTER","topic_id":"propertyjurisdictionname","label":"Property: Jurisdiction Name"},{"formatted_value":"SINGLE FAMILY RESIDENCE","value":"SINGLE FAMILY RESIDENCE","topic_id":"propertyusestandardized","label":"Property: Use (Detail)"}],"tab_id":"1499862699449","tab_label":"tabX5"}],"header":[{"formatted_value":"","value":"null","topic_id":"parcelnumberformatted","label":"Parcel Number Formatted"}]},"position":{"lng":"-96.634106","lat":"40.847188"},"color":"46E71B:Circle","rowid":"row-0","datatype":"usa_property_sfdc","c2c":true,"uid":1925588,"geoid":1925588,"label":"3430 N 63RD ST"}]}}';
        Map<String,Object>mockResponse=(Map<String,Object>)JSON.deserializeUntyped(resString);
        SfMapsRetriever.makeFilterMaps(props);

        Test.startTest();
        List<Property__c>foundProps=sfmr.procHostedDataResponse(mockResponse);
        Test.stopTest();
        System.debug('\rSFMapsApiTest: testProcHostedDataResponse():  pre-foundProps('+props.size()+')—>\r'+props);
        Property__c foundProp1=foundProps[0];
        Property__c foundProp2=foundProps[1];
        System.debug('foundProp1—>'+foundProp1);
        System.debug('foundProp2—>'+foundProp2);
        System.assertEquals('1400 W WASHINGTON ST',foundProp1.propertyaddressfull__c,'propertyaddressfull__c p1');
        System.assertEquals('3430 N 63RD ST',foundProp2.propertyaddressfull__c,'propertyaddressfull__c p2');
        System.assertEquals('DRAMANE BOKO',foundProp1.partyowner1namefull__c,'partyowner1namefull__c p1');
        System.assertEquals('BOSTOCK RENTAL 2 LLC',foundProp2.partyowner1namefull__c,'partyowner1namefull__c p2');
        System.assertEquals(null,foundProp1.partyowner2namefull__c,'partyowner2namefull__c p1');
        System.assertEquals(null,foundProp2.partyowner2namefull__c,'partyowner2namefull__c p2');
        System.assertEquals('1400 W WASHINGTON ST',foundProp1.contactownermailaddressfull__c,'contactownermailaddressfull__c p1');
        System.assertEquals('1607 NW 51ST ST',foundProp2.contactownermailaddressfull__c,'contactownermailaddressfull__c p2');
        System.assertEquals('FRAME',foundProp1.construction__c,'construction__c p1');
        System.assertEquals('NONE STATED',foundProp2.construction__c,'construction__c p2');
        System.assertEquals('OTHER',foundProp1.structurestyle__c,'structurestyle__c p1');
        System.assertEquals('RANCH',foundProp2.structurestyle__c,'structurestyle__c p2');
        System.assertEquals('HARTLAND ESTATES',foundProp1.legalsubdivision__c,'legalsubdivision__c p1');
        System.assertEquals('HAVELOCK',foundProp2.legalsubdivision__c,'legalsubdivision__c p2');
        System.assertEquals('Lancaster',foundProp1.situscounty__c,'situscounty__c p1');
        System.assertEquals('Lancaster',foundProp2.situscounty__c,'situscounty__c p2');
        System.assertEquals(null,foundProp1.parcelnumberformatted__c,'parcelnumberformatted__c p1');
        System.assertEquals(null,foundProp2.parcelnumberformatted__c,'parcelnumberformatted__c p2');
        System.assertEquals('UNKNOWN OR NOT PROVIDED',foundProp1.foundation__c,'foundation__c p1');
        System.assertEquals('BLOCK (UNSPECIFIED)',foundProp2.foundation__c,'foundation__c p2');
        System.assertEquals('Composition Shingle',foundProp1.roofmaterial__c,'roofmaterial__c p1');
        System.assertEquals('Composition Shingle',foundProp2.roofmaterial__c,'roofmaterial__c p2');
        System.assertEquals(0,foundProp1.roomscount__c,'roomscount__c p1');
        System.assertEquals(0,foundProp2.roomscount__c,'roomscount__c p2');
        System.assertEquals(4.000,foundProp1.bathcount__c,'bathcount__c p1');
        System.assertEquals(2.000,foundProp2.bathcount__c,'bathcount__c p2');
        System.assertEquals(3,foundProp1.bedroomscount__c,'bedroomscount__c p1');
        System.assertEquals(2,foundProp2.bedroomscount__c,'bedroomscount__c p2');
        System.assertEquals(2,foundProp1.storiescount__c,'storiescount__c p1');
        System.assertEquals(1,foundProp2.storiescount__c,'storiescount__c p2');
        System.assertEquals(0,foundProp1.unitscount__c,'unitscount__c p1');
        System.assertEquals(0,foundProp2.unitscount__c,'unitscount__c p2');
        System.assertEquals(false,foundProp1.statusowneroccupiedflag__c,'statusowneroccupiedflag__c p1');
        System.assertEquals(true,foundProp2.statusowneroccupiedflag__c,'statusowneroccupiedflag__c p2');
        System.assertEquals(props[1].Id,foundProp1.Id,'');
        System.assertEquals(props[0].Id,foundProp2.Id,'');
    }
    @IsTest
    static void testTopicsChecked(){
        Test.startTest();
        System.debug('pre topics='+inTopics);
        List<String> checkedTopics=SFMapsAPI.topicsChecked(inTopics);
        System.debug('checkedTopics='+checkedTopics);
        Test.stopTest();
        System.assertEquals(false,inTopics.contains('propertyaddressfull'));
        System.assertEquals(true,checkedTopics.contains('propertyaddressfull'));
        System.assertEquals(true,checkedTopics.contains('partyowner1namefull'));
        System.assertEquals(true,checkedTopics.contains('contactownermailaddressfull'));
        System.assertEquals(true,inTopics.contains('batcount'));
        System.assertEquals(false,checkedTopics.contains('batcount'));
        System.assertEquals(false,checkedTopics.contains('bathcount'));
    }
    @IsTest
    static void testRemovePostCallProblems(){
        Account a=new Account(Name='grey man',Name_of_Lead_Source__c='PirateshipTesting');
        insert a;
        Account qA=[SELECT Id FROM Account WHERE Name_of_Lead_Source__c='PirateshipTesting' LIMIT 1];
        Property__c qP=[SELECT Id FROM Property__c WHERE Address__Street__s='xxx' LIMIT 1];
        Account_Property_Relationship__c apr=new Account_Property_Relationship__c(Account__c=qA.Id,Property__c=qP.Id);
        insert apr;
        Property__c p2=new Property__c(Name='1610 Lake Street Beatrice, NE',Address__Street__s='1610 Lake Street',Address__City__s='Beatrice',Address__StateCode__s='NE',Address__PostalCode__s='68310',Address__CountryCode__s='US',Address__Latitude__s=40.2489945,Address__Longitude__s= -96.7523966);
        insert p2;
        Property__c qP2=[SELECT Id FROM Property__c WHERE Name='1610 Lake Street Beatrice, NE' LIMIT 1];
        Lead l=new Lead(FirstName='BarfBag',LastName='Fajjit',Mailing_Only_Address__c='#4',Street='1610 Lake Street',City='Beatrice',State='NE',Country='US',PostalCode='68310',Status='Open',Name_of_Lead_Source__c='PirateshipTesting',Property__c=qP2.Id,Company='BarfBag Fajjit');
        insert l;
        Lead qL=[SELECT Id FROM Lead WHERE Name_of_Lead_Source__c='PirateshipTesting' LIMIT 1];
//        insert new Lead(FirstName='gaww',LastName='wawow',Street)
        List<Property__c> props=[SELECT Id,Name,Address__c,Address__Street__s,Address__City__s,Address__StateCode__s,
                Address__CountryCode__s,Address__PostalCode__s,Address__Latitude__s,Address__Longitude__s,
                contactownermailaddressfull__c,propertyaddressfull__c,partyowner1namefull__c,partyowner2namefull__c,Mailing_Only_Address__c,
                (SELECT Id,LastName,Mailing_Only_Address__c FROM Leads__r),
                (SELECT Id,Account__r.Name FROM Account_Property_Relationships__r)
        FROM Property__c WHERE Address__Street__s!=NULL AND Address__City__s != NULL ORDER BY LastModifiedDate ASC LIMIT 4];
        List<Property__c> testProps=new List<Property__c>();
        List<Property__c> expectedProps=new List<Property__c>();
        List<Property__c> cutProps=new List<Property__c>();
        for(Property__c p : props){
            if(p.Address__Street__s.startsWith('1400')){
                p.propertyaddressfull__c='1400 W WASHINGTON ST';
                p.partyowner1namefull__c='DRAMANE BOKO';
                p.contactownermailaddressfull__c='1400 W WASHINGTON ST';
                expectedProps.add(p);
            }else if(p.Address__Street__s.startsWith('3430')){
                p.propertyaddressfull__c='3430 N 63RD ST';
                p.partyowner1namefull__c='BOSTOCK RENTAL 2 LLC';
                p.contactownermailaddressfull__c='1607 NW 51ST ST';
                expectedProps.add(p);
            } else if(p.Address__Street__s=='1610 Lake Street'){
                p.propertyaddressfull__c=null;
                p.Mailing_Only_Address__c='APT 9';
                p.partyowner1namefull__c='RuthBall Fajjit';
                p.partyowner2namefull__c='HunnyBung Fajjit';
                p.contactownermailaddressfull__c='1610 LAKE ST APT 2';
                expectedProps.add(p);
            } else if(p.Address__Street__s=='xxx'){
                p.propertyaddressfull__c='1000 FAKE ST';
                p.Mailing_Only_Address__c='APT 99';
                p.partyowner1namefull__c='GREY MAN';
                p.contactownermailaddressfull__c='1000 FAKE ST APT 28';
                cutProps.add(p);
            }
            testProps.add(p);
        }
        SFMapsAPI sfmapi=new SFMapsAPI('property','propertyaddressfull','propertyaddresscity',false,null);
        Test.startTest();
        System.debug('testProps pre-Size—>'+testProps.size()+'\r'+testProps);
        List<Property__c> actualProps=sfmapi.removePostCallProblems(testProps);
        System.debug('testProps postSize—>'+testProps.size()+'\r'+testProps);
        Test.stopTest();
        List<Property__c>expectedTrimmed=expectedProps;
        expectedTrimmed.add(actualProps.get(2));
        expectedTrimmed.sort();
        actualProps.sort();

        System.assertEquals(expectedTrimmed,actualProps,'WE SHOULDVE REMOVED 1!!!!!');
        System.assertEquals(4,actualProps.size());
    }
    @IsTest
    public static void testPropertyPirateShip() {
        List<String> topics=new List<String>{'propertyaddressfull','propertyaddresszip','propertyaddresscity','propertylatitude','propertylongitude'};
        MockHttpResponse geoIdmockres=new MockHttpResponse(mockResMap);
        Test.setMock(HttpCalloutMock.class,geoIdmockres);
        String filterField='Name';
        String filterOpr='=';
        String filterVal='';
        String filterString=filterField+' '+filterOpr+' '+'\''+filterVal;
        Integer limitVal=2;
        String filterQString;
        if(filterField!=null&&filterVal!=null&&filterOpr!=null){
            filterQString='\t\t'+filterString+'\''+' AND\n';
        } else {
            filterQString='';
        }
        String expectedQueryString='SELECTId,Name,Address__c,Address__Street__s,Address__City__s,Address__StateCode__s,Address__CountryCode__s,Address__PostalCode__s,Address__Latitude__s,Address__Longitude__s,propertyaddressfull__c,Mailing_Only_Address__c,(SELECTId,FirstName,LastName,SecondaryContactFirstName__c,Secondary_Contact_Last_Name__c,Mailing_Only_Address__cFROMLeads__r),(SELECTId,Account__r.NameFROMAccount_Property_Relationships__r)FROMProperty__cWHEREName=\'\'ANDAddress__Street__s!=NULLANDAddress__City__s!=NULLANDAddress__StateCode__s!=NULLANDAddress__PostalCode__s!=NULLANDAddress__Latitude__s!=NULLANDAddress__Longitude__s!=NULLORDERBYAddress__StateCode__sDESC,Address__City__sDESC,Address__Latitude__sDESC,Address__Longitude__sDESCLIMIT2';
        expectedQueryString.remove(' ').remove('\n').remove('\r').remove('\t');
        SFMapsAPI sfmapi=new SFMapsAPI('property','propertyaddressfull','propertyaddresscity',false,null);
        SfMapsRetriever.makeFilterMaps(aProp);
        SFMapsAPI.geographicIds=new List<Integer>{195672075,1925588};
        sfmapi.sfmr.response=mockResMap;
        System.debug(sfmapi.sfmr.response);
        List<PropertyPirateShip.pirateShipFilter> pirateFilters=new List<PropertyPirateShip.pirateShipFilter>{
                new PropertyPirateShip.pirateShipFilter('Name','=','')
        };
        PropertyPirateShip batch=new PropertyPirateShip(new Set<String>(topics),pirateFilters,2,'property','propertyaddressfull','propertyaddresscity',false,null,true,null);
        System.debug(batch.inTopics);
        System.debug(batch.queryString);
        Test.startTest();
        Database.executeBatch(batch,2);
        System.debug(batch.source);
        System.debug(PropertyPirateShip.inPropsSize);
        Test.stopTest();
        String actualQueryString=batch.queryString.remove(' ').remove('\n').remove('\r').remove('\t');
        System.assertEquals(expectedQueryString,actualQueryString);
        System.assertEquals('property',batch.source);
    }
    @IsTest
    public static void testPropertyPirateShipOpportunity() {
        Account a=new Account(Name='a1',Name_of_Lead_Source__c='PirateshipTesting');
        insert a;
        Account qA=[SELECT Id FROM Account WHERE Name_of_Lead_Source__c='PirateshipTesting' LIMIT 1];
        Opportunity o=new Opportunity(Name='a1 big oppty',StageName='Closed',AccountId=qA.Id,Opportunity_Property__c=aProp[0].Id,CloseDate=System.today());
        insert o;
        Opportunity qO=[SELECT Name,Id,StageName,AccountId,Opportunity_Property__c,CloseDate FROM Opportunity WHERE AccountId=:qA.Id LIMIT 1];
        String expectedQueryString='SELECTId,Name,Address__c,Address__Street__s,Address__City__s,Address__StateCode__s,Address__CountryCode__s,Address__PostalCode__s,Address__Latitude__s,Address__Longitude__s,propertyaddressfull__c,Mailing_Only_Address__c,(SELECTId,LastName,Mailing_Only_Address__cFROMLeads__r),(SELECTId,Account__r.NameFROMAccount_Property_Relationships__r)FROMProperty__cWHERE(Id=\'a1qU8000003DZRFIA4\')';
        expectedQueryString=expectedQueryString.remove(' ').remove('\n').remove('\t').remove('\r');
        PropertyPirateShip batch=new PropertyPirateShip(qO,'property','propertyaddressfull','propertyaddresscity',false,null,true,null);
        Test.startTest();
        String actualQueryString=batch.queryString.remove(' ').remove('\n').remove('\t').remove('\r');
        Test.stopTest();
        System.assertEquals(SFMapsAPI.allTopics,batch.inTopics);
        System.debug(batch.source);
        System.debug(PropertyPirateShip.inPropsSize);
        System.debug('\rACTUAL QueryString: '+batch.queryString+'\rEXPECTED QueryString: '+expectedQueryString);
        System.assertEquals(expectedQueryString.substringBefore('a1q'),actualQueryString.substringBefore('a1q'));
        System.assertEquals('property',batch.source);
    }
}