/**
 * Created by Ben on 12/5/2024.
 */
@IsTest
public with sharing class AniAssignerTest {
    public static final Integer defaultLoadSize = 200;
    public static Integer prevQueriesUsed = 0;
    public static Map<String, List<String>> countyCityStringsMap = new Map<String, List<String>>{
            'Douglas, NE' => new List<String>{//8
                    'Bennington', 'Omaha', 'Ralston', 'Valley', 'Waterloo'
            },
            'Lancaster, NE' => new List<String>{//16
                    'Davey', 'Denton', 'Emerald', 'Firth',
                    'Hallam', 'Hickman', 'Kramer', 'Lincoln'
            },
            'Gage, NE' => new List<String>{//12
                    'Adams', 'Barneston', 'Beatrice', 'Blue Springs'
            }
            ,
            'Custer, NE' => new List<String>{
                    'Anselmo', 'Arnold', 'Broken Bow', 'Callaway'
            }

    };

    public static Map<String, String> cityZipMap = new Map<String, String>{
            //5//Douglas-01
            'Bennington' => '68007', 'Omaha' => '68102', 'Ralston' => '68127', 'Valley' => '68064', 'Waterloo' => '68069',

            //8//Lancaster-02
            'Davey' => '68336', 'Denton' => '68339', 'Emerald' => '68528', 'Firth' => '68358',
            'Hallam' => '68368', 'Hickman' => '68372', 'Kramer' => '68333', 'Lincoln' => '68508',

            //4//Gage-03
            'Adams' => '68301', 'Barneston' => '68309', 'Beatrice' => '68310', 'Blue Springs' => '68318'

            ,            //Custer-04
            'Anselmo' => '68813', 'Arnold' => '69120', 'Broken Bow' => '68822'

    };
    public static Integer recordMax = 0;

    @TestSetup
    static void aniAssignerTestSetup() {
        System.debug('Counties Count = ' + countyCityStringsMap.keySet().size());
        Integer newQueriesUsed = 0;
        List<Lead> leads = new List<Lead>();
        List<Account> accounts = new List<Account>();
        List<Contact> contacts = new List<Contact>();
        List<County__c> counties = new List<County__c>();
        List<City__c> cities = new List<City__c>();
        List<ANI__c> anis = new List<ANI__c>();
        List<String> countyKeyList = new List<String>();

        List<String> leadStreets = new List<String>();
        List<String> acctStreets = new List<String>();

        countyKeyList.addAll(countyCityStringsMap.keySet());

        System.debug(' SOQL LIMITS:—>BeforeDMLs.ALL[recordMax —> ' + recordMax + '; QueriesUsed —> ' + Limits.getQueries() + '; Query Limit —> ' + Limits.getLimitQueries() + '; agrQueries —> ' + Limits.getAggregateQueries() + '; agrQueries Limit —> ' + Limits.getLimitAggregateQueries() + ' ]');
        for (String countyKey : countyCityStringsMap.keySet()) {
            recordMax = recordMax + countyCityStringsMap.get(countyKey).size();
            County__c county = new County__c(Name = countyKey, State__c = 'NE');
            counties.add(county);
        }
        insert counties;
//        System.debug((' '.repeat(5))+'SOQL LIMITS:—>inserted '+counties.size()+' Counties; DML Cost '+(Limits.getQueries()-prevQueriesUsed)+' Queries...'+'\r'+(' '.repeat(52))+'We have '+(100-Limits.getQueries())+'/100 queries Remaining'+'\r'+(' '.repeat(52))+'This DML Made —> '+(Limits.getQueries()-prevQueriesUsed)+' Queries on '+counties.size()+' Counties⇝('+(((Decimal)Limits.getQueries()-(Decimal)prevQueriesUsed)/(Decimal)counties.size())+'Queries / County Inserted) '+'\r'+(' '.repeat(52))+' THE MAX NUMBER OF COUNTY INSERTS IS —> '+Integer.valueOf(100/(((Decimal)Limits.getQueries()-(Decimal)prevQueriesUsed)/(Decimal)counties.size()))+']');
        System.debug((' '.repeat(5)) + 'SOQL LIMITS:—>inserted ' + counties.size() + ' Counties; DML Cost ' + (Limits.getQueries() - prevQueriesUsed) + ' Queries...' + '\r' + (' '.repeat(52)) + 'We have ' + (100 - Limits.getQueries()) + '/100 queries Remaining' + '\r' + (' '.repeat(52)) + 'This DML Made —> ' + (Limits.getQueries() - prevQueriesUsed) + ' Queries on ' + counties.size() + ' Counties⇝(' + (((Decimal) Limits.getQueries() - (Decimal) prevQueriesUsed) / (Decimal) counties.size()) + 'Queries / County Inserted) ' + '\r' + (' '.repeat(52)) + ' THE MAX NUMBER OF COUNTY INSERTS IS —> ' + Integer.valueOf(100 / (((Decimal) Limits.getQueries() - (Decimal) prevQueriesUsed) / 1 + (Decimal) counties.size())) + ']');

        prevQueriesUsed = Limits.getQueries();
        List<County__c> updateCounties = new List<County__c>();
        for (County__c county : counties) {
            Integer countyX = counties.indexOf(county);
            if (counties.indexOf(county) == 0) {//default county first —> Douglas — 01 no backup
            } else { //for backup just do the highest index county in list
                county.Backup_County_ANIs__c = counties[counties.indexOf(county) - 1].Id;
                updateCounties.add(county);
            }
            System.debug('updateCounties—>' + updateCounties);
            for (String cityName : countyCityStringsMap.get(county.Name)) {
                Integer countyCityX = countyCityStringsMap.get(county.Name).indexOf(cityName);
                String codeSuffix = ('0' + countyX).right(2) + ('0' + countyCityX).right(2);
                cities.add(new City__c(
                        Name = cityName + ', ' + county.State__c, State__c = county.State__c, County__c = county.Id
                ));
                String leadStreet = Integer.valueOf(codeSuffix).toString() + ' Road ' + cityName.left(1).toUpperCase();
                String acctStreet = codeSuffix + ' ' + cityName.reverse() + ' ' + 'Street';
                leadStreets.add(leadStreet);
                acctStreets.add(acctStreet);

                Lead l = new Lead(FirstName = 'l' + countyX + '.' + countyCityX, LastName = county.Name.substringBefore(',') + '.' + cityName,
                        MobilePhone = '666666' + codeSuffix, Street = leadStreet, City = cityName, State = county.State__c, PostalCode = cityZipMap.get(cityName),
                        Country = 'US', Status = 'Open', Company = 'l' + codeSuffix,
                        Name_of_Lead_Source__c = 'AniAssignerTest');
                leads.add(l);
                System.debug('Lead(' + l.FirstName + ' ' + l.LastName + ') —> [' + l + ']');
                accounts.add(new Account(Name = 'a' + codeSuffix, BillingStreet = acctStreet,
                        BillingCity = cityName, BillingState = county.State__c, BillingPostalCode = cityZipMap.get(cityName), BillingCountry = 'US', Name_of_Lead_Source__c = 'AniAssignerTest')
                );
                contacts.add(new Contact(FirstName = 'c' + countyX + '.' + countyCityX, LastName = county.Name.substringBefore(',') + '.' + cityName,
                        MobilePhone = '777777' + codeSuffix, MailingStreet = acctStreet, MailingCity = cityName, MailingState = county.State__c, MailingPostalCode = cityZipMap.get(cityName), MailingCountry = 'US')
                );
                System.debug('lead [' + countyX + '.' + countyCityX + ']--> ' + leads[countyCityX]);
                System.debug('contact [' + countyX + '.' + countyCityX + ']--> ' + contacts[countyCityX]);
                System.debug('acct [' + countyX + '.' + countyCityX + ']--> ' + accounts[countyCityX]);
            }
        }
        insert leads;
        System.debug('\r' + (' '.repeat(52)) + 'SOQL LIMITS:—>inserted ' + leads.size() + ' Leads; DML Cost ' + (Limits.getQueries() - prevQueriesUsed) + ' Queries...' + '\r' + (' '.repeat(52)) + 'We have ' + (100 - Limits.getQueries()) + '/100 queries Remaining' + '\r' + (' '.repeat(52)) + 'This DML Made —> ' + (Limits.getQueries() - prevQueriesUsed) + ' Queries on ' + leads.size() + ' Leads⇝(' + (((Decimal) Limits.getQueries() - (Decimal) prevQueriesUsed) / (Decimal) leads.size()) + 'Queries / Lead Inserted) ' + '\r' + (' '.repeat(52)) + ' THE MAX NUMBER OF LEAD INSERTS IS —> ' + Integer.valueOf(100 / (((Decimal) Limits.getQueries() - (Decimal) prevQueriesUsed) / (Decimal) leads.size())) + ']');
        prevQueriesUsed = Limits.getQueries();
        insert cities;
        System.debug('cities(post-Insert)—>' + cities);
        System.debug('\r' + (' '.repeat(52)) + 'SOQL LIMITS:—>inserted ' + cities.size() + ' Cities; DML Cost ' + (Limits.getQueries() - prevQueriesUsed) + ' Queries...' + '\r' + (' '.repeat(52)) + 'We have ' + (100 - Limits.getQueries()) + '/100 queries Remaining' + '\r' + (' '.repeat(52)) + 'This DML Made —> ' + (Limits.getQueries() - prevQueriesUsed) + ' Queries on ' + cities.size() + ' Cities⇝(' + (((Decimal) Limits.getQueries() - (Decimal) prevQueriesUsed) / .1 + (Decimal) cities.size()) + 'Queries / City Inserted) ' + '\r' + (' '.repeat(52)) + ' THE MAX NUMBER OF CITY INSERTS IS —> ' + Integer.valueOf(100 / (1 + ((Decimal) Limits.getQueries() - (Decimal) prevQueriesUsed) / (Decimal) cities.size())) + ']');
        prevQueriesUsed = Limits.getQueries();
        update updateCounties;
        System.debug('\r' + (' '.repeat(52)) + 'SOQL LIMITS:—>updated ' + updateCounties.size() + ' Counties; DML Cost ' + (Limits.getQueries() - prevQueriesUsed) + ' Queries...' + '\r' + (' '.repeat(52)) + 'We have ' + (100 - Limits.getQueries()) + '/100 queries Remaining' + '\r' + (' '.repeat(52)) + 'This DML Made —> ' + (Limits.getQueries() - prevQueriesUsed) + ' Queries on ' + updateCounties.size() + ' Counties⇝(' + (((Decimal) Limits.getQueries() - (Decimal) prevQueriesUsed) / (Decimal) updateCounties.size()) + 'Queries / County Updated) ' + '\r' + (' '.repeat(52)) + ' THE MAX NUMBER OF COUNTY UPDATES IS —> ' + Integer.valueOf(100 / (1 + ((Decimal) Limits.getQueries() - (Decimal) prevQueriesUsed) / (Decimal) updateCounties.size())) + ']');
        prevQueriesUsed = Limits.getQueries();
        insert accounts;
        System.debug('\r' + (' '.repeat(52)) + 'SOQL LIMITS:—>inserted ' + accounts.size() + ' Accounts; DML Cost ' + (Limits.getQueries() - prevQueriesUsed) + ' Queries...' + '\r' + (' '.repeat(52)) + 'We have ' + (100 - Limits.getQueries()) + '/100 queries Remaining' + '\r' + (' '.repeat(52)) + 'This DML Made —> ' + (Limits.getQueries() - prevQueriesUsed) + ' Queries on ' + accounts.size() + ' Accounts⇝(' + (((Decimal) Limits.getQueries() - (Decimal) prevQueriesUsed) / (Decimal) accounts.size()) + 'Queries / Account Inserted) ' + '\r' + (' '.repeat(52)) + ' THE MAX NUMBER OF ACCOUNT INSERTS IS —> ' + Integer.valueOf(100 / (((Decimal) Limits.getQueries() - (Decimal) prevQueriesUsed) / (Decimal) accounts.size())) + ']');
        prevQueriesUsed = Limits.getQueries();

        Map<String, Id> cityNameToCountyIdMap = new Map<String, Id>();
        for (City__c c : cities) {
            cityNameToCountyIdMap.put(c.Name, c.County__c);
        }
        System.debug('cityNameToCountyIdMap —> ' + cityNameToCountyIdMap);

        for (Account a : accounts) {
            Contact c = contacts.get(accounts.indexOf(a));
            c.AccountId = a.Id;
            System.debug('Contact(' + c.FirstName + ' ' + c.LastName + ') —> [' + c + ']');
        }
        insert contacts;
        System.debug('\r' + (' '.repeat(52)) + 'SOQL LIMITS:—>inserted ' + contacts.size() + ' Contacts; DML Cost ' + (Limits.getQueries() - prevQueriesUsed) + ' Queries...' + '\r' + (' '.repeat(52)) + 'We have ' + (100 - Limits.getQueries()) + '/100 queries Remaining' + '\r' + (' '.repeat(52)) + 'This DML Made —> ' + (Limits.getQueries() - prevQueriesUsed) + ' Queries on ' + contacts.size() + ' Contacts⇝(' + (((Decimal) Limits.getQueries() - (Decimal) prevQueriesUsed) / (Decimal) contacts.size()) + ' Queries / Contact Inserted) ' + '\r' + (' '.repeat(52)) + ' THE MAX NUMBER OF CONTACTS INSERTS IS —> ' + Integer.valueOf(100 / (((Decimal) Limits.getQueries() - (Decimal) prevQueriesUsed) / (Decimal) contacts.size())) + ']');
        prevQueriesUsed = Limits.getQueries();
        List<Property__c> props = [
                SELECT Id, Address__Street__s, Address__City__s, Address__StateCode__s, Address__PostalCode__s, Address__CountryCode__s, Address__Latitude__s, Address__Longitude__s, Address__c, AccountId__c
                FROM Property__c
                WHERE Address__Street__s IN :leadStreets OR Address__Street__s IN :acctStreets
        ];
        System.debug('SOQL LIMITS:—>postProperty SOQL[props.size—>' + props.size() + '; usedQueries—>' + Limits.getQueries() + '; agrQueries—>' + Limits.getAggregateQueries() + '/100; qUse/property—>' + (Limits.getQueries() / props.size()));

        System.debug('all cityNameToCountyIdMap ——>' + cityNameToCountyIdMap);
        for (Lead l : leads) {
            System.debug('get Mapped [city,State]=>County Record——>' + cityNameToCountyIdMap.get(l.City + ', ' + l.State));
            if (countyCityStringsMap.get('Douglas, NE').contains(l.City)) {
                anis.add(
                        new ANI__c(Name = '5555550000', City__c = l.City + ', NE', County__c = cityNameToCountyIdMap.get(l.City + ', ' + l.State), isActive__c = true, b7__c = 'testB7-0')
                );
            } else if (countyCityStringsMap.get('Lancaster, NE').contains(l.City)) {
                anis.add(
                        new ANI__c(Name = '5555551111', City__c = l.City + ', NE', County__c = cityNameToCountyIdMap.get(l.City + ', ' + l.State), isActive__c = true, b7__c = 'testB7-1')
                );
            } else if (countyCityStringsMap.get('Gage, NE').contains(l.City)) { //this one is inactive
                anis.add(
                        new ANI__c(Name = '5555552222', City__c = l.City + ', NE', County__c = cityNameToCountyIdMap.get(l.City + ', ' + l.State), isActive__c = false, b7__c = 'testB7-2')
                );
            }
        }
        insert anis;
        System.debug('anis(' + anis.size() + ' inserts)—>' + anis);

        List<Campaign> camps = new List<Campaign>{
                new Campaign(Name='testCampaign')
        };
        insert camps;
        List<Id> campIds = new List<Id>();
        for(Campaign camp : camps){
            campIds.add(camp.Id);
        }
        List<CampaignMember> cMbrs = new List<CampaignMember>();
        for(Lead l : leads){
            cMbrs.add(new CampaignMember(LeadId = l.Id,CampaignId = camps[0].Id));
        }
        for(Contact c : contacts){
            cMbrs.add(new CampaignMember(contactId = c.Id,CampaignId = camps[0].Id));
        }
        insert cMbrs;
    }
//    @IsTest static void testEnqueue(){
//        List<Lead> leads = [SELECT Id, FirstName, LastName, MobilePhone, Phone, Secondary_Contact_Mobile__c, ba685ce4_2c28_433a_a4c6_cac18b40f436__c, b7ef8429_9f35_4102_b1ea_44d3453a5086__c, Street, City, State FROM Lead WHERE Name_of_Lead_Source__c = 'AniAssignerTest'];
//        List<Contact> contacts = [SELECT Id, AccountId, MobilePhone, HomePhone, Phone, ba685ce4_2c28_433a_a4c6_cac18b40f436__c, b7ef8429_9f35_4102_b1ea_44d3453a5086__c, MailingStreet, MailingCity, MailingState FROM Contact WHERE MobilePhone LIKE '777777%'];
//
//        System.debug('first job: leads size: ' + leads.size());
//        System.debug('second job: contacts size: ' + contacts.size());
////        System.assertEquals(updateableCount,mockResList.size());
//
//        Test.startTest();
//        AniAssigner ldAniAssigner = new AniAssigner(leads);
//        System.assertEquals(leads, ldAniAssigner.Leads, 'LEAD aniAssigner constructor... AniAssigner.Leads public list should be [queried testSetup] leads');
//        System.enqueueJob(ldAniAssigner);
//
//        AniAssigner ctAniAssigner = new AniAssigner(contacts);
//        System.assertEquals(contacts, ctAniAssigner.Contacts, 'CONTACT aniAssigner constructor... AniAssigner.Contacts public list should be [queried testSetup] contacts');
////        System.enqueueJob(ctAniAssigner);
//        Test.stopTest();
//    }
    @IsTest
    static void testProcessLeads() {
        List<County__c> defaultCounties = [SELECT Id, Name FROM County__c WHERE Name = 'Douglas, NE'];

        List<Lead> leads = [SELECT Id, FirstName, LastName, MobilePhone, Phone, Secondary_Contact_Mobile__c, ba685ce4_2c28_433a_a4c6_cac18b40f436__c, b7ef8429_9f35_4102_b1ea_44d3453a5086__c, Street, City, State FROM Lead WHERE Name_of_Lead_Source__c = 'AniAssignerTest'];
        List<Lead> leadsPre = leads;
        List<Lead> assertLeads = AniAssigner.ProcessLeads(leads);
        System.debug('leads(pre) —> ' + leadsPre);
        System.debug('assertLeads—> ' + assertLeads);
        System.assertEquals(leads.size(), assertLeads.size());

        for (Lead l : assertLeads) {
            Integer countyANIx;

            //the index where gage county leads start (which have no anis active & should lookup, those with lookups to inactive counties to douglas, ne anis);
            if (countyCityStringsMap.get('Douglas, NE').contains(l.City)) {
                System.assertEquals('testB7-0', l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c, +l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c + ' on Record—>[' + leads.indexOf(l) + '] ... ' + l);
                System.assertEquals('5555550000', l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c, +l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c + ' on Record—>[' + leads.indexOf(l) + '] ... ' + l);
            } else if (countyCityStringsMap.get('Lancaster, NE').contains(l.City)) {
                System.assertEquals('testB7-1', l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c, +l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c + ' on Record—>[' + leads.indexOf(l) + '] ... ' + l);
                System.assertEquals('5555551111', l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c, +l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c + ' on Lead Record—>[' + leads.indexOf(l) + '] ... ' + l);
            } else if (countyCityStringsMap.get('Gage, NE').contains(l.City)) { //backup county anis
                System.assertEquals('testB7-1', l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c, +l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c + ' on Lead Record—>[' + leads.indexOf(l) + '] ... ' + l);
                System.assertEquals('5555551111', l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c, +l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c + ' on Lead Record—>[' + leads.indexOf(l) + '] ... ' + l);
            } else if (countyCityStringsMap.get('Custer, NE').contains(l.City)) { //backup county anis
                System.assertEquals('testB7-0', l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c, +l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c + ' on Lead Record—>[' + leads.indexOf(l) + '] ... ' + l);
                System.assertEquals('5555550000', l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c, +l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c + ' on Lead Record—>[' + leads.indexOf(l) + '] ... ' + l);
            }
        }

    }
    @IsTest
    static void testProcessContacts() {
        List<County__c> defaultCounties = [SELECT Id, Name FROM County__c WHERE Name = 'Douglas, NE'];
        List<City__c> cities = [SELECT Name, Id, County__c FROM City__c WHERE CreatedDate = TODAY];
        System.debug('cities queried—>' + cities);
        List<Contact> contacts = [SELECT Id, AccountId, MobilePhone, HomePhone, Phone, ba685ce4_2c28_433a_a4c6_cac18b40f436__c, b7ef8429_9f35_4102_b1ea_44d3453a5086__c, MailingStreet, MailingCity, MailingState FROM Contact WHERE MobilePhone LIKE '777777%'];
        System.debug('contacts(prrocessCe) —> ' + contacts);
        List<Contact> assertContacts = AniAssigner.ProcessContacts(contacts);

        System.debug('assertContacts—> ' + assertContacts);
        System.assertEquals(contacts.size(), assertContacts.size());
        for (Contact c : assertContacts) {
            if (countyCityStringsMap.get('Douglas, NE').contains(c.MailingCity)) {
                System.assertEquals('testB7-0', c.b7ef8429_9f35_4102_b1ea_44d3453a5086__c, +c.b7ef8429_9f35_4102_b1ea_44d3453a5086__c + ' on Contact Record—>[' + contacts.indexOf(c) + '] ... ' + c);
                System.assertEquals('5555550000', c.ba685ce4_2c28_433a_a4c6_cac18b40f436__c, +c.ba685ce4_2c28_433a_a4c6_cac18b40f436__c + ' on Contact Record—>[' + contacts.indexOf(c) + '] ... ' + c);
            } else if (countyCityStringsMap.get('Lancaster, NE').contains(c.MailingCity)) {
                System.assertEquals('testB7-1', c.b7ef8429_9f35_4102_b1ea_44d3453a5086__c, +c.b7ef8429_9f35_4102_b1ea_44d3453a5086__c + ' on Contact Record—>[' + contacts.indexOf(c) + '] ... ' + c);
                System.assertEquals('5555551111', c.ba685ce4_2c28_433a_a4c6_cac18b40f436__c, +c.ba685ce4_2c28_433a_a4c6_cac18b40f436__c + ' on Contact Record—>[' + contacts.indexOf(c) + '] ... ' + c);
            } else if (countyCityStringsMap.get('Gage, NE').contains(c.MailingCity)) { //backup county anis
                System.assertEquals('testB7-1', c.b7ef8429_9f35_4102_b1ea_44d3453a5086__c, +c.b7ef8429_9f35_4102_b1ea_44d3453a5086__c + ' on Contact Record—>[' + contacts.indexOf(c) + '] ... ' + c);
                System.assertEquals('5555551111', c.ba685ce4_2c28_433a_a4c6_cac18b40f436__c, +c.ba685ce4_2c28_433a_a4c6_cac18b40f436__c + ' on Contact Record—>[' + contacts.indexOf(c) + '] ... ' + c);
            } else if (countyCityStringsMap.get('Custer, NE').contains(c.MailingCity)) { //backup county anis
                System.assertEquals('testB7-0', c.b7ef8429_9f35_4102_b1ea_44d3453a5086__c, +c.b7ef8429_9f35_4102_b1ea_44d3453a5086__c + ' on Contact Record—>[' + contacts.indexOf(c) + '] ... ' + c);
                System.assertEquals('5555550000', c.ba685ce4_2c28_433a_a4c6_cac18b40f436__c, +c.ba685ce4_2c28_433a_a4c6_cac18b40f436__c + ' on Contact Record—>[' + contacts.indexOf(c) + '] ... ' + c);
            }
        }
    }
//    @IsTest
//    static void testLeadLoadSplits() {
//        List<Lead> leads = [SELECT Id FROM Lead WHERE Name_of_Lead_Source__c = 'AniAssignerTest'];
//        Integer expectedLoads = (leads.size() + 199) / defaultLoadSize;
//        Integer expectedRemainder = defaultLoadSize - ((defaultLoadSize * expectedLoads) - leads.size());
//        System.debug('expectedLoads = ' + expectedLoads);
//
//        System.assertEquals(((leads.size() + (defaultLoadSize - 1)) / defaultLoadSize), leadLoads.size(), 'number of loads');
//        System.assertEquals(expectedLoads, leadLoads.size(), (expectedLoads - 1).toString() + ' full loads and 1 partial)');
//        for (List<Lead> load : leadLoads) {
//            if (leadLoads.indexOf(load) < (expectedLoads - 1)) {
//                System.assertEquals(defaultLoadSize, load.size(), 'expecting FULL BATCH');
//            } else {
//                System.assertEquals(expectedRemainder, load.size(), 'last Batch should be a remainder(unless leads.size() is multiple of defaultLoadSize)');
//            }
//        }
//    }
    @IsTest
    static void testLoadSplits() {
        List<Lead> leads = [SELECT Id FROM Lead WHERE Name_of_Lead_Source__c = 'AniAssignerTest'];
        List<Contact> contacts = [SELECT Id FROM Contact WHERE MobilePhone LIKE '777777%'];
        Integer expectedLoads = (contacts.size() + 199) / defaultLoadSize;
        Integer expectedRemainder = Math.mod(contacts.size()+defaultLoadSize,defaultLoadSize);
        System.debug('expectedLoads = ' + expectedLoads);
        List<List<Contact>> contactLoads = AniAssigner.contactLoadSplits(contacts);
        List<List<Lead>> leadLoads = AniAssigner.leadLoadSplits(leads);
        System.assertEquals(((contacts.size() + (defaultLoadSize - 1)) / defaultLoadSize), contactLoads.size(), 'number of loads');
        System.assertEquals(expectedLoads, contactLoads.size(), (expectedLoads - 1).toString() + ' full loads and 1 partial)');
        for (List<Lead> load : leadLoads) {
            if (leadLoads.indexOf(load) < (expectedLoads - 1)) {
                System.assertEquals(defaultLoadSize, load.size(), 'full Batch of '+leadLoads.size()+' ... from '+load.size()+' leads');
            } else {
                System.assertEquals(expectedRemainder, load.size(), 'last Batch of '+leadLoads.size()+' ... from '+load.size()+' leads');
            }
        }
        for (List<Contact> load : contactLoads) {
            if (contactLoads.indexOf(load) < (expectedLoads - 1)) {
                System.assertEquals(defaultLoadSize, load.size(), 'full Batch of '+contactLoads.size()+' ... from '+load.size()+' contacts');
            } else {
                System.assertEquals(expectedRemainder, load.size(), 'last Batch of '+contactLoads.size()+' ... from '+load.size()+' contacts');
            }
        }
    }

    @IsTest
    static void testGetLeadsAndContactsByCampaignId(){

        List<Lead> leads = [SELECT Id,Street,City,State,PostalCode,MobilePhone,Phone,Secondary_Contact_Mobile__c FROM Lead WHERE Name_of_Lead_Source__c = 'AniAssignerTest'];
        List<Contact> contacts = [SELECT Id,AccountId,MailingStreet,MailingCity,MailingState,MailingPostalCode,MobilePhone,HomePhone,Phone FROM Contact WHERE MobilePhone LIKE '777777%'];
        System.debug('contacts—>'+contacts);
        List<Campaign> camps = [SELECT Id FROM Campaign WHERE Name = 'testCampaign'];
        List<Id> campIds = new List<Id>();
        for(Campaign camp : camps){
            campIds.add(camp.Id);
        }
        List<Lead> assertLeads = AniAssigner.GetLeadsByCampaignId(campIds);
        List<Contact> assertContacts = AniAssigner.GetContactsByCampaignId(campIds);
        System.assertEquals(leads,assertLeads,'leads should match campaignmember leads');
        System.assertEquals(contacts,assertContacts,'contacts should match campaignmember contacts');
    }
    @IsTest
    static void testRefreshANIs(){

        List<Campaign> camps = [SELECT Id FROM Campaign WHERE Name = 'testCampaign'];
        List<Id> campIds = new List<Id>();
        for(Campaign camp : camps){
            campIds.add(camp.Id);
        }
        Test.startTest();
        AniAssigner.RefreshANIs(campIds);
        Test.stopTest();
        List<Lead> leads = [SELECT Id,Street,City,State,PostalCode,MobilePhone,Phone,Secondary_Contact_Mobile__c FROM Lead WHERE Name_of_Lead_Source__c = 'AniAssignerTest'];
        List<Contact> contacts = [SELECT Id,MailingStreet,MailingCity,MailingState,MailingPostalCode,MobilePhone,HomePhone,Phone FROM Contact WHERE MobilePhone LIKE '777777%'];


    }
}




//Map<String,List<String>> countyCityStringsMap = new Map<String,List<String>>{
//        'Douglas, NE' => new List<String>{
//                'Bennington','Briggs','Debolt','Elk City','Elkhorn','Irvington','Omaha','Ralston','Valley','Waterloo'
//        },
//        'Lancaster, NE' => new List<String>{
//                'Agnew','Cheney','Davey','Denton','Emerald','Firth','Hallam','Hickman','Kramer','Lincoln','Malcolm','Martell','Panama','Prairie Home','Princeton','Raymond','Roca','Sprague','Walton'
//        },
//        'Gage, NE' => new List<String>{
//                'Adams','Barneston','Beatrice','Blue Springs','Clatonia','Cortland','Filley','Holmesville','Liberty','Odell','Pickrell','Virginia','Wymore'
//        },
//        'Custer, NE' => new List<String>{
//                'Anselmo','Ansley','Arnold','Berwyn','Broken Bow','Callaway','Comstock','Mason City','Merna','Oconto','Sargent','Weissert','Wescott','Westerville'
//        },
//        'Dodge, NE' => new List<String>{
//                'Ames','Centerville','Dodge','Everett','Fremont','Hooper','Inglewood','Nickerson','North Bend','Scribner','Snyder','Uehling','Winslow'
//        },
//        'Saunders, NE' => new List<String>{
//                'Ashland','Cedar Bluffs','Ceresco','Colon','Malmo','Mead','Morse Bluff','Prague','Swedeburg','Touhy','Valparaiso','Wann','Weston','Wahoo','Yutan'
//        },
//        'Madison, NE' => new List<String>{
//                'Battle Creek','Emerick','Enola','Meadow Grove','Madison','Newman Grove','Norfolk','Tilden','Warnerville'
//        },
//        'Hall, NE' => new List<String>{
//                'Alda','Cairo','Doniphan','Grand Island','Hansen','Shelton','Wood River'
//        },
//        'Buffalo, NE' => new List<String>{
//                'Amherst','Buda','Denman','Elm Creek','Gibbon','Glenwood','Kearney','Miller','Odessa','Pleasanton','Prairie Center','Ravenna','Riverdale','Shelton','Saint Michael','Sweetwater'
//        },
//        'Platte, NE' => new List<String>{
//                'Columbus','Cornlea','Creston','Duncan','Humphrey','Lakeview','Lindsay','Monroe','Newman Grove','Oconee','Platte Center','Tarnov','Rosenborg','Saint Bernard'
//        },
//        'Otoe, NE' => new List<String>{
//                'Burr','Douglas','Dunbar','Lorton','Nebraska City','Otoe','Palmyra','Paul','Syracuse','Talmage','Unadilla','Woodland Hills','Wyoming'
//        },
//        'Knox, NE' => new List<String>{
//                'Bazile Mills','Bloomfield','Center','Creighton','Crofton','Dukeville','Jelen','Knoxville','Lindy','Mars','Niobrara','Pishelville','Santee','Sparta','Venus','Walnut','Wausa','Winnetoon'
//        },
//        'Cedar, NE' => new List<String>{
//                'Aten','Bow Valley','Belden','Coleridge','Constance','Fordyce','Hartington','Laurel','Magnet','Menominee','Obert','Randolph','Saint Helena','Saint James','South Yankton','Wynot'
//        },
//        'Adams, NE' => new List<String>{
//                'Ayr','Assumption','Hansen','Hastings','Hayland','Holstein','Ingleside','Juniata','Kenesaw','Pauline','Prosser','Roseland','Trumbull'
//        },
//        'Lincoln, NE' => new List<String>{
//                'Brady','Bignell','Birdwood','Dickens','Hershey','Maxwell','North Platte','O\'Fallons','Somerset','Sutherland','Vroman','Wallace','Wellfleet'
//        },
//        'Seward, NE' => new List<String>{
//                'Beaver Crossing','Bee','Cordova','Garland','Goehner','Grover','Milford','Pleasant Dale','Ruby','Seward','Staplehurst','Tamora','Utica'
//        },
//        'York, NE' => new List<String>{
//                'Arborville','Benedict','Bradshaw','Gresham','Henderson','Houston','Lushton','McCool Junction','Thayer','Waco','York'
//        },
//        'Dawson, NE' => new List<String>{
//                'Buffalo','Cozad','Darr','Eddyville','Farnam','Gothenburg','Josselyn','Lexington','Overton','Sumner','Willow Island'
//        },
//        'Richardson, NE' => new List<String>{
//                'Barada','Dawson','Falls City','Humboldt','Nim City','Preston','Rulo','Salem','Shubert','Stella','Straussville','Verdon'
//        },
//        'Cass, NE' => new List<String>{
//                'Alvo','Avoca','Beaver Lake','Buccaneer Bay','Cedar Creek','Eagle','Elmwood','Greenwood','Lake Waconda','Louisville','Manley','Murdock','Murray','Mynard','Nehawka','Plattsmouth','South Bend','Union','Wabash','Weeping Water'
//        },
//        'Scotts Bluff, NE' => new List<String>{
//                'Bradley','Gering','Haig','Henry','Lyman','McGrew','Melbeta','Minatare','Mitchell','Morrill','Terrytown','Scottsbluff'
//        },
//        'Saline, NE' => new List<String>{
//                'Crete','De Witt','Dorchester','Friend','Pleasant Hill','Shestak','Swanton','Tobias','Western','Wilber'
//        },
//        'Boone, NE' => new List<String>{
//                'Akron','Albion','Boone','Cedar Rapids','Closter','Loretto','Petersburg','Primrose','Raeville','Saint Edward'
//        },
//        'Cuming, NE' => new List<String>{
//                'Aloys','Bancroft','Beemer','Bismarck','Monterey','West Point','Wisner'
//        },
//        'Butler, NE' => new List<String>{
//                'Abie','Bellwood','Brainard','Bruno','David City','Dwight','Edholm','Garrison','Loma','Linwood','Millerton','Nimburg','Octavia','Rising City','Surprise','Ulysses'
//        },
//        'Antelope, NE' => new List<String>{
//                'Brunswick','Clearwater','Elgin','Neligh','Oakdale','Orchard','Royal','Tilden'
//        },
//        'Wayne, NE' => new List<String>{
//                'Altona','Carroll','Hoskins','Sholes','Wakefield','Wayne','Winside'
//        },
//        'Hamilton, NE' => new List<String>{
//                'Aurora','Giltner','Hampton','Hordville','Marquette','Overland','Phillips','Stockham'
//        },
//        'Washington, NE' => new List<String>{
//                'Arlington','Blair','De Soto','Fontanelle','Fort Calhoun','Herman','Kennard','Nashville','Orum','Spiker','Telbasta','Washington'
//        },
//        'Clay, NE' => new List<String>{
//                'Clay Center','Deweese','Edgar','Eldorado','Fairfield','Glenvil','Harvard','Inland','Ong','Saronville','Sutton','Trumbull','Verona'
//        },
//        'Burt, NE' => new List<String>{
//                'Arizona','Bertha','Craig','Decatur','Lyons','Oakland','Tekamah'
//        },
//        'Thayer, NE' => new List<String>{
//                'Alexandria','Belvidere','Bruning','Byron','Carleton','Chester','Davenport','Deshler','Gilead','Hebron','Hubbell'
//        },
//        'Jefferson, NE' => new List<String>{
//                'Daykin','Diller','Endicott','Fairbury','Gladstone','Harbine','Helvey','Jansen','Plymouth','Powell','Reynolds','Steele City','Thompson'
//        },
//        'Fillmore, NE' => new List<String>{
//                'Burress','Carlisle','Exeter','Fairmont','Geneva','Grafton','Martland','Milligan','Ohiowa','Shickley','Strang'
//        },
//        'Dixon, NE' => new List<String>{
//                'Allen','Concord','Dixon','Emerson','Lime Grove','Martinsburg','Maskell','Newcastle','Ponca','Wakefield','Waterbury'
//        },
//        'Holt, NE' => new List<String>{
//                'Amelia','Anncar','Atkinson','Catalpa','Chambers','Deloit','Dorsey','Dustin','Emmet','Ewing','Inez','Inman','Meek','O\'Neill','Opportunity','Paddock','Page','Redbird','Stafford','Star','Stuart'
//        },
//        'Phelps, NE' => new List<String>{
//                'Atlanta','Bertrand','Clyde','Funk','Holdrege','Loomis','Sacramento','Westmark'
//        },
//        'Furnas, NE' => new List<String>{
//                'Arapahoe','Beaver City','Cambridge','Edison','Hendley','Holbrook','Hollinger','Oxford','Precept','Wilsonville'
//        },
//        'Cheyenne, NE' => new List<String>{
//                'Brownson','Colton','Dalton','Gurley','Huntsman','Lodgepole','Lorenzo','Potter','Sidney','Sunol'
//        },
//        'Pierce, NE' => new List<String>{
//                'Breslau','Foster','Hadar','McLean','Osmond','Pierce','Plainview','Wee Town'
//        },
//        'Polk, NE' => new List<String>{
//                'Durant','Osceola','Polk','Shelby','Stromsburg','Swedehome'
//        },
//        'Nuckolls, NE' => new List<String>{
//                'Angus','Bostwick','Cadams','Hardy','Lawrence','Mount Clare','Nelson','Nora','Oak','Ruskin','Saint Stephens','Sedan','Smyrna','Superior'
//        },
//        'Colfax, NE' => new List<String>{
//                'Clarkson','Heun','Howells','Leigh','Olean', 'Richland','Rogers','Schuyler'
//        },
//        'Nemaha, NE' => new List<String>{
//                'Auburn','Brock','Brownville','Glenrock','Howe','Johnson','Julian','Nemaha','Peru','Rohrs'
//        },
//        'Webster, NE' => new List<String>{
//                'Amboy','Bladen','Blue Hill','Cowles','Guide Rock','Inavale','Red Cloud','Rosemont'
//        },
//        'Merrick, NE' => new List<String>{
//                'Archer','Central City','Chapman','Clarks','Havens','Lockwood','Palmer','Silver Creek','Worms'
//        },
//        'Valley, NE' => new List<String>{
//                'Arcadia','Elyria','North Loup','Olean','Ord','Sumter'
//        },
//        'Red Willow, NE' => new List<String>{
//                'Bartley','Danbury','Indianola','Lebanon','Marion','McCook','Perry','Shippee'
//        },
//        'Howard, NE' => new List<String>{
//                'Cotesfield','Cushing','Dannevirke','Dannebrog','Elba','Farwell','Howard City','Nysted','Saint Libory','Saint Paul','Wolbach'
//        },
//        'Franklin, NE' => new List<String>{
//                'Bloomington','Campbell','Franklin','Hildreth','Macon','Naponee','Riverton','Upland'
//        },
//        'Harlan, NE' => new List<String>{
//                'Alma','Huntley','Mascot','Orleans','Oxford','Ragan','Republican City','Stamford'
//        },
//        'Kearney, NE' => new List<String>{
//                'Axtell','Heartwell','Keene','Lowell','Minden','Newark','Norman','Wilcox'
//        },
//        'Stanton, NE' => new List<String>{
//                'Pilger','Stanton','Woodland Park'
//        },
//        'Pawnee, NE' => new List<String>{
//                'Bookwalter','Burchard','Du Bois','Lewiston','Mayberry','Pawnee City','Steinauer','Table Rock'
//        },
//        'Thurston, NE' => new List<String>{
//                'Emerson','Macy','Pender','Rosalie','Thurston','Walthill','Winnebago'
//        },
//        'Sherman, NE' => new List<String>{
//                'Ashton','Hazard','Litchfield','Loup City','Rockville'
//        },
//        'Johnson, NE' => new List<String>{
//                'Cook','Crab Orchard','Elk Creek','Saint Mary','Sterling','Tecumseh','Vesta'
//        },
//        'Nance, NE' => new List<String>{
//                'Belgrade','Fullerton','Genoa','Krakow','Merchiston'
//        },
//        'Sarpy, NE' => new List<String>{
//                'Avery','Beacon View','Bellevue','Chalco','Gilmore','Gretna','La Platte','La Vista','Linoma Beach','Offutt AFB','Meadow','Melia','Papillion','Richfield','Springfield'
//        },
//        'Frontier, NE' => new List<String>{
//                'Curtis','Eustis','Freedom','Maywood','Moorefield','Orafino','Quick','Stockville'
//        },
//        'Sheridan, NE' => new List<String>{
//                'Antioch','Bingham','Clinton','Ellsworth','Gordon','Hay Springs','Hoffland','Lakeside','Rushville','Whiteclay'
//        },
//        'Greeley, NE' => new List<String>{
//                'Belfast','Brayton','Greeley Center','Horace','O\'Connor','Scotia','Spalding','Wolbach'
//        },
//        'Boyd, NE' => new List<String>{
//                'Anoka','Bristow','Butte','Gross','Lynch','Monowi','Naper','Spencer'
//        },
//        'Morrill, NE' => new List<String>{
//                'Angora','Atkins','Bayard','Bonner','Bridgeport','Broadwater','Lynn','Northport','Redington','Vance'
//        },
//        'Box Butte, NE' => new List<String>{
//                'Alliance','Berea','Hemingford','Letan','Nonpareil'
//        },
//        'Cherry, NE' => new List<String>{
//                'Brownlee','Cascade','Cody','Crookston','Eli','Elsmere','Kilgore','Merriman','Nenzel','Wood Lake','Sparks','Thatcher','Valentine'
//        },
//        'Hitchcock, NE' => new List<String>{
//                'Culbertson','Palisade','Stratton','Trenton'
//        },
//        'Keith, NE' => new List<String>{
//                'Belmar','Brule','Keystone','Lemoyne','Martin','Nevens','Ogallala','Paxton','Roscoe','Ruthton','Sarben'
//        },
//        'Dawes, NE' => new List<String>{
//                'Bordeaux','Chadron','Crawford','Horn','Marsland','Pine Ridge','Whitney'
//        },
//        'Dakota, NE' => new List<String>{
//                'Dakota City','Emerson','Goodwin','Homer','Hubbard','Jackson','Nacora','South Sioux City','Willis'
//        },
//        'Kimball, NE' => new List<String>{
//                'Bushnell','Dix','Jacinto','Kimball','Oliver','Owasco'
//        },
//        'Chase, NE' => new List<String>{
//                'Champion','Enders','Imperial','Lamar','Wauneta'
//        },
//        'Gosper, NE' => new List<String>{
//                'Elwood','Smithfield','Johnson Lake'
//        },
//        'Perkins, NE' => new List<String>{
//                'Brandon','Elsie','Grainton','Grant','Madrid','Venango'
//        },
//        'Brown, NE' => new List<String>{
//                'Ainsworth','Johnstown','Koshopah','Long Pine','Raven'
//        },
//        'Dundy, NE' => new List<String>{
//                'Benkelman','Haigler','Lamont','Max','Ough','Parks','Sanborn'
//        },
//        'Garden, NE' => new List<String>{
//                'Lewellen','Lisco','Mumper','Oshkosh','Rackett'
//        },
//        'Deuel, NE' => new List<String>{
//                'Barton','Big Springs','Chappell'
//        },
//        'Hayes, NE' => new List<String>{
//                'Hamlet','Hayes Center','Marengo','Palisade'
//        },
//        'Sioux, NE' => new List<String>{
//                'Agate','Andrews','Glen','Harrison','Joder','Orella','Story'
//        },
//        'Rock, NE' => new List<String>{
//                'Bassett','Duff','Mariaville','Newport','Rose','Sybrant'
//        },
//        'Keya Paha, NE' => new List<String>{
//                'Burton','Jamison','Meadville','Mills','Norden','Riverview','Springview'
//        },
//        'Garfield, NE' => new List<String>{
//                'Burwell','Deverre','Gables'
//        },
//        'Wheeler, NE' => new List<String>{
//                'Bartlett','Cumminsville','Ericson'
//        },
//        'Banner, NE' => new List<String>{
//                'Harrisburg'
//        },
//        'Blaine, NE' => new List<String>{
//                'Brewster','Dunning','Halsey','Linscott','Purdum'
//        },
//        'Logan, NE' => new List<String>{
//                'Gandy','Hoagland','Logan','Stapleton'
//        },
//        'Loup, NE' => new List<String>{
//                'Almeria','Taylor'
//        },
//        'Thomas, NE' => new List<String>{
//                'Halsey','Natick','Norway','Seneca','Thedford'
//        },
//        'McPherson, NE' => new List<String>{
//                'Ringgold','Tryon'
//        },
//        'Arthur, NE' => new List<String>{
//                'Arthur','Bucktail','Calora','Lena','Velma'
//        },
//        'Grant, NE' => new List<String>{
//                'Ashby','Hyannis','Whitman'
//        },
//        'Hooker, NE' => new List<String>{
//                'Mullen'
//        }
//};