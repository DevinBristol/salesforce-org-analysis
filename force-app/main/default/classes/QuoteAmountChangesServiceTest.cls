/**
 * Created by noahr on 8/12/2024.
 */

@IsTest(SeeAllData=true)
public with sharing class QuoteAmountChangesServiceTest {

    @IsTest
    static void QuoteProcessTest(){
        Account newAcc = new Account(
                Name = 'Placeholder'
        );
        insert newAcc;
        Opportunity newOpp = new Opportunity(
                AccountId = newAcc.Id,
                StageName = 'Nurturing',
                CloseDate = Date.today()
        );
        insert newOpp;

        //code is for a bay window
        Test.startTest();
        QuoteAmountChangesController.CreateNewQuoteBuffer(newOpp.Id,'01tHs00000AfgCzIAJ',2);
        Test.stopTest();
        Quote madeQuote = [SELECT Id,OpportunityId FROM Quote WHERE OpportunityId = :newOpp.Id];
        System.assertEquals(madeQuote.OpportunityId, newOpp.Id);

        Quote newQuote = new Quote(
                Name = 'placeholder quote',
                OpportunityId = newOpp.Id
        );
        insert newQuote;

        QuoteAmountChangesController.UpdateSyncedQuoteBuffer(newOpp.Id,newQuote.Id);
        Opportunity returnedQuote = [SELECT SyncedQuoteId FROM Opportunity WHERE Id = :newOpp.Id];

        System.assertEquals(newQuote.Id,returnedQuote.SyncedQuoteId);

        QuoteAmountChangesController.AddLineItemsBuffer('01tHs00000AfgCzIAJ',newOpp.Id,1);
        Quote testQuote = [SELECT LineItemCount FROM Quote WHERE Id = :newQuote.Id];

        System.assertEquals(1,testQuote.LineItemCount);

        List<QuoteLineItem> quoteLineItems = QuoteAmountChangesController.GetLineItemsBuffer(newOpp.Id);
        System.assertEquals(1,quoteLineItems.size());

        List<Quote> quotes = QuoteAmountChangesController.GetLinkedQuotesBuffer(newOpp.Id);
        System.assertEquals(2,quotes.size());

        QuoteAmountChangesController.ConvertQuoteToOrderBuffer(newQuote.Id,newOpp.Id,Date.today());
        Order newOrder = [SELECT Name,Status,EffectiveDate,QuoteId,OpportunityId FROM Order WHERE OpportunityId = :newOpp.Id];

        System.assertEquals('Draft', newOrder.Status);
        System.assertEquals(newQuote.Id, newOrder.QuoteId);
        System.assertEquals(newOpp.Id, newOrder.OpportunityId);
        System.assertEquals(Date.today(), newOrder.EffectiveDate);

    }
}