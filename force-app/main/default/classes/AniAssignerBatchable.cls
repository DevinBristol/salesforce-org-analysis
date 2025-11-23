/**
 * Created by benra on 4/21/2025.
 */

global class AniAssignerBatchable implements Database.Batchable<SObject>, Database.Stateful {
    public Integer minimumANIs{get;set;}
    public County__c defaultCounty;
    public static Set<String>batchBadCities=new Set<String>();
    public Set<String>badCities=new Set<String>();
    public String queryString='SELECT Id,Address,b7ef8429_9f35_4102_b1ea_44d3453a5086__c,ba685ce4_2c28_433a_a4c6_cac18b40f436__c FROM Lead WHERE Id IN :ldIds';
    public Map<String,Object>bindMap=new Map<String,Object>{'ldIds'=>new Set<Id>()};
    public List<Campaign>campaigns=new List<Campaign>(); //just the id,name,f9listsource not all the members and shtuf
    public static Map<Id,Set<Id>>countyLeadsMap=new Map<Id,Set<Id>>();
    public static Map<Id,Set<ANI__c>>aniMap=new Map<Id,Set<ANI__c>>();
    public AniAssignerBatchable(Set<Id> campaignIds){
        this.defaultCounty=[SELECT Id,Name,(SELECT Id,Name,b7__c FROM ANI__r WHERE isActive__c=TRUE) FROM County__c WHERE Name = 'Douglas, NE' LIMIT 1];
        this.bindMap=makeBindMap(campaignIds);
    }
    public AniAssignerBatchable(Set<Id> campaignIds,String defaultCountyName){
        this.minimumANIs=5;
        defaultCountyName='%'+defaultCountyName+'%';
        this.defaultCounty=[SELECT Id,Name,(SELECT Id,Name,b7__c FROM ANI__r WHERE isActive__c=TRUE) FROM County__c WHERE Name LIKE :defaultCountyName LIMIT 1];
        this.bindMap=makeBindMap(campaignIds);
    }
    public AniAssignerBatchable(Set<Id> campaignIds,Integer minimumANIs){
        this.minimumANIs=minimumANIs;
        this.defaultCounty=[SELECT Id,Name,(SELECT Id,Name,b7__c FROM ANI__r WHERE isActive__c=TRUE) FROM County__c WHERE Name ='Douglas, NE' LIMIT 1];
        this.bindMap=makeBindMap(campaignIds);
    }
    public AniAssignerBatchable(Set<Id> campaignIds,Integer minimumANIs,String defaultCountyName){
        defaultCountyName='%'+defaultCountyName+'%';
        this.minimumANIs=minimumANIs;
        this.defaultCounty=[SELECT Id,Name,(SELECT Id,Name,b7__c FROM ANI__r WHERE isActive__c=TRUE) FROM County__c WHERE Name LIKE :defaultCountyName LIMIT 1];
        this.bindMap=makeBindMap(campaignIds);
    }
    public Map<String,Object> makeBindMap(Set<Id> campaignIds){ //also pre updates campaigns clearing the f9list field
        List<Campaign>camps=[SELECT Id,Name,NumberOfLeads,Five9ListSource__c,(SELECT Id,LeadId FROM CampaignMembers WHERE Type='Lead' AND (Lead.MobilePhone!=NULL OR Lead.Phone!=NULL)) FROM Campaign WHERE Id IN :campaignIds];
        Set<Id>ldIds=new Set<Id>();
        for(Campaign camp : camps){
            this.campaigns.add(new Campaign(Id=camp.Id,Five9ListSource__c=camp.Five9ListSource__c,Five9__Five9list__c=''));
            System.debug('\n\tMakeBindMap: Running camp: '+camp.Name+', LeadMembers#:'+camp.NumberOfLeads);
            for(CampaignMember cMbr : camp.CampaignMembers){
                ldIds.add(cMbr.LeadId);
            }
        } System.debug('bindMap='+this.bindMap);
        System.debug('Constructor: this.campaigns—>\r'+JSON.serializePretty(this.campaigns));
        update this.campaigns;
        return new Map<String,Object>{'ldIds'=>ldIds};
    }
    global Database.QueryLocator start(Database.BatchableContext bc) {
        update this.campaigns; //clearing f9list
        return Database.getQueryLocatorWithBinds(this.queryString,this.bindMap,AccessLevel.USER_MODE);
    }
    global void execute(Database.BatchableContext bc,List<Lead>scope) {
        List<Lead>updateLeads=processLeads(scope,this.minimumANIs,this.defaultCounty);
        System.debug('SCOPE SIZE = '+scope.size()+' / UPDATER SIZE='+updateLeads.size());
        System.debug('\r\r\r\t\t<<<!BAD CITIES!>>>\r\t\t\t\t'+JSON.serializePretty(batchBadCities));
        this.badCities.addAll(batchBadCities);
        update updateLeads;
    }
    global void finish(Database.BatchableContext bc) {
        for(Campaign camp : this.campaigns){
            camp.Five9__Five9list__c=camp.Five9ListSource__c;
        }
        System.debug('\r\r\t\t——(FINISH)—ALL–BAD–CITIES——>\r'+'\t\t...size='+badCities.size()+'\r'+JSON.serializePretty(this.badCities));
        for(Campaign camp : this.campaigns){
            reapplyFive9List(camp.Id,camp.Five9ListSource__c); // this isnt retarded
        }
    }
    public static List<Lead>processLeads(List<Lead>leads,Integer minANIs,County__c defaultCounty){
        List<County__c>counties=getCounties(makeCityNameList(leads),minANIs,defaultCounty);
        List<Lead>updateLeads=new List<Lead>();
        for(County__c county : counties){ //there shouldnt be any 0-sized county.ani__r lists by now.
            if(aniMap.get(county.Id).size()>0){
                List<ANI__c>anis=new List<ANI__c>(aniMap.get(county.Id));
                Integer idX=anis.size();
                Integer aniX;
                for(Id ldId : countyLeadsMap.get(county.Id)){
                    aniX=Math.mod(idX,anis.size());
                    System.debug('idX='+idX+', aniX='+aniX+' ('+anis[aniX]+'), anis.size()='+anis.size());
                    updateLeads.add(new Lead(Id=ldId,ba685ce4_2c28_433a_a4c6_cac18b40f436__c=anis[aniX].Name,b7ef8429_9f35_4102_b1ea_44d3453a5086__c=anis[aniX].b7__c));
                    idX++;
                }
            } else {
                System.debug('\n\n\t\t<—(–(-(?_WHAT THE FUCK HAPPENED HERE_?)-)–)—>\n\tNO ANIS FOUND FOR COUNTY: '+county.Name+'\n'+county);
            }
        }
        System.debug('\n\n\t——UPDATE-LEADS(size='+updateLeads.size()+')–—>\n'+updateLeads);
        return updateLeads;
    }
    public static Map<String,Set<Id>>makeCityNameList(List<Lead>leads){
        Map<String,Set<Id>>cityNameMap=new Map<String,Set<Id>>();
        for(Lead l : leads){
            String city=l.Address.getCity();
            if(city.contains(' ')){
                List<String>ssList=city.split(' ');
                List<String>newSubs=new List<String>();
                for(String ss : ssList){
                    ss=ss.toLowerCase();
                    ss=ss.capitalize();
                    newSubs.add(ss);
                }
                city=String.join(newSubs,' ');
            }
            if(stateCodes.containsKey(l.Address.getState())){
                city=city+', '+l.Address.getState();
            } else if(stateFulls.containsKey(l.Address.getState())){
                city=city+', '+stateFulls.get(l.Address.getState());
            }
            Set<Id>cityLeadIds=new Set<Id>{l.Id};
            if(cityNameMap.containsKey(city)){
                cityLeadIds.addAll(cityNameMap.get(city));
            }
            cityNameMap.put(city,cityLeadIds);
        }
        System.debug('\n\n\t––//–makeCityNameList–//–CITY-NAME-MAP(size:[keys='+cityNameMap.keySet().size()+', vals='+cityNameMap.values().size()+'])––>\n'+JSON.serializePretty(cityNameMap));
        return cityNameMap;
    }
    public static List<County__c>getCounties(Map<String,Set<Id>>cityNameMap,Integer minANIs,County__c defaultCounty){
        List<City__c>cities=[SELECT Id,Name,County__c,County__r.Id,County__r.Name FROM City__c WHERE Name IN :cityNameMap.keySet()];
        for(City__c city : cities) {
            if (cityNameMap.containsKey(city.Name)){
                Set<Id> leadIds = new Set<Id>(cityNameMap.get(city.Name));
                if (countyLeadsMap.containsKey(city.County__c)) {
                    leadIds.addAll(countyLeadsMap.get(city.County__c));
                }
                countyLeadsMap.put(city.County__c, leadIds);
            } else {
                batchBadCities.add(city.Name);
            }
        } System.debug('\n\n\t——COUNTY-LEADS-MAP(size:[keys='+countyLeadsMap.keySet().size()+', vals='+countyLeadsMap.values().size()+'])–—>\n'+JSON.serializePretty(countyLeadsMap));
        List<County__c>counties=[SELECT Id,Name,Backup_County_ANIs__c,Backup_County_ANIs__r.Name,(SELECT Id,Name,County__r.Name,b7__c FROM ANI__r) FROM County__c WHERE Id IN :countyLeadsMap.keySet()];
        Map<Id,Id>backupMap=new Map<Id,Id>();
        aniMap=new Map<Id,Set<ANI__c>>();
        for(County__c county : counties){
            Set<ANI__c>anis=new Set<ANI__c>(county.ANI__r);
            if(anis.size()<minANIs){
                if(!backupMap.containsKey(county.Id)){
                    backupMap.put(county.Backup_County_ANIs__c,county.Id);
                }
            }
            aniMap.put(county.Id,anis);
        } System.debug('round1 aniMap—>\n'+JSON.serializePretty(aniMap));
        if(backupMap.keySet().size()>0){
            List<County__c>backups=[SELECT Id,Name,(SELECT Id,Name,County__r.Name,b7__c FROM ANI__r) FROM County__c WHERE Id IN :backupMap.keySet()];
            for(County__c bCounty : backups){System.debug('@backup:START='+bCounty.Name);
                Set<ANI__c>anis=new Set<ANI__c>(bCounty.ANI__r);
                System.debug('@backup:after'+bCounty.Name+' ... new anis size='+anis.size());
                if(aniMap.containsKey(backupMap.get(bCounty.Id))){
                    anis.addAll(aniMap.get(backupMap.get(bCounty.Id)));
                }
                if(anis.size()<minANIs){
                    anis.addAll(defaultCounty.ANI__r);
                    System.debug('@backup:DEFAULTS='+bCounty.Name+' ... new anis size='+anis.size());
                }
                aniMap.put(backupMap.get(bCounty.Id),anis);
            }
        }
        return counties;
    }
    public static void reapplyFive9List(Id campId,String f9List){
        Campaign finishedCamp=new Campaign(Id=campId,Five9__Five9list__c=f9List);
        System.debug('\r\t——FINISHED–CAMPAIGN——>\r\r'+JSON.serializePretty(finishedCamp));
        update new Campaign(Id=campId,Five9__Five9list__c=f9List);
    }
    @AuraEnabled
    public static void campaignListActionController(List<Id>campIds,Integer batchSize,Integer minANIs,String defCounty){
        if(campIds.size()>0){
            Set<Id>campIdSet=new Set<Id>(campIds);
            AniAssignerBatchable aniab;
            if(minANIs==null){
                if(defCounty==null){aniab=new AniAssignerBatchable(campIdSet);
                } else { aniab=new AniAssignerBatchable(campIdSet,defCounty);
                }
            } else {
                if(defCounty==null){aniab=new AniAssignerBatchable(campIdSet,minANIs);
                } else { aniab=new AniAssignerBatchable(campIdSet,minANIs,defCounty);
                }
            }
            if(batchSize==null){
                batchSize=50;
            }
            Database.executeBatch(aniab,batchSize);
        } else {
            throw new AuraHandledException('PICK SOMETHING JACKASS');
        }
    }
    public static final Map<String,String>stateFulls=new Map<String,String>{
            'ALABAMA'=>'AL','ALASKA'=>'AK','ARIZONA'=>'AZ','ARKANSAS'=>'AR','CALIFORNIA'=>'CA','COLORADO'=>'CO','CONNECTICUT'=>'CT','DELAWARE'=>'DE','FLORIDA'=>'FL','GEORGIA'=>'GA','HAWAII'=>'HI','IDAHO'=>'ID','ILLINOIS'=>'IL','INDIANA'=>'IN','IOWA'=>'IA','KANSAS'=>'KS','KENTUCKY'=>'KY','LOUISIANA'=>'LA','MAINE'=>'ME','MARYLAND'=>'MD','MASSACHUSETTS'=>'MA','MICHIGAN'=>'MI','MINNESOTA'=>'MN','MISSISSIPPI'=>'MS','MISSOURI'=>'MO','MONTANA'=>'MT','NEBRASKA'=>'NE','NEVADA'=>'NV','NEW HAMPSHIRE'=>'NH','NEW JERSEY'=>'NJ','NEW MEXICO'=>'NM','NEW YORK'=>'NY','NORTH CAROLINA'=>'NC','NORTH DAKOTA'=>'ND','OHIO'=>'OH','OKLAHOMA'=>'OK','OREGON'=>'OR','PENNSYLVANIA'=>'PA','RHODE ISLAND'=>'RI','SOUTH CAROLINA'=>'SC','SOUTH DAKOTA'=>'SD','TENNESSEE'=>'TN','TEXAS'=>'TX','UTAH'=>'UT','VERMONT'=>'VT','VIRGINIA'=>'VA','WASHINGTON'=>'WA','WEST VIRGINIA'=>'WV','WISCONSIN'=>'WI','WYOMING'=>'WY'
    };
    public static final Map<String,String>stateCodes=new Map<String,String>{
            'AL'=>'ALABAMA','AK'=>'ALASKA','AZ'=>'ARIZONA','AR'=>'ARKANSAS','CA'=>'CALIFORNIA','CO'=>'COLORADO','CT'=>'CONNECTICUT','DE'=>'DELAWARE','FL'=>'FLORIDA','GA'=>'GEORGIA','HI'=>'HAWAII','ID'=>'IDAHO','IL'=>'ILLINOIS','IN'=>'INDIANA','IA'=>'IOWA','KS'=>'KANSAS','KY'=>'KENTUCKY','LA'=>'LOUISIANA','ME'=>'MAINE','MD'=>'MARYLAND','MA'=>'MASSACHUSETTS','MI'=>'MICHIGAN','MN'=>'MINNESOTA','MS'=>'MISSISSIPPI','MO'=>'MISSOURI','MT'=>'MONTANA','NE'=>'NEBRASKA','NV'=>'NEVADA','NH'=>'NEW HAMPSHIRE','NJ'=>'NEW JERSEY','NM'=>'NEW MEXICO','NY'=>'NEW YORK','NC'=>'NORTH CAROLINA','ND'=>'NORTH DAKOTA','OH'=>'OHIO','OK'=>'OKLAHOMA','OR'=>'OREGON','PA'=>'PENNSYLVANIA','RI'=>'RHODE ISLAND','SC'=>'SOUTH CAROLINA','SD'=>'SOUTH DAKOTA','TN'=>'TENNESSEE','TX'=>'TEXAS','UT'=>'UTAH','VT'=>'VERMONT','VA'=>'VIRGINIA','WA'=>'WASHINGTON','WV'=>'WEST VIRGINIA','WI'=>'WISCONSIN','WY'=>'WYOMING'
    };
}