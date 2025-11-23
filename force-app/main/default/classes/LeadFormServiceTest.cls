@IsTest
private class LeadFormServiceTest {

    @IsTest
    static void createLeadTest(){
        Campaign c = new Campaign(Name = 'TestCampaign1');
        insert c;
        LeadFormController.LeadCreationBuffer('Noah189', 'Russell189', 'companyName',
        'sStreet', 'sCity', 'USA','NE', '68526', '', 'aer@ver.net',c.Id);

        Lead lead = [SELECT Id,FirstName,LastName,MobilePhone,Email FROM Lead WHERE LastName = 'Russell189'];

        System.assertEquals('Noah189', lead.FirstName);
        System.assertEquals('Russell189', lead.LastName);
        System.assertEquals(null, lead.MobilePhone);
        System.assertEquals('aer@ver.net', lead.Email);
    }

    @IsTest
    static void createLeadTestTwo(){
        System.assertEquals(false,LeadFormHelper.CheckForAddress('asfd', 'asfdf', '','', ''));
    }

    @IsTest
    static void createContact(){
        Campaign c = new Campaign(Name = 'TestCampaign1');
        insert c;
        LeadFormController.ContactCreationBuffer('Noah1899', 'Russell1899', 'companyName',
                'sStreet', 'sCity', 'USA','NE', '68526', '', 'a34@v.net', Date.today(), '005Hs00000DCEpBIAX', true,
                'secondFirstNameTest', 'secondLastNameTest', 'a@v.net', '',true,c.Id);

        Contact aContact = [SELECT Id,FirstName,LastName,MobilePhone,Email,AccountId FROM Contact WHERE LastName = 'Russell1899'];
        Contact bContact = [SELECT Id,FirstName,LastName,MobilePhone,Email FROM Contact WHERE LastName = 'secondLastNameTest'];
        Account acc = [SELECT Call_Back_Date__c FROM Account WHERE Id = :aContact.AccountId];

        System.assertEquals('Noah1899', aContact.FirstName);
        System.assertEquals('Russell1899', aContact.LastName);
        System.assertEquals(null, aContact.MobilePhone);
        System.assertEquals('a34@v.net', aContact.Email);

        System.assertEquals('secondFirstNameTest', bContact.FirstName);
        System.assertEquals('secondLastNameTest', bContact.LastName);
        System.assertEquals(null, bContact.MobilePhone);
        System.assertEquals('a@v.net', bContact.Email);

        System.assertEquals(Date.today(), acc.Call_Back_Date__c);
    }
}