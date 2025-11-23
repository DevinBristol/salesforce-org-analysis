/**
 * Created by noahr on 6/21/2024.
 */

public with sharing class OpportunityPageController{
    @AuraEnabled(Cacheable=false)
    public static void ChangeStatusBuffer(String newStatus, String oppId, String reasonOne, String reasonTwo){
        OpportunityPageService.ChangeStatus(newStatus,oppId, reasonOne, reasonTwo);
    }
    @AuraEnabled(Cacheable=false)
    public static void CreateCallbackBuffer(Datetime followUpDate, String sDescription, String accountId,Id userId,Boolean isUnreachable){
        OpportunityPageService.CreateCallback(followUpDate,sDescription,accountId,userId,isUnreachable);
    }
    @AuraEnabled(Cacheable=false)
    public static void WorkOrderCreationBuffer(Datetime workDate, String sOwnerId, String oppId, String workTypeId, String sAccountId) {
        OpportunityPageService.WorkOrderCreation(workDate, sOwnerId, oppId, workTypeId, sAccountId);
    }
}