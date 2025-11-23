/**
 * Created by Devin on 6/4/2024.
 */

public with sharing class LeadTriggerHandler extends TriggerHandler{
    public override void beforeInsert(){
        List<Lead> NameableLeads = new List<Lead>();
        List<Lead> PhoneDeformatableLeads = new List<Lead>();
        for(Lead l : (List<Lead>)Trigger.new){
            if(LeadTriggerHelper.LeadIsNameable(l)){
                NameableLeads.add(l);
            }
            if(LeadTriggerHelper.PhoneIsDeformatable(l)){
                PhoneDeformatableLeads.add(l);
            }
        }
        NamingUtility.NameLeadCompany(NameableLeads);
        LeadTriggerHelper.DeformatLeadNumbers(PhoneDeformatableLeads);
    }
    public override void beforeUpdate(){
        List<Lead> NameableLeads = new List<Lead>();
        List<Lead> PhoneDeformatableLeads = new List<Lead>();
        for(Lead l : (List<Lead>)Trigger.new){
            if(LeadTriggerHelper.LeadIsNameable(l)){
                NameableLeads.add(l);
            }
            if(LeadTriggerHelper.PhoneIsDeformatable(l)){
                PhoneDeformatableLeads.add(l);
            }
        }
        NamingUtility.NameLeadCompany(NameableLeads);
        LeadTriggerHelper.DeformatLeadNumbers(PhoneDeformatableLeads);
    }
    public override void afterUpdate(){
            List<Lead> PhoneRelatableLeads = new List<Lead>();
            Map<Id,Lead> PropertyRelatableLeads = new Map<Id,Lead>();
            for(Lead l : (List<Lead>)Trigger.new){
                if(LeadTriggerHelper.PhonesAreRelatable(l)){
                    PhoneRelatableLeads.add(l);
                }
                if(LeadTriggerHelper.PropertiesAreRelatable(l)){
                    PropertyRelatableLeads.put(l.Id,l);
                }
            }
            System.debug('LeadTriggerHandler : PhoneRelatableLeads ::: ' + PhoneRelatableLeads.size());
            System.debug('LeadTriggerHandler : PropertyRelatableLeads ::: ' + PropertyRelatableLeads.size());
            LeadTriggerHelper.RelateLeadProperties(PropertyRelatableLeads);
            PhoneRelationHandler.HandlePhonesFromLeads(PhoneRelatableLeads);
    }
    public override void afterInsert(){
        LeadTriggerHelper.RelateLeadProperties((Map<Id,Lead>)Trigger.newMap);
        PhoneRelationHandler.HandlePhonesFromLeads((List<Lead>)Trigger.new);
        TriggerHandler.bypass('LeadTriggerHandler');
    }
    public override void afterDelete(){
        PhoneRelationHandler.HandlePhonesFromLeads((List<Lead>)Trigger.old);
    }
}