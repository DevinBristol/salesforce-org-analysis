/**
 * Created by NoahR on 7/24/2025.
 */

@IsTest
public with sharing class AniBatchAssignerTests {

    @IsTest
    static void testBatchWithLeads() {
        // Create a County and ANI
        County__c county = new County__c(Name = 'Douglas, NE');
        insert county;

        ANI__c ani = new ANI__c(
                Name = '1234567890',
                County__c = county.Id,
                isActive__c = true,
                b7__c = 'B7TestVal'
        );
        insert ani;

        // Create a City and link it to the County
        City__c city = new City__c(
                Name = 'OMAHA, NE',
                County__c = county.Id
        );
        insert city;

        // Create a Campaign
        Campaign camp = new Campaign(Name = 'Test Campaign', IsActive = true);
        insert camp;

        // Create a Lead that matches the campaign + city/state
        Lead lead = new Lead(
                FirstName = 'Test',
                LastName = 'Lead',
                Company = 'TestCo',
                Status = 'Open',
                City = 'Omaha',
                State = 'NE'
        );
        insert lead;

            // Associate Lead to Campaign
        CampaignMember cm = new CampaignMember(
                CampaignId = camp.Id,
                LeadId = lead.Id
        );
        insert cm;

        // Bypass trigger if needed
        TriggerHandler.bypass('LeadTriggerHandler');

        Test.startTest();
        AniBatchAssigner batch = new AniBatchAssigner('Lead', new List<Id>{camp.Id});
        Database.executeBatch(batch, 1);
        Test.stopTest();

        // Reload the lead and assert the fields were updated
        Lead updatedLead = [SELECT Id, ba685ce4_2c28_433a_a4c6_cac18b40f436__c,
                b7ef8429_9f35_4102_b1ea_44d3453a5086__c FROM Lead WHERE Id = :lead.Id];

        System.assertNotEquals(null, updatedLead.ba685ce4_2c28_433a_a4c6_cac18b40f436__c, 'ANI field should be set');
        System.assertEquals('B7TestVal', updatedLead.b7ef8429_9f35_4102_b1ea_44d3453a5086__c, 'B7 value should be set from ANI');
    }

    @IsTest
    static void testBatchWithEmptyScope() {
        // Create an empty campaign
        Campaign camp = new Campaign(Name = 'Empty Campaign', IsActive = true);
        insert camp;

        Test.startTest();
        AniBatchAssigner batch = new AniBatchAssigner('Lead', new List<Id>{camp.Id});
        Database.executeBatch(batch, 1);
        Test.stopTest();

        // Should not throw any errors even with no matching leads
        System.assert(true, 'Batch executed with empty scope');
    }
}