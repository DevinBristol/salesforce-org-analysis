/**
 * Created by Devin on 6/5/2024.
 */

public with sharing class AccountTriggerHandler extends TriggerHandler {

    public override void afterInsert(){
        List<List<SObject>> recordsLists = AccountTriggerHelper.pickRecords((List<Account>)Trigger.new);
        List<Account> accountsUpdate = NamingUtility.NameAccount(recordsLists[0]);
        update accountsUpdate;
    }

    public override void afterUpdate(){
        List<List<SObject>> recordsLists = AccountTriggerHelper.pickRecords((List<Account>)Trigger.new);
        List<Opportunity> opportunitiesUpdate = NamingUtility.NameOpportunity(recordsLists[1]);
        update opportunitiesUpdate;
    }

    public override void beforeInsert(){
        AccountTriggerHelper.UpdateAccountStageOnNull();
    }
}