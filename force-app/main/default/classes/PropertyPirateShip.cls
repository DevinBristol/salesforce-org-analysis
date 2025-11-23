/**
 * Created by Ben on 1/24/2025.
 */

global class PropertyPirateShip implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    public static final Map<String,String>stateCodes=new Map<String,String>{
            'ALABAMA'=>'AL','ALASKA'=>'AK','ARIZONA'=>'AZ','ARKANSAS'=>'AR','CALIFORNIA'=>'CA','COLORADO'=>'CO','CONNECTICUT'=>'CT','DELAWARE'=>'DE','FLORIDA'=>'FL','GEORGIA'=>'GA','HAWAII'=>'HI','IDAHO'=>'ID','ILLINOIS'=>'IL','INDIANA'=>'IN','IOWA'=>'IA','KANSAS'=>'KS','KENTUCKY'=>'KY','LOUISIANA'=>'LA','MAINE'=>'ME','MARYLAND'=>'MD','MASSACHUSETTS'=>'MA','MICHIGAN'=>'MI','MINNESOTA'=>'MN','MISSISSIPPI'=>'MS','MISSOURI'=>'MO','MONTANA'=>'MT','NEBRASKA'=>'NE','NEVADA'=>'NV','NEW HAMPSHIRE'=>'NH','NEW JERSEY'=>'NJ','NEW MEXICO'=>'NM','NEW YORK'=>'NY','NORTH CAROLINA'=>'NC','NORTH DAKOTA'=>'ND','OHIO'=>'OH','OKLAHOMA'=>'OK','OREGON'=>'OR','PENNSYLVANIA'=>'PA','RHODE ISLAND'=>'RI','SOUTH CAROLINA'=>'SC','SOUTH DAKOTA'=>'SD','TENNESSEE'=>'TN','TEXAS'=>'TX','UTAH'=>'UT','VERMONT'=>'VT','VIRGINIA'=>'VA','WASHINGTON'=>'WA','WEST VIRGINIA'=>'WV','WISCONSIN'=>'WI','WYOMING'=>'WY'
    };
    public static final Map<String,String>stateFulls=new Map<String,String>{
            'AL'=>'ALABAMA','AK'=>'ALASKA','AZ'=>'ARIZONA','AR'=>'ARKANSAS','CA'=>'CALIFORNIA','CO'=>'COLORADO','CT'=>'CONNECTICUT','DE'=>'DELAWARE','FL'=>'FLORIDA','GA'=>'GEORGIA','HI'=>'HAWAII','ID'=>'IDAHO','IL'=>'ILLINOIS','IN'=>'INDIANA','IA'=>'IOWA','KS'=>'KANSAS','KY'=>'KENTUCKY','LA'=>'LOUISIANA','ME'=>'MAINE','MD'=>'MARYLAND','MA'=>'MASSACHUSETTS','MI'=>'MICHIGAN','MN'=>'MINNESOTA','MS'=>'MISSISSIPPI','MO'=>'MISSOURI','MT'=>'MONTANA','NE'=>'NEBRASKA','NV'=>'NEVADA','NH'=>'NEW HAMPSHIRE','NJ'=>'NEW JERSEY','NM'=>'NEW MEXICO','NY'=>'NEW YORK','NC'=>'NORTH CAROLINA','ND'=>'NORTH DAKOTA','OH'=>'OHIO','OK'=>'OKLAHOMA','OR'=>'OREGON','PA'=>'PENNSYLVANIA','RI'=>'RHODE ISLAND','SC'=>'SOUTH CAROLINA','SD'=>'SOUTH DAKOTA','TN'=>'TENNESSEE','TX'=>'TEXAS','UT'=>'UTAH','VT'=>'VERMONT','VA'=>'VIRGINIA','WA'=>'WASHINGTON','WV'=>'WEST VIRGINIA','WI'=>'WISCONSIN','WY'=>'WYOMING'
    };
    public static Integer inPropsSize;
    public static Integer totalUpdates;
    public List<String> inTopics;
    public String queryString;
    public String source;
    public String streetTopic;
    public String cityTopic;
    public Boolean routeFiltering;
    public String badChars;
    public Boolean updateCleanedFields;
    public Map<String,String>ScavengingPlan;
    public Boolean ScavangingEnabled=false;
    public void initializer(Set<String>topics,String source,String streetTopic,String cityTopic,Boolean routeFiltering,String badChars,Boolean updateCleanedFields,Map<String,String>ScavengingPlan){
        if(topics==null||topics.size()==0){
            this.inTopics=SFMapsAPI.allTopics;
        } else {
            this.inTopics=new List<String>(topics);
        }
        this.streetTopic=(streetTopic ?? 'propertyaddressfull');
        this.cityTopic=(cityTopic??this.streetTopic.removeEnd('full')+'city');
        this.source=(source??'property');
        this.routeFiltering=routeFiltering;
        this.badChars=(badChars??'().,"—–');
        this.updateCleanedFields=(updateCleanedFields??false);
        if(ScavengingPlan!=null&&!ScavengingPlan.isEmpty()){
            this.ScavangingEnabled=true;
            this.ScavengingPlan=ScavengingPlan;
        }
    }
    public PropertyPirateShip(Opportunity op,String source,String streetTopic,String cityTopic,Boolean routeFiltering,String badChars,Boolean updateCleanedFields,Map<String,String>scavengePlan){
        initializer(null,source,streetTopic,cityTopic,routeFiltering,badChars,updateCleanedFields,null);
        String ortString=' Id=\''+op.Opportunity_Property__c+'\'';
        System.debug(' @ Last ortString = '+ortString);
        this.queryString = 'SELECT Id,Name, Address__c,Address__Street__s,Address__City__s,Address__StateCode__s,Address__CountryCode__s,Address__PostalCode__s,Address__Latitude__s,Address__Longitude__s,propertyaddressfull__c,Mailing_Only_Address__c,(SELECT Id,LastName,Mailing_Only_Address__c FROM Leads__r),(SELECT Id,Account__r.Name FROM Account_Property_Relationships__r) FROM Property__c\nWHERE ('+ortString+')';
        System.debug('queryString = '+this.queryString);
    }
    public PropertyPirateShip(Set<String>topics,List<pirateShipFilter>pirateShipFilters,Integer LimitValue,String source,String streetTopic,String cityTopic,Boolean routeFiltering,String badChars,Boolean updateCleanedFields,Map<String,String>scavengePlan){
        inPropsSize=0;
        totalUpdates=0;
        initializer(topics,source,streetTopic,cityTopic,routeFiltering,badChars,updateCleanedFields,scavengePlan);
        String filterQString='';
        if(pirateShipFilters.size()>0){
            for(pirateShipFilter pirateShipFilter : pirateShipFilters){
                filterQString=filterQString+pirateShipFilter.queryFilterPart;
                System.debug(filterQString);
            }
        }
        String limitString='';
        if(LimitValue!=null){
            limitString='\t\tLIMIT '+LimitValue;
        }
        this.queryString='SELECT Id,Name,Address__c,Address__Street__s,Address__City__s,Address__StateCode__s,Address__CountryCode__s,Address__PostalCode__s,Address__Latitude__s,Address__Longitude__s,propertyaddressfull__c,Mailing_Only_Address__c,\n\t'+
                '(SELECT Id,FirstName,LastName,SecondaryContactFirstName__c,Secondary_Contact_Last_Name__c,Mailing_Only_Address__c FROM Leads__r),\n\t\t' +
                '(SELECT Id,Account__r.Name FROM Account_Property_Relationships__r) FROM Property__c WHERE\n\t\t'+
                filterQString+'\n\t\tAddress__Street__s!=NULL AND\n\t\tAddress__City__s!=NULL AND\n\t\tAddress__StateCode__s!=NULL AND\n\t\tAddress__PostalCode__s!=NULL AND\n\t\tAddress__Latitude__s!=NULL AND\n\t\tAddress__Longitude__s!=NULL\n\t'+
                'ORDER BY Address__StateCode__s DESC,Address__City__s DESC,Address__Latitude__s DESC,Address__Longitude__s DESC\n\t'+
                limitString;
        System.debug('queryString = '+queryString); //wy,sd,ne,mo,ks,ia,co ,ne->york-alma ne->york->n to s then e to w
    }
    global Database.QueryLocator start(Database.BatchableContext bc) {
//        System.debug('—–—Property–Pirateship–START-Method—–—>\nthis.streetTopic='+this.streetTopic+'...\nthis.cityTopic='+this.cityTopic+'...\nthis.source='+this.source+'...\nthis.routeFiltering='+this.routeFiltering);
        return Database.getQueryLocator(queryString);
    }
    public SFMapsAPI setupAPI(List<Property__c>scope){
        SFMapsAPI sfmApi = new SFMapsAPI(this.source,this.streetTopic,this.cityTopic,this.routeFiltering,this.badChars);//makes sfmr1 //makes filtermaps//        System.debug('SERIALIZED sfmAPI#1(scope,source)—>'+JSON.serializePretty(sfmApi));//        System.debug('SERIALIZED sfmr#1(scope,source)—>'+JSON.serializePretty(sfmApi.sfmr));
        sfmApi=new SFMapsAPI(scope);
        return sfmApi;
    }
    global void execute(Database.BatchableContext bc, List<Property__c> scope) {
        // HERE I'M GONNA EMULATE THE ANONYMOUS APEX USED TO CALL SFMapsAPI.
        SFMapsAPI sfmApi=setupAPI(scope);
        if(SFMapsAPI.geographicIds.size()>0){
            sfmApi = new SFMapsAPI(scope,this.inTopics);
        }
        System.debug('scope size='+scope.size()+', props(out) size='+sfmApi.props.size());
        if(sfmApi.props.size()>0){
            System.debug(sfmApi.props);
            update sfmApi.props;
        }
        if(this.updateCleanedFields){
            update prepCleaners(scope);
        }
//        if(this.ScavangingEnabled){ //this has the advantage of referencing the previous search.
//    //make another sfmapsapi with specific filters for your scavenging
//            Map<String,Object>targetedFilter=SFMapsAPI.Scavenger(sfmApi.unmatchedProps);
//            SFMapsAPI scavengeRun=new SFMapsAPI(this.ScavengingPlan.get('streetTopic'),this.ScavengingPlan.get('cityTopic'),this.ScavengingPlan.get('source'),Boolean.valueOf(this.ScavengingPlan.get('routeSplit')),this.ScavengingPlan.get('badCharacters'));
//            scavengeRun.sfmr=sfmApi.sfmr;//
//            scavengeRun.sfmr.reqString='inject the new one here';
//        }
    }
    global void finish(Database.BatchableContext bc) {
    }

    public static List<Property__c>prepCleaners(List<Property__c>scope){
        Set<Property__c>cleaners=new Set<Property__c>();
        for(Property__c p : scope){
            cleaners.add(new Property__c(Id=p.Id,Pirateship_Checked__c=true));
        }
        return new List<Property__c>(cleaners);
    }

    public class pirateShipFilter{
        public String filterField;
        public String filterOperator;
        public String filterValue;
        public String queryFilterPart;
        public pirateShipFilter(String filterField,String filterOperator,String filterValue){
            this.filterField=filterField;
            this.filterOperator=filterOperator;
            this.filterValue=filterValue;
            if(filterField!=null&&this.filterValue!=null&&this.filterOperator!=null){
                String qt='';
                if(this.filterValue!='TRUE'&&this.filterValue!='FALSE'&&this.filterValue!='NULL' && !(new Set<String>{'>','>=','<=','<'}.contains(this.filterOperator)) &&
                        !(((this.filterField.toUpperCase().contains('DATE') | (this.filterField.toUpperCase().contains('TIME')))) && ( new Set<String>{'TODAY','YESTERDAY','TOMORROW','NEXT_WEEK','LAST_MONTH','THIS_MONTH','NEXT_MONTH','LAST_90_DAYS','NEXT_90_DAYS','NEXT_N_DAYS ','LAST_YEAR','NEXT_YEAR'}.contains(this.filterValue.substringBefore(':')) || (Date.valueOf(this.filterValue)!=null) || (Datetime.valueOf(this.filterValue)!=null))) &&
                        ( this.filterValue.isAlpha() ||  this.filterValue.isWhitespace() || this.filterValue.contains('%'))){
                    qt='\'';
                    System.debug(this.queryFilterPart);
                }
                this.queryFilterPart='\t'+this.filterField+' '+this.filterOperator+' '+(qt+this.filterValue+qt)+' AND\n';
            }
        }
    }
    //this is for checking against the scope (maybe even some fuggen bonus queries) if methodical cleaning fails
//    public class guessCard{
//        // we need to be able to grab the street variant within the scope that tells us in order:
//        //for streets without necessary detail:(123 HWY 6,123 RD 4,123 South)
//        // 1.the correct address suffix format, 2.dirs range&format, routename format/errors((6 Rd vs 6th Rd) type shit),4.numb range?,5.(Bonus for later:subunit presence,type,format/range/placement)
//        //1. make object path/id with ((unique))keychain from field combo
//        //2. make a map or method to get fellow guessCards at keychain for path/id ,(bottom level(numbs||numbs&&mailingOnly) should just be 1 though)
//        //      Hierarchymap going (authKey)=>routeMap.get(suffxs)=>routeMap.get(route)=>(state+','+city)=>
//        public guessCard(String street,String city,String state){//get auth fields// get keychain//  get correct format (if null do all possible formats)
//            if(stateCodes.containsKey(state.toUpperCase())){
//                this.state=state;
//            } else if(stateFulls.containsKey(state.toUpperCase())){
//                this.state=stateCodes.get(state.toUpperCase());
//            }
//            this.routeMap=SfMapsRetriever.getRouteMap(street,city);
//            makeKeychain();
//        }
//        public String street;
//        public String city;
//        public String state;
////        public String authLevel; //STATE,FEDERAL,COUNTY,OTHER
////        public String authVal; // the substring value which tripped a conditional (State , NE-, US-, U.s.,null for generix)
//        public String authKey; //the universal version of whatever the substring is. probably just statecode
//        public Map<String,String>routeMap;
//        public String keychain;
//        public void makeKeychain(){
//            System.debug('routemap='+routeMap);
//            System.debug('authKey='+authKey);
//            this.keychain='{"'+authKey+'":{"'+this.state+','+this.city.toUpperCase()+'":{"'+this.routeMap.get('route')+'":{"'+routeMap.get('dir')+'":{"'+this.routeMap.get('suffxs')+'"}}}}}';
//            Map<String,Object>testKeyChain=(Map<String,Object>)JSON.deserializeUntyped(this.keychain);
//            System.debug('testKeyChain deserialized='+testKeyChain);
//        }
//    }
//    public static Map<String,Map<String,Map<String,Object>>>guessCardScoreboard=new Map<String,Map<String,Map<String,Object>>>{
//            'auth'=>new Map<String,Map<String,Object>>{ //example values in inner map
//                    'STATE'=>new Map<String,Object>{'authVal'=>'Nebraska','format'=>''},
//                    'FEDERAL'=>new Map<String,Object>{},
//                    'COUNTY'=>new Map<String,Object>{},
//                    'OTHER'=>new Map<String,Object>{},
//                    'OTHER'=>new Map<String,Object>{// like Cornhusker Highway(altname),Kings Hwy(normal city streets w/ hwy suffix),Old X Hwy or other gay shit
//                    },
//                    'score'=>new Map<String,Integer>{}
//            },
//            'sufx'=>new Map<String,Map<String,Object>>{
//                    'HWY'=>new Map<String,Map<String,Object>>{
//                    }
//            }
//    };
}