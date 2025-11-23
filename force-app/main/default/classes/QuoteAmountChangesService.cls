/**
 * Created by noahr on 7/12/2024.
 */

public with sharing class QuoteAmountChangesService {
    public static List<QuoteLineItem> GetLineItems(String oppId){
        List<QuoteLineItem> quoteItems = [SELECT Product2.Name,Id,Quantity,TotalPrice,UnitPrice FROM QuoteLineItem WHERE Quote.Opportunity.Id = :oppId AND Quote.IsSyncing = TRUE ];

        for(QuoteLineItem qli : quoteItems){
            qli.Product_Name__c = qli.Product2.Name;
        }

        update quoteItems;

        return quoteItems;
    }

    public static List<Quote> GetLinkedQuotes(String oppId){
        return [SELECT Id, Name FROM Quote WHERE OpportunityId = :oppId];
    }

    public static void CreateNewQuote(String oppId, String productItemId, Integer numberOfItems){
        PricebookEntry prodEntry = [SELECT UnitPrice,Id FROM PricebookEntry WHERE Product2Id = :productItemId];
        Pricebook2 pb = new Pricebook2(
                Id = '01sHs000003Of8eIAC'
        );

        Quote newQuote = new Quote(
                OpportunityId = oppId,
                Name = 'Placeholder Quote',
                Pricebook2Id = pb.Id
        );
        insert newQuote;

        QuoteLineItem qlt = new QuoteLineItem(
                QuoteId = newQuote.Id,
                PricebookEntryId = prodEntry.Id,
                Quantity = numberOfItems,
                UnitPrice = prodEntry.UnitPrice
        );

        Opportunity secondOpp = new Opportunity(
                Id = oppId
        );

        secondOpp.SyncedQuoteId = newQuote.Id;

        update secondOpp;
        insert qlt;

    }

    public static void UpdateSyncedQuote(String oppId, String quoteId){
        Opportunity newSync = new Opportunity(
                Id = oppId,
                SyncedQuoteId = quoteId
        );

        update newSync;
    }

    public static void AddLineItems(String product2Id, String oppId, Integer numberOfItems){
        Opportunity opp = [SELECT SyncedQuoteId FROM Opportunity WHERE Id = :oppId];
        PricebookEntry prodEntry = [SELECT UnitPrice,Id FROM PricebookEntry WHERE Product2Id = :product2Id];
        Quote syncedQuote = [SELECT Id FROM Quote WHERE Id = :opp.SyncedQuoteId];

        QuoteLineItem qlt = new QuoteLineItem(
                QuoteId = syncedQuote.Id,
                PricebookEntryId = prodEntry.Id,
                Quantity = numberOfItems,
                UnitPrice = prodEntry.UnitPrice
        );

        insert qlt;
    }

    public static void ConvertQuoteToOrder(String quoteId, String oppId, Date effDate){

        Opportunity currOpp = [SELECT AccountId FROM Opportunity WHERE Id = :oppId];

        Order order = new Order(
                Name = 'test UNNAMED',
                Status = 'Draft',
                AccountId = currOpp.AccountId,
                EffectiveDate = effDate,
                QuoteId = quoteId,
                OpportunityId = oppId,
                Pricebook2Id = '01sHs000003Of8eIAC'
        );
        insert order;

        List<OrderItem> orderProds = new List<OrderItem>();
        List<QuoteLineItem> convQuoteItems = [SELECT Id,UnitPrice,Quantity,PricebookEntryId FROM QuoteLineItem WHERE QuoteId = :quoteId];
        for(QuoteLineItem thisItem : convQuoteItems)
        {
            OrderItem newOi = new OrderItem(
                    OrderId = order.Id,
                    UnitPrice = thisItem.UnitPrice,
                    QuoteLineItemId = thisItem.Id,
                    Quantity = thisItem.Quantity,
                    PricebookEntryId = thisItem.PricebookEntryId
            );
            orderProds.add(newOi);
        }
        insert orderProds;
    }
}