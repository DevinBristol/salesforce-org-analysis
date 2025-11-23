/**
 * Fully Combined AniBatchAssigner Class (No Separate Utility Class)
 * Created by NoahR on 6/18/2025
 */
public with sharing class AniBatchAssigner implements Database.Batchable<SObject> {

    public String objectType;
    public List<Id> campaignIds;
    public List<Campaign> campaigns = new List<Campaign>();

    public AniBatchAssigner(String objectType, List<Id> campaignIds) {
        this.objectType = objectType;
        this.campaignIds = campaignIds;
    }

    private List<SObject> recordsToUpdate = new List<SObject>();

    public Database.QueryLocator start(Database.BatchableContext BC) {
        if (objectType == 'Lead') {
            return Database.getQueryLocator([
                    SELECT Id, City, State, ba685ce4_2c28_433a_a4c6_cac18b40f436__c,
                            b7ef8429_9f35_4102_b1ea_44d3453a5086__c
                    FROM Lead
                    WHERE Id IN (
                            SELECT LeadId FROM CampaignMember
                            WHERE CampaignId IN :campaignIds AND LeadId != NULL
                    )
            ]);
        } else {
            return Database.getQueryLocator([
                    SELECT Id, AccountId, MailingCity, MailingState, MailingStreet, MailingPostalCode,
                            ba685ce4_2c28_433a_a4c6_cac18b40f436__c,
                            b7ef8429_9f35_4102_b1ea_44d3453a5086__c
                    FROM Contact
                    WHERE Id IN (
                            SELECT ContactId FROM CampaignMember
                            WHERE CampaignId IN :campaignIds AND ContactId != NULL
                    )
            ]);
        }
    }

    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        if (scope.isEmpty()) {
            System.debug('Empty SCOPE');
            return;
        }

        System.debug('scope is not empty');
        String cityField = (objectType == 'Lead') ? 'City' : 'MailingCity';
        String stateField = (objectType == 'Lead') ? 'State' : 'MailingState';
        String aniField = 'ba685ce4_2c28_433a_a4c6_cac18b40f436__c';
        String b7Field = 'b7ef8429_9f35_4102_b1ea_44d3453a5086__c';

        if (objectType == 'Lead') {
            System.debug('hit Lead');
            TriggerHandler.bypass('LeadTriggerHandler');
        } else {
            TriggerHandler.bypass('ContactTriggerHandler');
        }

        Set<String> cityStrings = new Set<String>();
        for (SObject record : scope) {
            String city = (String) record.get(cityField);
            String state = (String) record.get(stateField);
            if (city != null && state != null) {
                cityStrings.add(city.trim().toUpperCase() + ', ' + state.trim().toUpperCase());
            }

            System.debug('City Strings: ' + cityStrings);
        }

        Map<String, Id> CityCountyIdMap = new Map<String, Id>();
        Map<Id, County__c> counties = new Map<Id, County__c>();
        Map<Id, List<String>> CountyPhonesMap = new Map<Id, List<String>>();
        Map<Id, Integer> CountyIdPhonePosition = new Map<Id, Integer>();
        Map<Id,Integer> CountyMaxAnis = new Map<Id, Integer>();
        Map<String, String> PhoneStringToB7Map = new Map<String, String>();

        List<City__c> cities = [SELECT Id, Name, County__c FROM City__c WHERE Name IN :cityStrings];
        Set<Id> countyIds = new Set<Id>();

        for (City__c city : cities) {
            countyIds.add(city.County__c);
            CityCountyIdMap.put(city.Name.toUpperCase(), city.County__c);
        }

        System.debug('City/Id Map: ' + CityCountyIdMap);

        County__c defaultCounty = [SELECT Id, Name FROM County__c WHERE Name = 'Douglas, NE' LIMIT 1];
        counties.putAll([
                SELECT Id, Name, Backup_County_ANIs__c,
                (SELECT Id, Name, isActive__c, b7__c FROM ANI__r)
                FROM County__c
                WHERE Id IN :countyIds OR Id = :defaultCounty.Id
        ]);

        for (County__c county : counties.values()) {
            List<String> anis = new List<String>();
            CountyIdPhonePosition.put(county.Id, 0);

            for (ANI__c ani : county.ANI__r) {
                if (ani.isActive__c) {
                    anis.add(ani.Name);
                    PhoneStringToB7Map.put(ani.Name, ani.b7__c);
                }
            }

            if (anis.isEmpty() && county.Backup_County_ANIs__c != null) {
                List<ANI__c> backupAnis = [
                        SELECT Name, isActive__c, b7__c FROM ANI__c
                        WHERE County__c = :county.Backup_County_ANIs__c
                ];
                for (ANI__c ani : backupAnis) {
                    if (ani.isActive__c) {
                        anis.add(ani.Name);
                        PhoneStringToB7Map.put(ani.Name, ani.b7__c);
                    }
                }
            }

            if (anis.isEmpty()) {
                List<ANI__c> backupAnis = [
                        SELECT Name, isActive__c, b7__c FROM ANI__c
                        WHERE County__c = :defaultCounty.Id
                ];
                for (ANI__c ani : backupAnis) {
                    if (ani.isActive__c) {
                        anis.add(ani.Name);
                        PhoneStringToB7Map.put(ani.Name, ani.b7__c);
                    }
                }
            }

            CountyMaxAnis.put(county.Id,anis.size());
            CountyPhonesMap.put(county.Id, anis);
        }

        System.debug('Max Anis ' + CountyMaxAnis);
        System.debug('Phones Map : ' + CountyPhonesMap);

        for (SObject record : scope) {
            String city = (String) record.get(cityField);
            String state = (String) record.get(stateField);
            if (String.isBlank(city) || String.isBlank(state)) continue; // use dug

            String cityKey = city.trim().toUpperCase() + ', ' + state.trim().toUpperCase();
            Id countyId = CityCountyIdMap.containsKey(cityKey)
                    ? CityCountyIdMap.get(cityKey)
                    : defaultCounty.Id;

            List<String> anis = CountyPhonesMap.get(countyId);
            if (anis == null || anis.isEmpty()) continue;

            Integer pos = CountyIdPhonePosition.get(countyId);
            String aniVal = anis[pos];
            record.put(aniField, aniVal);
            record.put(b7Field, PhoneStringToB7Map.get(aniVal));
            CountyIdPhonePosition.put(countyId, Math.mod(pos + 1, anis.size()));
        }

        System.debug('Finals Scope: ' + scope);

        System.enqueueJob(new BatchAbleAniHelper(scope));

    }

    public void finish(Database.BatchableContext BC) {
        System.debug('finish called');

    }

    public static void preClearCampaigns(List<Id>campIds){
        List<Campaign>camps=new List<Campaign>();
        System.debug('\nINVOCABLE: preClearCampaigns(Cleared regs):\n\tthis.campaigns—>\n'+JSON.serializePretty(camps));
        for(Campaign camp : camps){ camp.Five9__Five9list__c=null; }
        update camps;
        System.debug('\nConstuctor: preClearCampaigns(Cleared Five9List):\n\tthis.campaigns—>\n'+JSON.serializePretty(camps));
    }
    @AuraEnabled
    public static void campaignListActionController(List<Id>campIds,Integer batchSize){
        if(campIds.size()>0){
            preClearCampaigns(campIds);
            AniBatchAssigner aba=new AniBatchAssigner('Lead',campIds);
            Database.executeBatch(aba,(batchSize??100));
        } else {throw new AuraHandledException('ID PLEASE. JACKASS.');}
    }

}