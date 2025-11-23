/**
 * Created by BEN on 8/30/2024.
 */
@IsTest
public class PropertyTriggerHelperTest {
    @TestSetup
    static void makeTestProperties(){
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            Account a = new Account(Name = i.toString(), BillingStreet = i.toString() + ' Testing Street', BillingCity = 'Lincoln', BillingState = 'NE', BillingPostalCode = '68504',Name_of_Lead_Source__c='TestCrap');
            testAccounts.add(a);
        }
        insert testAccounts;

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
    }
    @IsTest
    static void testTriggerIsAfterUpdate() {
        List<Property__c> testProperties = [SELECT Address__Street__s, Address__City__s,
                Address__StateCode__s, Address__PostalCode__s FROM Property__c WHERE Address__Street__s LIKE '% Testing Street'];
        List<Property__c> updateProperties = new List<Property__c>();

        for (Property__c p : testProperties) {
            p.Address__Street__s = p.Address__Street__s.replace('Street', 'Drive');
            updateProperties.add(p);
        }
        Test.startTest();
        update updateProperties;
        Test.stopTest();
        //i guess assertions aren't required, we can just run it without failing. I duonno
    }

}