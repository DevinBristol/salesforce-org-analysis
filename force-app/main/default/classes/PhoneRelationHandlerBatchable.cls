/**
 * Created by BENJAMIN r on 3/5/2025.
 */

global class PhoneRelationHandlerBatchable implements Database.Batchable<SObject>{
    public String queryString;

    public PhoneRelationHandlerBatchable(String filterStr){
        this.queryString='SELECT Id,Name,MobilePhone,Phone,Secondary_Contact_Mobile__c FROM Lead WHERE '+filterStr;
    }
    public PhoneRelationHandlerBatchable(String campaignName,String filterStr){
        List<CampaignMember>cmbrs=[SELECT LeadId FROM CampaignMember WHERE Campaign.Name=:campaignName AND LeadId!=NULL AND ContactId=NULL ORDER BY Campaign.Name];
        Set<Id>leadIds=new Set<Id>();
        for(CampaignMember cmbr : cmbrs){
            leadIds.add(cmbr.LeadId);
        }
        String cmbrFilter='(Id=\''+String.join(leadIds,'\' OR Id=\'')+'\')\n';
        this.queryString='SELECT Id,Name,MobilePhone,Phone,Secondary_Contact_Mobile__c FROM Lead WHERE '+cmbrFilter+' AND '+filterStr;
    }
    global Database.QueryLocator start(Database.BatchableContext bc) {
        Database.QueryLocator ql;
        System.debug('\r\r\t———QUERY—STRING—@—START——>\r'+this.queryString);
        return Database.getQueryLocator(this.queryString);
    }
    global void execute(Database.BatchableContext bc,List<Lead>scope) {
         // doing an additional dml prevents false positives or unneccesary errors
        List<Lead>updateLeads=phoneRelationHandlerPrep(scope);
        update updateLeads;
    }
    global void finish(Database.BatchableContext bc) {
    }
    public static List<Lead> phoneRelationHandlerPrep(List<Lead>scope){
        List<Lead>updateLeads=new List<Lead>();
        List<Lead>runnables=new List<Lead>();
        Set<Id>runIds=new Set<Id>();
        for(Lead l : scope){
            if((l.MobilePhone==null&&l.Phone==null&&l.Secondary_Contact_Mobile__c==null)){
                l.InitializedNumbers__c=100.00;
                updateLeads.add(l);
            } else {
                runnables.add(l);
                runIds.add(l.Id);
            }
        }
        PhoneRelationHandler.HandlePhonesFromLeads(runnables);
        updateLeads.addAll(markForInitializedNumbers(runIds));
        return updateLeads;
    }
    public static List<Lead> markForInitializedNumbers(Set<Id>scopeIds){ //all no-phonenumbered leads should be already filtered out in execute
        List<Lead>leads=[SELECT Id,MobilePhone,Phone,Secondary_Contact_Mobile__c,InitializedNumbers__c,(SELECT Id,Phonenumber__r.Name,Phonenumber__r.Incidence__c FROM Phone2LeadRelationship__r) FROM Lead WHERE Id IN:scopeIds];
        for(Lead l : leads){
            Set<String>leadNumbVals=new Set<String>{l.MobilePhone,l.Phone,l.Secondary_Contact_Mobile__c};
            leadNumbVals.remove(null);
            Decimal initializedVals=0;
            for(PhonePersonRelationship__c ppr : l.Phone2LeadRelationship__r){
                if(leadNumbVals.contains(ppr.Phonenumber__r.Name)){
                    initializedVals=initializedVals+1;
                }
            }
            l.InitializedNumbers__c=initializedVals.divide(Decimal.valueOf(String.valueOf(leadNumbVals.size())),2);
        }
        return leads;
    }
}

// preserved for later, the loadcontrol constructor——>

//Map<String,Integer>loadControl=new Map<String,Integer>();
//public PhoneRelationHandlerBatchable(List<String>campaignNames,Integer maxBatch,String filterStr){
//    //The database.executebatch(needs batchsize=1) for this to work
//    //each batch runs on a single campaign, but it actually has to run multiple times per campaign so batchch sizes are less than 1,
//    //we can make a filter term list of campaign names or ids and multiply batches ran per one record
//    //make the start run a qstring with campaignname=batchOrdering[chunkindex?]&&Limit=batchSizes[]
//    List<Campaign>camps=[SELECT Id,
//    (
//            SELECT Lead.Id,Lead.Name,Lead.MobilePhone,Lead.Phone,Lead.Secondary_Contact_Mobile__c FROM CampaignMembers
//            WHERE LeadId!=NULL AND ContactId=NULL AND
//            (Lead.MobilePhone!=NULL OR Lead.Phone!=NULL OR Lead.Secondary_Contact_Mobile__c!=NULL)
//    ) FROM Campaign WHERE Name IN :campaignNames];
//    Set<Id>leadIds=new Set<Id>();
//    List<String>batchOrdering=new List<String>();
//    List<Integer>batchSizes=new List<Integer>();
//    for(Campaign c : camps){
//        Integer cTotalBatches=(c.CampaignMembers.size())/(maxBatch-1);
//        for(Integer cBatch=0;cBatch<cTotalBatches;cBatch++){
//            batchOrdering.add(c.Name);
//            if(cBatch==cTotalBatches-1){
//                batchSizes.add(c.CampaignMembers.size()-(maxBatch*cBatch));
//            } else {
//                batchSizes.add(maxBatch);
//            }
//        }
//    }
//    String cmbrFilter=' (Id=\''+String.join(leadIds,'\' OR Id=\'')+'\')\n';
//    this.queryString='SELECT Id,Name,MobilePhone,Phone,Secondary_Contact_Mobile__c FROM Lead WHERE'+cmbrFilter+'AND (MobilePhone!=NULL OR Phone!=NULL OR Secondary_Contact_Mobile__c!=NULL)'+filterStr;
//}