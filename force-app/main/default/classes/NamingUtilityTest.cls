/**
 * Created by brist on 7/29/2024.
 */

@IsTest
private class NamingUtilityTest {
    @TestSetup
    static void insertTestRecords() {
        List<Lead> testInsertLeads = new List<Lead>();
        List<Account> testInsertAccounts = new List<Account>();
        //Integer lastNameInt = 0;
        for (Integer i = 0; i < 8; i++) { //testdata shorthand:: ✔ = set; ✘ = null
            // primaryFirst,primaryLast,2ndaryFirst,2ndaryLast
            if (i == 0) {//✔✔✔✔
                Lead l = new Lead(Name_of_Lead_Source__c = 'TestCrap', Company = '.', FirstName = i.toString(), LastName = i.toString(), SecondaryContactFirstName__c = i.toString(), Secondary_Contact_Last_Name__c = i.toString());
                testInsertLeads.add(l);
            } else if (i == 1) {//✔✔✔✘
                Lead l = new Lead(Name_of_Lead_Source__c = 'TestCrap', Company = '.', FirstName = i.toString(), LastName = i.toString(), SecondaryContactFirstName__c = i.toString());
                testInsertLeads.add(l);
            } else if (i == 2) {//✔✔✘✔
                Lead l = new Lead(Name_of_Lead_Source__c = 'TestCrap', Company = '.', FirstName = i.toString(), LastName = i.toString(), Secondary_Contact_Last_Name__c = i.toString());
                testInsertLeads.add(l);
            } else if (i == 3) {//✘✔✔✔
                Lead l = new Lead(Name_of_Lead_Source__c = 'TestCrap', Company = '.', LastName = i.toString(), SecondaryContactFirstName__c = i.toString(), Secondary_Contact_Last_Name__c = i.toString());
                testInsertLeads.add(l);
            } else if (i == 4) {//✔✔✘✘
                Lead l = new Lead(Name_of_Lead_Source__c = 'TestCrap', Company = '.', FirstName = i.toString(), LastName = i.toString());
                testInsertLeads.add(l);
            } else if (i == 5) {//✘✔✔✘
                Lead l = new Lead(Name_of_Lead_Source__c = 'TestCrap', Company = '.', LastName = i.toString(), SecondaryContactFirstName__c = i.toString());
                testInsertLeads.add(l);
            } else if (i == 6) {//✘✔✘✔
                Lead l = new Lead(Name_of_Lead_Source__c = 'TestCrap', Company = '.', LastName = i.toString(), Secondary_Contact_Last_Name__c = i.toString());
                testInsertLeads.add(l);
            } else if (i == 7) {//✘✔✘✘
                Lead l = new Lead(Name_of_Lead_Source__c = 'TestCrap', Company = '.', LastName = i.toString());
                testInsertLeads.add(l);
            }
        }
        insert testInsertLeads;

        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 4; i++) {
            Account a = new Account(Name = i.toString(), BillingStreet = i.toString() + ' Testing Street', BillingCity = 'Lincoln', BillingState = 'NE', BillingPostalCode = '68504',Name_of_Lead_Source__c='TestCrap');
            testAccounts.add(a);
        }
        insert testAccounts;

        List<Contact> testContacts = new List<Contact>();
        for (Integer i = 0; i < 4; i++) {
            if (i == 0) {
                Contact contact1 = new Contact(FirstName = 'One', LastName = 'Test' + i.toString(), AccountId = testAccounts[i].Id);
                Contact contact2 = new Contact(FirstName = 'Two', LastName = 'Test' + i.toString(), AccountId = testAccounts[i].Id);
                Contact contact3 = new Contact(FirstName = 'Three', LastName = 'Test' + i.toString(), AccountId = testAccounts[i].Id);
                Contact contact4 = new Contact(FirstName = 'Four', LastName = 'Test' + i.toString(), AccountId=testAccounts[i].Id );
                testContacts.add(contact1);
                testContacts.add(contact2);
                testContacts.add(contact3);
            }
            if (i == 1) {
                Contact contact1 = new Contact(FirstName = 'One', LastName = 'Test' + i.toString(), AccountId = testAccounts[i].Id);
                Contact contact2 = new Contact(FirstName = 'Two', LastName = 'Test' + i.toString(), AccountId = testAccounts[i].Id);
                testContacts.add(contact1);
                testContacts.add(contact2);
            }
            if (i == 2) {
                Contact contact1 = new Contact(FirstName = 'One', LastName = 'Test' + i.toString(), AccountId = testAccounts[i].Id);
                testContacts.add(contact1);
            }
            if (i == 3) {
                Contact contact4 = new Contact(FirstName = 'One', LastName = 'Test' + i.toString(), AccountId = testAccounts[i].Id);
                testContacts.add(contact4);
            }
        }
        insert testContacts;

        List<Property__c> testProperties = new List<Property__c>();
        for (Integer i = 0; i < 3; i++) {
            Property__c p = new Property__c(Address__Street__s = i.toString() + ' Testing Street',
                    Address__City__s = 'Lincoln',
                    Address__StateCode__s = 'NE',
                    Address__PostalCode__s = '68504',
                    AccountId__c = testAccounts[i].Id);
            testProperties.add(p);
        }
        insert testProperties;

        List<Opportunity> testOpportunities = new List<Opportunity>();
        for (Integer i = 0; i < 4; i++) {
            if(i<3){Opportunity o = new Opportunity(Name = testAccounts[i].Name+' Opportunity'+i.toString(), AccountId = testAccounts[i].Id, Opportunity_Property__c = testProperties[i].Id, StageName = '(Re)Setting',CloseDate = Date.today().addDays(i));
                testOpportunities.add(o);}
            else{Opportunity o = new Opportunity(Name = testAccounts[i].Name+' Opportunity'+i.toString(), AccountId = testAccounts[i].Id, StageName = '(Re)Setting',CloseDate = Date.today().addDays(i));
                testOpportunities.add(o);}

        }
        insert testOpportunities;

//        WorkType salesDemo = [SELECT Id FROM WorkType WHERE Id = '08qHs000000kgPPIAY' LIMIT 1];
        List<WorkOrder> testWorkOrders = new List<WorkOrder>();
        for (Integer i = 0; i < 4; i++){
            WorkOrder wo = new WorkOrder(Street = i.toString() + ' Testing Street', City = 'Lincoln', State = 'NE', PostalCode = '68504',AccountId = testAccounts[i].Id);
            testWorkOrders.add(wo);
        }
        insert testWorkOrders;

        List<ServiceAppointment> testSvcAppts = new List<ServiceAppointment>();
        for (Integer i = 0; i < 4; i++){
            ServiceAppointment sa = new ServiceAppointment(Street = testWorkOrders[i].Street,
                    City = testWorkOrders[i].City, State = testWorkOrders[i].State, PostalCode = testWorkOrders[i].PostalCode, ParentRecordId = testWorkOrders[i].Id,
                    DueDate = System.now().addDays(i+10));
            testSvcAppts.add(sa);
        }
        insert testSvcAppts;
    }
    @IsTest
    static void testNameLeadCompany() {
        List<Lead> testLeads = [SELECT Id, Name_of_Lead_Source__c, Company, FirstName, LastName, SecondaryContactFirstName__c, Secondary_Contact_Last_Name__c
        FROM Lead WHERE Name_of_Lead_Source__c = 'TestCrap'];
        for(Integer i = 0; i < 8; i++){
            System.debug(testLeads[i]);
            if(i==0){System.assertEquals('0 0 & 0 0',testLeads[i].Company);}
            else if(i==1){System.assertEquals('1 1 & 1 1',testLeads[i].Company);}
            else if(i==2){System.assertEquals('2 2 & [not provided] 2',testLeads[i].Company);}
            if(i==3){System.assertEquals('3 3 & [not provided] 3',testLeads[i].Company);}
            if(i==4){System.assertEquals('4 4',testLeads[i].Company);}
            if(i==5){System.assertEquals('5 5 & [not provided] 5',testLeads[i].Company);}
            if(i==6){System.assertEquals('[not provided] 6 & [not provided] 6',testLeads[i].Company);}
            if(i==7){System.assertEquals('[not provided] 7',testLeads[i].Company);}
        }
    }
    @IsTest
    static void testNameLeadCompanyOnUpdate() {
        Lead testLead0 = [
                SELECT Id, Name_of_Lead_Source__c, Company, FirstName, LastName, SecondaryContactFirstName__c, Secondary_Contact_Last_Name__c
                FROM Lead
                WHERE Company = '0 0 & 0 0'
                LIMIT 1
        ];
        Lead updateLead = testLead0;
        updateLead.FirstName = 'updtdFirst';
        update updateLead;
        Lead updatedLead = [SELECT Id, Name_of_Lead_Source__c, Company, FirstName, LastName, SecondaryContactFirstName__c, Secondary_Contact_Last_Name__c
        FROM Lead
        WHERE Name_of_Lead_Source__c = 'TestCrap' AND LastName = '0'
        LIMIT 1
        ];
        System.debug('Updated Company::: ' + updatedLead.Company);
        System.assertEquals('0 0 & updtdFirst 0', updatedLead.Company);
    }
    @IsTest
    static void testNameProperty(){
        List<Account> testAccounts = [SELECT Id, Name_of_Lead_Source__c, Name, BillingStreet, BillingState, BillingCity, BillingPostalCode
                                      FROM Account WHERE Name_of_Lead_Source__c = 'TestCrap'];
        List<Id> testAccountIds = new List<Id>();
        for(Account a : testAccounts){
            testAccountIds.add(a.Id);
        }
        List<Property__c> testProperties = [SELECT Id, Name, Address__Street__s, Address__City__s, Address__StateCode__s, Address__PostalCode__s
                                            FROM Property__c WHERE AccountId__c IN :testAccountIds];
        System.debug('oldProperties::-> '+testProperties);
        testProperties = NamingUtility.NameProperty(testProperties);
        for(Integer i = 0 ; i < 3; i++){
        System.debug('newProperties::-> '+testProperties);
        System.assertEquals(i+' '+'Testing Street Lincoln, NE',testProperties[i].Name);
        }
    }
    @IsTest
    static void testNameAccount() {
        List<Account> testAccounts = [SELECT Id, Name, (SELECT Id, FirstName, LastName FROM Contacts) FROM Account WHERE Name_of_Lead_Source__c = 'TestCrap'];
        testAccounts = NamingUtility.NameAccount(testAccounts);
        for(Integer i = 0; i < 3; i++){
            System.debug(testAccounts[i].Name);
            if(i==0){System.assertEquals('One Test0 & Three Test0 & Two Test0',testAccounts[i].Name);}
            if(i==1){System.assertEquals('One Test1 & Two Test1',testAccounts[i].Name);}
            if(i==2){System.assertEquals('One Test2',testAccounts[i].Name);}
        }
    }
    @IsTest
    static void testNameOpportunity() {
        List<Account> testAccounts = [SELECT Id, Name FROM Account WHERE Name_of_Lead_Source__c = 'TestCrap'];
        List<Opportunity> testOpptiesP = [SELECT Id, Name, AccountId, Opportunity_Property__c, CloseDate FROM Opportunity WHERE AccountId IN :testAccounts ORDER BY CloseDate ASC NULLS FIRST];
        List<Property__c> testProperties = [SELECT Id, Name FROM Property__c WHERE AccountId__c IN :testAccounts];
        Opportunity testOpptyNullCD = testOpptiesP[0];
        testOpptyNullCD.CloseDate = null;
        testOpptiesP.remove(0);
        List<Opportunity> testOppties = new List<Opportunity>();
        testOppties.add(testOpptyNullCD);
        testOppties.addAll(testOpptiesP);
        testOppties = NamingUtility.NameOpportunity(testOppties);
        for(Integer i = 0; i < testOppties.size(); i++){
            System.debug(testOppties[i].Name);
            if(i==0){
                System.assertEquals(testAccounts[i].Name+' – '+testProperties[i].Name+' – '+'[not provided]',testOppties[i].Name);
            } else if(i<3){
                System.assertEquals(testAccounts[i].Name+' – '+testProperties[i].Name+' – '+Date.today().addDays(i).format(),testOppties[i].Name);
            }
            else{
                System.assertEquals(testAccounts[i].Name+' – '+'[not provided]'+' – '+Date.today().addDays(i).format(), testOppties[i].Name);
            }
        }
    }
//    @IsTest
//    static void testStandardizePropertyNameFromAddress(){
//        String np = '[not provided]';
//        String street = '123 O Street';
//        String city = 'Hog City';
//        String stateC = 'NE';
//        String postalCode = '13481';
//        String no;
//        String nameFull = street+' '+city+', '+stateC;
//        String nameNoStr = np+' '+city+', '+stateC;
//        String nameNoCity = street+' '+np+', '+stateC;
//        String nameNoState = street+' '+city+', '+np;
//        String nameNoStrNoCity = np+' '+np+', '+stateC;
//        String nameNoStrNoState = np+' '+city+', '+np;
//        String nameNoCityNoState = street+' '+np+', '+np;
//        String nameNothing = np+' '+np+', '+np;
//        System.assertEquals(nameFull,NamingUtility.StandardizePropertyNameFromAddresses(street,city,stateC,postalCode));//full
//        System.assertEquals(nameNoStr,NamingUtility.StandardizePropertyNameFromAddresses(no,city,stateC,postalCode));      //noStr
//        System.assertEquals(nameNoCity,NamingUtility.StandardizePropertyNameFromAddresses(street,no,stateC,postalCode));      //noCity
//        System.assertEquals(nameNoState,NamingUtility.StandardizePropertyNameFromAddresses(street,city,no,postalCode));//noState
//        System.assertEquals(nameNoStrNoCity,NamingUtility.StandardizePropertyNameFromAddresses(no,no,stateC,postalCode));//noStr noCity
//        System.assertEquals(nameNoStrNoState,NamingUtility.StandardizePropertyNameFromAddresses(no,city,no,postalCode));//noStr noState
//        System.assertEquals(nameNoCityNoState,NamingUtility.StandardizePropertyNameFromAddresses(street,no,no,postalCode));//NoCity NoState
//        System.assertEquals(nameNothing,NamingUtility.StandardizePropertyNameFromAddresses(no,no,no,postalCode));
//        List<String> testStates = new List<String>();
//        String state;
//        List<String> states = new List<String>{'NE','IA','SD','KS','MO','CO','WY','MN'};
//        for (Integer i = 0; i < 8; i++){
//            nameFull = street+' '+city+', '+states[i];
//            if(i==0){
//                stateC='Nebraska';
//                System.assertEquals(nameFull,NamingUtility.StandardizePropertyNameFromAddresses(street,city,stateC,postalCode));
//            } else if(i==1){
//                stateC='Iowa';//ia
//                System.assertEquals(nameFull,NamingUtility.StandardizePropertyNameFromAddresses(street,city,stateC,postalCode));
//            } else if(i==2){
//                stateC='South Dakota';//sd
//                System.assertEquals(nameFull,NamingUtility.StandardizePropertyNameFromAddresses(street,city,stateC,postalCode));
//            } else if(i==3){
//                stateC='Kansas';//ks
//                System.assertEquals(nameFull,NamingUtility.StandardizePropertyNameFromAddresses(street,city,stateC,postalCode));
//            } else if(i==4){
//                stateC= 'Missouri';//mo
//                System.assertEquals(nameFull,NamingUtility.StandardizePropertyNameFromAddresses(street,city,stateC,postalCode));
//            } else if(i==5){
//                stateC= 'Colorado';//co
//                System.assertEquals(nameFull,NamingUtility.StandardizePropertyNameFromAddresses(street,city,stateC,postalCode));
//            } else if(i==6){
//                stateC= 'Wyoming';//wy
//                System.assertEquals(nameFull,NamingUtility.StandardizePropertyNameFromAddresses(street,city,stateC,postalCode));
//            }else if(i==7){
//                stateC= 'Minnesota';//mn
//                System.assertEquals(nameFull,NamingUtility.StandardizePropertyNameFromAddresses(street,city,stateC,postalCode));
//            }
//        }
//
//
//        Integer i = 0;
//        for(String testState : testStates) {
//            if(i==0){
//
//            }else if(i==1){
//                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
//                System.assertEquals('123 O Street Hog City, IA',propertyName);
//            }else if(i==2){
//                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
//                System.assertEquals('123 O Street Hog City, SD',propertyName);
//            }else if(i==3){
//                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
//                System.assertEquals('123 O Street Hog City, KS',propertyName);
//            }else if(i==4){
//                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
//                System.assertEquals('123 O Street Hog City, MO',propertyName);
//            }else if(i==5){
//                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
//                System.assertEquals('123 O Street Hog City, CO',propertyName);
//            }else if(i==6){
//                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
//                System.assertEquals('123 O Street Hog City, WY',propertyName);
//            }else if(i==7){
//                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
//                System.assertEquals('123 O Street Hog City, MN',propertyName);
//            }else{
//                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
//                System.assertEquals('123 O Street Hog City, [not provided]',propertyName);
//            }
//            i++;
//        }
//    }
    @IsTest
    static void TestStandardizePropertyName(){
        String testZip;
        List<Property__c> testProps = new List<Property__c>();
        for (Integer i = 0; i < 8; i++){
            if(i==0){
                testZip='69000';//ne
            } else if(i==1){
                testZip='52800';//ia
            } else if(i==2){
                testZip='57700';//sd
            } else if(i==3){
                testZip='67900';//ks
            } else if(i==4){
                testZip= '65800';//mo
            } else if(i==5){
                testZip= '81600';//co
            } else if(i==6){
                testZip= '83400';//wy
            }else if(i==7){
                testZip= '56700';//mn
            }
            Property__c p = new Property__c(Name = '.',Address__Street__s = '123 O Street',Address__City__s = 'Hog City',Address__PostalCode__s = testZip);
            testProps.add(p);
        }
        Integer i = 0;
        for(Property__c p : testProps) {
            String stateCode = NamingUtility.StandardizePropertyName(p);
            if(i==0){
                System.assertEquals('123 O Street Hog City, NE',stateCode);
            }else if(i==1){
                System.assertEquals('123 O Street Hog City, IA',stateCode);
            }else if(i==2){
                System.assertEquals('123 O Street Hog City, SD',stateCode);
            }else if(i==3){
                System.assertEquals('123 O Street Hog City, KS',stateCode);
            }else if(i==4){
                System.assertEquals('123 O Street Hog City, MO',stateCode);
            }else if(i==5){
                System.assertEquals('123 O Street Hog City, CO',stateCode);
            }else if(i==6){
                System.assertEquals('123 O Street Hog City, WY',stateCode);
            }else if(i==7){
                System.assertEquals('123 O Street Hog City, MN',stateCode);
            }
            i++;
        }
    }
    @IsTest
    static void testStandardizePropertyNameFromAddress(){
        List<String> testStates = new List<String>();
        String testState;

        for (Integer i = 0; i < 8; i++){
            if(i==0){
                testState='Nebraska';//ne
            } else if(i==1){
                testState='Iowa';//ia
            } else if(i==2){
                testState='South Dakota';//sd
            } else if(i==3){
                testState='Kansas';//ks
            } else if(i==4){
                testState= 'Missouri';//mo
            } else if(i==5){
                testState= 'Colorado';//co
            } else if(i==6){
                testState= 'Wyoming';//wy
            }else if(i==7){
                testState= 'Minnesota';//mn
            }
        }
        String street = '123 O Street';
        String city = 'Hog City';
        String postalCode = '13481';

        Integer i = 0;
        for(String state : testStates) {
            if(i==0){
                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
                System.assertEquals('123 O Street Hog City, NE',propertyName);
            }else if(i==1){
                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
                System.assertEquals('123 O Street Hog City, IA',propertyName);
            }else if(i==2){
                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
                System.assertEquals('123 O Street Hog City, SD',propertyName);
            }else if(i==3){
                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
                System.assertEquals('123 O Street Hog City, KS',propertyName);
            }else if(i==4){
                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
                System.assertEquals('123 O Street Hog City, MO',propertyName);
            }else if(i==5){
                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
                System.assertEquals('123 O Street Hog City, CO',propertyName);
            }else if(i==6){
                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
                System.assertEquals('123 O Street Hog City, WY',propertyName);
            }else if(i==7){
                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
                System.assertEquals('123 O Street Hog City, MN',propertyName);
            }else{
                String propertyName = NamingUtility.StandardizePropertyNameFromAddresses(street,city,state,postalCode);
                System.assertEquals('123 O Street Hog City, [not provided]',propertyName);
            }
            i++;
        }
    }
    @IsTest
    static void testStateNameToStateCode() {
        System.assertEquals('NE', NamingUtility.StateNameToStateCode('Nebraska'), 'exp NE for Nebraska');
        System.assertEquals('IA', NamingUtility.StateNameToStateCode('Iowa'), 'exp IA for Iowa');
        System.assertEquals('SD', NamingUtility.StateNameToStateCode('South Dakota'), 'exp SD for South Dakota');
        System.assertEquals('KS', NamingUtility.StateNameToStateCode('Kansas'), 'exp KS for Kansas');
        System.assertEquals('MO', NamingUtility.StateNameToStateCode('Missouri'), 'exp MO for Missouri');
        System.assertEquals('CO', NamingUtility.StateNameToStateCode('Colorado'), 'exp CO for Colorado');
        System.assertEquals('WY', NamingUtility.StateNameToStateCode('Wyoming'), 'exp WY for Wyoming');
        System.assertEquals('MN', NamingUtility.StateNameToStateCode('Minnesota'), 'exp MN for Minnesota');
        System.assertEquals('North Dakota', NamingUtility.StateNameToStateCode('North Dakota'), 'just regurgitate the crazy shit');
        System.assertEquals(null, NamingUtility.StateNameToStateCode(null), 'expect null for null');
    }
    @IsTest
    static void testMakeTaskSubjectForLead() {
        Lead lead = new Lead(FirstName = 'number1', LastName='TestLead', Company = 'testLead', Status = 'Open', MobilePhone = '5987654321');
        insert lead;
        Id ownerId = UserInfo.getUserId();
        Task task = new Task(
                WhoId = lead.Id, Five9ANI__c = '2345678901', Five9DNIS__c = '5987654321',
                CallDisposition = 'No-answer', OwnerId = ownerId, CreatedById = ownerId
        );

//        String expectedSubject = owner.FirstName + '(' + task.Five9ANI__c + ') → ' +
//                lead.Name + '(' + task.Five9DNIS__c + '), ' + task.CallDisposition + '; ' + task.CreatedDate.format('MM/dd/yyyy hh:mm a');
        insert task;
        System.debug(NamingUtility.MakeTaskSubject(task.Id));
        Test.startTest();
        String result = NamingUtility.MakeTaskSubject(task.Id);
        Test.stopTest();
        System.assertEquals(System.UserInfo.getFirstName()+'(2345678901) → number1 TestLead(5987654321), No-answer; '+System.now().format('MM/dd/yyyy hh:mm a'),NamingUtility.MakeTaskSubject(task.Id));

        //System.assertEquals(expectedSubject, result);
    }
    @IsTest
    static void testMakeTaskSubjectForContact() {

        Contact c= new Contact(FirstName = 'number1', LastName='Testc', MobilePhone = '5987654321');
        insert c;
        Id ownerId = UserInfo.getUserId();
        Task task = new Task(
                WhoId = c.Id, Five9ANI__c = '2345678901', Five9DNIS__c = '5987654321',
                CallDisposition = 'No-answer', OwnerId = ownerId, CreatedById = ownerId
        );

//        String expectedSubject = owner.FirstName + '(' + task.Five9ANI__c + ') → ' +
//                lead.Name + '(' + task.Five9DNIS__c + '), ' + task.CallDisposition + '; ' + task.CreatedDate.format('MM/dd/yyyy hh:mm a');
        insert task;
        System.debug(NamingUtility.MakeTaskSubject(task.Id));
        Test.startTest();
        String result = NamingUtility.MakeTaskSubject(task.Id);
        Test.stopTest();
        System.assertEquals(System.UserInfo.getFirstName()+'(2345678901) → number1 Testc(5987654321), No-answer; '+System.now().format('MM/dd/yyyy hh:mm a'),NamingUtility.MakeTaskSubject(task.Id));
    }

//    @IsTest
//    static void testMakeTaskSubjectWithNullFields() {
//        Lead lead = new Lead(LastName='Test Lead Null Fields');
//        insert lead;
//        User owner = [SELECT Id, FirstName FROM User WHERE UserType = 'Standard' LIMIT 1];
//        Task task = new Task(WhoId = lead.Id, Five9Agent__c = null, Five9ANI__c = null, Five9DNIS__c = null, CallDisposition = null, OwnerId = owner.Id);
//        insert task;
//        Test.startTest();
//        String result = NamingUtility.MakeTaskSubject(task.Id);
//        Test.stopTest();
//        String expectedSubject = owner.FirstName + '([not provided]) → ' +
//                lead.Name + '([not provided]), ' +
//                '[not provided]; ' +
//                task.CreatedDate.format('MM/dd/yyyy hh:mm a');
//        System.assertEquals(expectedSubject, result);
//    }
}