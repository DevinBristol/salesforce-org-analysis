/**
 * Created by benra on 4/22/2025.
 */
@IsTest
public with sharing class AniAssignerBatchableTest {

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
                anis.addAll(new List<ANI__c>{
                        new ANI__c(Name = '5555550000', City__c = l.City + ', NE', County__c = cityNameToCountyIdMap.get(l.City + ', ' + l.State), isActive__c = true, b7__c = 'testB7-0.0'),
                        new ANI__c(Name = '5555551111', City__c = l.City + ', NE', County__c = cityNameToCountyIdMap.get(l.City + ', ' + l.State), isActive__c = true, b7__c = 'testB7-0.1'),
                        new ANI__c(Name = '5555552222', City__c = l.City + ', NE', County__c = cityNameToCountyIdMap.get(l.City + ', ' + l.State), isActive__c = true, b7__c = 'testB7-0.2'),
                        new ANI__c(Name = '5555553333', City__c = l.City + ', NE', County__c = cityNameToCountyIdMap.get(l.City + ', ' + l.State), isActive__c = true, b7__c = 'testB7-0.3')
                });
            } else if (countyCityStringsMap.get('Lancaster, NE').contains(l.City)) {
                anis.addAll(new List<ANI__c>{
                        new ANI__c(Name = '6665551111', City__c = l.City + ', NE', County__c = cityNameToCountyIdMap.get(l.City + ', ' + l.State), isActive__c = true, b7__c = 'testB7-1.0'),
                        new ANI__c(Name = '6665552222', City__c = l.City + ', NE', County__c = cityNameToCountyIdMap.get(l.City + ', ' + l.State), isActive__c = true, b7__c = 'testB7-1.1'),
                        new ANI__c(Name = '6665553333', City__c = l.City + ', NE', County__c = cityNameToCountyIdMap.get(l.City + ', ' + l.State), isActive__c = true, b7__c = 'testB7-1.2')

                });
            } else if (countyCityStringsMap.get('Gage, NE').contains(l.City)) { //this one is inactive
                anis.add(
                        new ANI__c(Name = '7775552222', City__c = l.City + ', NE', County__c = cityNameToCountyIdMap.get(l.City + ', ' + l.State), isActive__c = false, b7__c = 'testB7-2')
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

    @IsTest
    static void testProcessLeads(){
        List<Campaign>camps=[SELECT Id FROM Campaign WHERE CreatedDate=TODAY];
        List<Lead>leads=[SELECT Id,City,State,Address,ba685ce4_2c28_433a_a4c6_cac18b40f436__c,b7ef8429_9f35_4102_b1ea_44d3453a5086__c FROM Lead WHERE CreatedDate=TODAY];
        System.debug(camps);
        System.debug(leads);
        Set<Id>campIds=new Set<Id>();
        for(Campaign camp : camps){
            campIds.add(camp.Id);
        }
        AniAssignerBatchable aab=new AniAssignerBatchable(campIds);
        Test.startTest();
        List<Lead>testLeads=AniAssignerBatchable.processLeads(leads,10,aab.defaultCounty);
        Test.stopTest();
        System.debug(testLeads);
    }
}