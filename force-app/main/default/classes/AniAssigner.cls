/**
 * Created by Devin on 10/30/2024.
 */
 //

public with sharing class AniAssigner implements Queueable{

    public AniAssigner(List<Lead> QueueableLeads){
        this.Leads = QueueableLeads;
    }
    public AniAssigner(List<Contact> QueueableContacts){
        this.Contacts = QueueableContacts;
    }

    public static List<Lead> ProcessLeads(List<Lead> LeadsToProcess){
        List<String> cityStrings = new List<String>();

        List<City__c> cities = new List<City__c>();
        List<Id> countyIds = new List<Id>();
        Map<Id,County__c> counties = new Map<Id,County__c>();
        Map<String,Id> CityCountyIdMap = new Map<String, Id>();
        Map<Id,List<String>> CountyPhonesMap = new Map<Id, List<String>>();
        Map<Id,Integer> CountyIdPhonePosition = new Map<Id, Integer>();
        Map<Id,Integer> CountyMaxAnis = new Map<Id, Integer>();
        Map<String,String> PhoneStringToB7Map = new Map<String, String>();


        // Take Input leads and build list of City Strings
        for(Lead l : LeadsToProcess){
            cityStrings.add(l.City + ', ' + l.State);
        }
        System.debug(cityStrings);
        //Query Cities with City Strings
        cities = [SELECT Id,Name,County__c FROM City__c WHERE Name IN :cityStrings];
        System.debug(cities);
        //Loop Cities and build CountyIds for Later SOQL
        //Also, we make a map of CityNames to CountyId for later
        for(City__c c :cities){
            countyIds.add(c.County__c);
            CityCountyIdMap.put(c.Name.toUpperCase(),c.County__c);
        }
        System.debug(cities);
        //Query Counties from CountyIds
        List<County__c> defaultCounties = [SELECT Id,Name FROM County__c WHERE Name = 'Douglas, NE'];
        County__c defaultCounty = defaultCounties[0];

        counties.putAll([SELECT Id,Name,Backup_County_ANIs__c, (SELECT Id, Name,isActive__c,b7__c FROM ANI__r) FROM County__c WHERE Id IN :countyIds OR Id = :defaultCounty.Id]);

        System.debug(counties);
        //Loop Counties and make CountIdPhonePositionMap so we can make a max ANI Integer later
        for(County__c c : counties.values()){
            List<String> anis = new List<String>();
            CountyIdPhonePosition.put(c.Id,0);

            for(ANI__c ani : c.ANI__r){
                if(ani.isActive__c == true){
                    anis.add(ani.Name);
                    PhoneStringToB7Map.put(ani.Name,ani.b7__c);
                }
            }
            // if there are no Active ANIs from the original county then use the backup county ANI's
            if(anis.isEmpty() && c.Backup_County_ANIs__c != null){
                List<ANI__c> backupAnis = new List<ANI__c>([SELECT Id,Name,isActive__c,b7__c FROM ANI__c WHERE County__c = :c.Backup_County_ANIs__c]);
                for(ANI__c ani : backupAnis){
                    if(ani.isActive__c == true){
                        anis.add(ani.Name);
                        PhoneStringToB7Map.put(ani.Name,ani.b7__c);
                    }
                }
            }

            if(anis.isEmpty()) {
                List<ANI__c> backupAnis = new List<ANI__c>([SELECT Id,Name,isActive__c,b7__c FROM ANI__c WHERE County__c = :defaultCounty.Id]);
                for(ANI__c ani : backupAnis){
                    if(ani.isActive__c == true){
                        anis.add(ani.Name);
                        PhoneStringToB7Map.put(ani.Name,ani.b7__c);
                    }
                }
            }
            CountyMaxAnis.put(c.Id,anis.size());
            CountyPhonesMap.put(c.Id,anis);
        }
        for(Lead l : LeadsToProcess){ String cityName=l.City.toUpperCase() + ', ' + l.State.toUpperCase();
            List<String> potentialANIs = CountyPhonesMap.get(CityCountyIdMap.get(cityName));
            System.debug(l.City + ', ' + l.State);
            if(potentialANIs != null){
                System.debug(l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c);
                l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c = potentialANIs.get(CountyIdPhonePosition.get(CityCountyIdMap.get(cityName)));
                System.debug(l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c);

                System.debug(l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c);
                l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c = PhoneStringToB7Map.get(l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c);
                System.debug(l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c);
                CountyIdPhonePosition.put(CityCountyIdMap.get(cityName),CountyIdPhonePosition.get(CityCountyIdMap.get(cityName))+1);
                if(CountyIdPhonePosition.get(CityCountyIdMap.get(cityName)) == potentialANIs.size()){
                    CountyIdPhonePosition.put(CityCountyIdMap.get(cityName),0);
                }
            } else if(potentialANIs == null){
                potentialANIs = CountyPhonesMap.get(defaultCounty.Id);
                System.debug(l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c);
                l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c = potentialANIs.get(CountyIdPhonePosition.get(defaultCounty.Id));
                System.debug(l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c);

                System.debug(l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c);
                l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c = PhoneStringToB7Map.get(l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c);
                System.debug(l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c);

                CountyIdPhonePosition.put(defaultCounty.Id,CountyIdPhonePosition.get(defaultCounty.Id)+1);
                if(CountyIdPhonePosition.get(defaultCounty.Id) == potentialANIs.size()){
                    CountyIdPhonePosition.put(defaultCounty.Id,0);
                }
            }
        }
        return LeadsToProcess;
    }
    public static List<Contact> ProcessContacts(List<Contact> ContactsToProcess){
        List<String> cityStrings = new List<String>();
        List<String> stateStrings = new List<String>();
        List<City__c> cities = new List<City__c>();
        List<Id> countyIds = new List<Id>();
        Map<Id,County__c> counties = new Map<Id,County__c>();
        Map<String,Id> CityCountyIdMap = new Map<String, Id>();
        Map<Id,List<String>> CountyPhonesMap = new Map<Id, List<String>>();
        Map<Id,Integer> CountyIdPhonePosition = new Map<Id, Integer>();
        Map<Id,Integer> CountyMaxAnis = new Map<Id, Integer>();
        Map<String,String> PhoneStringToB7Map = new Map<String, String>();

//        ContactsToProcess = AddMailingAddressToContacts(ContactsToProcess);

        for(Contact c : ContactsToProcess ){
            cityStrings.add(c.MailingCity.toUpperCase()+', '+c.MailingState.toUpperCase());
        }
        System.debug(cityStrings);
        cities = [SELECT Id,Name,County__c FROM City__c WHERE Name IN :cityStrings];
        System.debug(cities);

        for(City__c c :cities){
            countyIds.add(c.County__c);
            CityCountyIdMap.put(c.Name.toUpperCase(),c.County__c);
        }
        System.debug(cities);

        List<County__c> defaultCounties = [SELECT Id,Name FROM County__c WHERE Name = 'Douglas, NE'];
        County__c defaultCounty = defaultCounties[0];

        counties.putAll([SELECT Id,Name,Backup_County_ANIs__c, (SELECT Id, Name,isActive__c,b7__c FROM ANI__r) FROM County__c WHERE Id IN :countyIds OR Id = :defaultCounty.Id]);
        System.debug(counties);

        for(County__c c : counties.values()){
            List<String> anis = new List<String>();
            CountyIdPhonePosition.put(c.Id,0);

            for(ANI__c ani : c.ANI__r){
                if(ani.isActive__c == true){
                    anis.add(ani.Name);
                    PhoneStringToB7Map.put(ani.Name,ani.b7__c);
                }
            }
            // if there are no Active ANIs from the original county then use the backup county ANI's
            if(anis.isEmpty() && c.Backup_County_ANIs__c != null){
                List<ANI__c> backupAnis = new List<ANI__c>([SELECT Id,Name,isActive__c,b7__c FROM ANI__c WHERE County__c = :c.Backup_County_ANIs__c]);
                for(ANI__c ani : backupAnis){
                    if(ani.isActive__c == true){
                        anis.add(ani.Name);
                        PhoneStringToB7Map.put(ani.Name,ani.b7__c);
                    }
                }
            }
            if(anis.isEmpty()) {
                List<ANI__c> backupAnis = new List<ANI__c>([SELECT Id,Name,isActive__c,b7__c FROM ANI__c WHERE County__c = :defaultCounty.Id]);
                for(ANI__c ani : backupAnis){
                    if(ani.isActive__c == true){
                        anis.add(ani.Name);
                        PhoneStringToB7Map.put(ani.Name,ani.b7__c);
                    }
                }
            }

            CountyMaxAnis.put(c.Id,anis.size());
            CountyPhonesMap.put(c.Id,anis);
        }

        for(Contact c : ContactsToProcess){ String cityName=c.MailingCity.toUpperCase() + ', ' + c.MailingState.toUpperCase();
            List<String> potentialANIs = CountyPhonesMap.get(CityCountyIdMap.get(cityName));
            System.debug(cityName);
            if(potentialANIs != null){
                System.debug(c.ba685ce4_2c28_433a_a4c6_cac18b40f436__c);
                c.ba685ce4_2c28_433a_a4c6_cac18b40f436__c = potentialANIs.get(CountyIdPhonePosition.get(CityCountyIdMap.get(cityName)));
                System.debug(c.ba685ce4_2c28_433a_a4c6_cac18b40f436__c);

                System.debug(c.b7ef8429_9f35_4102_b1ea_44d3453a5086__c);
                c.b7ef8429_9f35_4102_b1ea_44d3453a5086__c = PhoneStringToB7Map.get(c.ba685ce4_2c28_433a_a4c6_cac18b40f436__c);
                System.debug(c.b7ef8429_9f35_4102_b1ea_44d3453a5086__c);

                CountyIdPhonePosition.put(CityCountyIdMap.get(cityName),CountyIdPhonePosition.get(CityCountyIdMap.get(cityName))+1);
                if(CountyIdPhonePosition.get(CityCountyIdMap.get(cityName)) == potentialANIs.size()){
                    CountyIdPhonePosition.put(CityCountyIdMap.get(cityName),0);
                }
            } else if(potentialANIs == null){
                potentialANIs = CountyPhonesMap.get(defaultCounty.Id);
                System.debug(c.ba685ce4_2c28_433a_a4c6_cac18b40f436__c);
                c.ba685ce4_2c28_433a_a4c6_cac18b40f436__c = potentialANIs.get(CountyIdPhonePosition.get(defaultCounty.Id));
                System.debug(c.ba685ce4_2c28_433a_a4c6_cac18b40f436__c);

                System.debug(c.b7ef8429_9f35_4102_b1ea_44d3453a5086__c);
                c.b7ef8429_9f35_4102_b1ea_44d3453a5086__c = PhoneStringToB7Map.get(c.ba685ce4_2c28_433a_a4c6_cac18b40f436__c);
                System.debug(c.b7ef8429_9f35_4102_b1ea_44d3453a5086__c);

                CountyIdPhonePosition.put(defaultCounty.Id,CountyIdPhonePosition.get(defaultCounty.Id)+1);
                if(CountyIdPhonePosition.get(defaultCounty.Id) == potentialANIs.size()){
                    CountyIdPhonePosition.put(defaultCounty.Id,0);
                }
            }
        }
        return ContactsToProcess;
    }

    public void execute(QueueableContext context){
        if(Leads!=null){
            TriggerHandler.bypass('LeadTriggerHandler');
            Leads = AniAssigner.ProcessLeads(Leads);
            update Leads;
        }
        if(Contacts!=null){
            TriggerHandler.bypass('ContactTriggerHandler');
            Contacts = AniAssigner.ProcessContacts(Contacts);
            update Contacts;
        }
    }

    public static List<List<Lead>> leadLoadSplits(List<Lead> Leads){
        List<List<Lead>> leadLoads = new List<List<Lead>>();
        Integer totalLeads = Leads.size();
        Integer loadSize = 500;
        Integer loads = totalLeads/loadSize;
        Integer r = Math.mod(totalLeads,loadSize);

        for (Integer i = 0; i < loads; i++){
            List<Lead> load = new List<Lead>();
            for(Integer j = 0; j < loadSize; j++){
                load.add(Leads[j]);
            }
            for(Integer j = 0; j < loadSize; j++){
                Leads.remove(0);
            }
            leadLoads.add(load);
        }
        if(r > 0){
            List<Lead> load = new List<Lead>();
            load.addAll(Leads);
            leadLoads.add(load);
        }
        System.debug(leadLoads);

        return leadLoads;
    }
    public static List<List<Contact>> contactLoadSplits(List<Contact> Contacts){
        List<List<Contact>> contactLoads = new List<List<Contact>>();
        Integer totalContacts = Contacts.size();
        Integer loadSize = 500;
        Integer loads = totalContacts/loadSize;
        Integer r = Math.mod(totalContacts,loadSize);

        for (Integer i = 0; i < loads; i++){
            List<Contact> load = new List<Contact>();
            for(Integer j = 0; j < loadSize; j++){
                load.add(Contacts[j]);
            }
            for(Integer j = 0; j < loadSize; j++){
                Contacts.remove(0);
            }
            contactLoads.add(load);
        }
        if(r > 0){
            List<Contact> load = new List<Contact>();
            load.addAll(Contacts);
            contactLoads.add(load);
        }
        System.debug(contactLoads);

        return contactLoads;
    }

    @InvocableMethod(Label='Refresh ANIs' Description='Updates ANIs for Leads in the Campaign' Category='Campaign')
    public static void RefreshANIs(List<Id> recordIds){
        List<Lead> Leads = GetLeadsByCampaignId(recordIds);
        List<Contact> Contacts = GetContactsByCampaignId(recordIds);
        if(!Leads.isEmpty()){
            List<List<Lead>> leadLoads = leadLoadSplits(Leads);
            for(List<Lead> load : leadLoads){
                System.enqueueJob(new AniAssigner(load));
            }
        }
        if(!Contacts.isEmpty()) {
            List<List<Contact>> contactLoads = contactLoadSplits(Contacts);
            for (List<Contact> load : contactLoads) {
                System.enqueueJob(new AniAssigner(load));
            }
        }
    }
    public static List<Lead> GetLeadsByCampaignId(List<Id> CampaignIds){
        System.debug(CampaignIds);
        List<Id> leadIds = new List<Id>();
        Campaign c = [SELECT Id, (SELECT Id,LeadId,City FROM CampaignMembers WHERE ContactId = NULL) FROM Campaign WHERE Id IN :CampaignIds LIMIT 1];
        System.debug(c);
        for(CampaignMember cMbr : c.CampaignMembers){
            leadIds.add(cMbr.LeadId);
        }
        List<Lead> leads = [SELECT Id,ba685ce4_2c28_433a_a4c6_cac18b40f436__c,b7ef8429_9f35_4102_b1ea_44d3453a5086__c, Street, City, State, PostalCode, MobilePhone, Phone FROM Lead WHERE Id IN :leadIds AND Status = 'Open'];
        return leads;
    }
    public static List<Contact> GetContactsByCampaignId(List<Id> CampaignIds){
        List<Id> ContactIds = new List<Id>();
        Campaign c = [SELECT Id, (SELECT Id,ContactId,City FROM CampaignMembers WHERE ContactId != NULL) FROM Campaign WHERE Id IN :CampaignIds LIMIT 1];
        for(CampaignMember cMbr : c.CampaignMembers){
            ContactIds.add(cMbr.ContactId);
        }
        List<Contact> contacts = [SELECT Id,AccountId,ba685ce4_2c28_433a_a4c6_cac18b40f436__c,b7ef8429_9f35_4102_b1ea_44d3453a5086__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MobilePhone, Phone FROM Contact WHERE Id IN :ContactIds];
        return contacts;
    }
    public static List<Contact> AddMailingAddressToContacts(List<Contact> contacts){
        Set<Id> AccIds = new Set<Id>();
        List<Contact> ContactsWithMailing = new List<Contact>();
        for(Contact c : contacts){
            AccIds.add(c.AccountId);
        }
        List<Account> accounts = new List<Account>([SELECT Id,(SELECT Id,Property__r.Address__c FROM Account_Property_Relationships__r),(SELECT Id,ba685ce4_2c28_433a_a4c6_cac18b40f436__c,b7ef8429_9f35_4102_b1ea_44d3453a5086__c,AccountId FROM Contacts) FROM Account WHERE Id IN :AccIds]);
        for(Account a : accounts){
            if(!a.Account_Property_Relationships__r.isEmpty()){
                for (Contact c : a.Contacts){
                    c.MailingStreet = a.Account_Property_Relationships__r[0].Property__r.Address__c.getStreet();
                    c.MailingCity = a.Account_Property_Relationships__r[0].Property__r.Address__c.getCity();
                    c.MailingState = a.Account_Property_Relationships__r[0].Property__r.Address__c.getStateCode();
                    c.MailingPostalCode = a.Account_Property_Relationships__r[0].Property__r.Address__c.getPostalCode();
                    c.MailingCountry = a.Account_Property_Relationships__r[0].Property__r.Address__c.getCountry();
                    ContactsWithMailing.add(c);
                }
            }
        }
        return ContactsWithMailing;
    }

    private List<Lead> Leads;
    private List<Contact> Contacts;
}