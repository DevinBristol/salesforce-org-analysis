/**
 * Created by noahr on 7/12/2024.
 */

public with sharing class QuoteAmountChangesController {
    @AuraEnabled(Cacheable=false)
    public static List<QuoteLineItem> GetLineItemsBuffer(String oppId){
        return QuoteAmountChangesService.GetLineItems(oppId);
    }

    @AuraEnabled(Cacheable=false)
    public static void CreateNewQuoteBuffer(String oppId, String productItemId, Integer numberOfItems){
        QuoteAmountChangesService.CreateNewQuote(oppId,productItemId,numberOfItems);
    }

    @AuraEnabled(Cacheable=false)
    public static void UpdateSyncedQuoteBuffer(String oppId, String quoteId){
        QuoteAmountChangesService.UpdateSyncedQuote(oppId,quoteId);
    }

    @AuraEnabled(Cacheable=false)
    public static void AddLineItemsBuffer(String product2Id, String oppId, Integer numberOfItems){
        QuoteAmountChangesService.AddLineItems(product2Id,oppId,numberOfItems);
    }

    @AuraEnabled(Cacheable=false)
    public static List<Quote> GetLinkedQuotesBuffer(String oppId) {
        return QuoteAmountChangesService.GetLinkedQuotes(oppId);
    }

    @AuraEnabled(Cacheable=false)
    public static void ConvertQuoteToOrderBuffer(String quoteId, String oppId, Date effDate) {
        QuoteAmountChangesService.ConvertQuoteToOrder(quoteId,oppId,effDate);
    }
}