/**
 * Created by Ben on 2/25/2025.
 */

global class LeadPropertyRelationshipBatchable implements Database.Batchable<SObject>{
    public String queryString;
    public Boolean useTriggerHelper=false;
    public List<String>streets=new List<String>();
    public List<String>cities=new List<String>();
    public List<String>states=new List<String>();
    public List<String>postals=new List<String>();
    public Map<String,Id>ldAddressToLeadId=new Map<String,Id>();
    public Map<String,Integer> ldAddressToLdIndex=new Map<String,Integer>();
    public Map<Id,Id>leadIdToPropId=new Map<Id,Id>();
    public Map<Id,Lead> leadMap=new Map<Id, Lead>();
    public LeadPropertyRelationshipBatchable(Boolean useTriggerHelper,String campaignName,String filterStr){
        if(filterStr==null){
            filterStr='Property__c=NULL AND InitializedProperty__c=FALSE AND\n   Street LIKE \'% %\' AND\n   ((City!=NULL AND State!=NULL) OR PostalCode!=NULL)\n';
        }
        if(campaignName!=null){
            List<CampaignMember>cmbrs=[SELECT LeadId FROM CampaignMember WHERE Campaign.Name=:campaignName AND LeadId!=NULL AND ContactId=NULL ORDER BY Campaign.Name];
            Set<Id>leadIds=new Set<Id>();
            for(CampaignMember cmbr : cmbrs){
                leadIds.add(cmbr.LeadId);
            }
            String cmbrFilter='(Id=\''+String.join(leadIds,'\' OR Id=\'')+'\')\n';
            filterStr=cmbrFilter+' AND '+filterStr;
        }
        this.useTriggerHelper=useTriggerHelper;
        this.queryString='SELECT Id,Street,City,State,PostalCode,Country,Latitude,Longitude,Property__c,CreatedDate\n' +
                '   FROM Lead WHERE '+filterStr+'   ORDER BY LastModifiedDate ASC';
    }
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(this.queryString);
    }
    global void execute(Database.BatchableContext bc,List<Lead>scope) {
        if(this.useTriggerHelper){
            initializeLeadMaps(scope);
            LeadTriggerHelper.RelateLeadProperties(this.leadMap);
        } else {
            initializeLeadMaps(scope);
            String propQString=makeScopePropQString(scope);
            List<Property__c> props=Database.query(propQString);
            List<Lead>updateLeads=makeUpdateLeads(scope,props,this.leadIdToPropId);
            update updateLeads;
        }

        Set<Id>scopeIds=new Set<Id>();
        for(Lead l : scope){
            scopeIds.add(l.Id);
        }
        markForInitializedProperty(scopeIds);
    }

    global void finish(Database.BatchableContext bc) {

    }
    public void initializeLeadMaps(List<Lead> leads){
        Integer i=0;
        for(Lead l : leads){
            streets.add(l.Street);
            cities.add(l.City);
            states.add(l.State);
            postals.add(l.PostalCode);
            leadMap.put(l.Id,l);
            String ldAddressString=l.Street.toUpperCase();
            if(l.City!=null){
                ldAddressString=ldAddressString+','+l.City.toUpperCase();
            }
            if(l.State!=null){
                ldAddressString=ldAddressString+','+l.State.toUpperCase();
            }
            if(l.PostalCode!=null){
                ldAddressString=ldAddressString+','+l.PostalCode;
            }
            ldAddressToLeadId.put(ldAddressString,l.Id);
            ldAddressToLdIndex.put(ldAddressString,i);
            i++;
        }
    }
    public String makeScopePropQString(List<Lead> leads){
        String propQString='SELECT Id,Address__Street__s,Address__City__s,Address__StateCode__s,Address__PostalCode__s,Address__CountryCode__s,Address__Latitude__s,Address__Longitude__s FROM Property__c WHERE (\n';
                for(Integer i=0;i<leads.size();i++){
                    String qLine='(';
                    if(i>0){ qLine='OR'+qLine; }
                    if(streets[i]!=null){
                        qLine=qLine+'';
                        if(streets[i].contains('\'')){
                            qLine=qLine+'  (Address__Street__s LIKE \''+streets[i].substringBefore('\'')+'%\''+' AND Address__Street__s LIKE \'%'+streets[i].substringAfter('\'')+'\')';
                        } else {
                            qLine=qLine+'Address__Street__s=\''+streets[i]+'\'';
                        }
                    }
                    if(cities[i]!=null){
                        qLine=qLine+' AND\n';
                        if(cities[i].contains('\'')){
                            qLine=qLine+'   (Address__City__s LIKE \''+cities[i].substringBefore('\'')+'%\''+' AND Address__City__s LIKE \'%'+cities[i].substringAfter('\'')+'\')';
                        } else {
                            qLine=qLine+'   Address__City__s=\''+cities[i]+'\'';
                        }
                    }
                    if(states[i]!=null){
                        qLine=qLine+' AND\n   Address__StateCode__s=\''+states[i]+'\'';
                    }
                    if(postals[i]!=null){
                        qLine=qLine+' AND\n   Address__PostalCode__s=\''+postals[i]+'\'';
                    }
                    qLine=qLine+')';
                    propQString = propQString + qLine + '\n';
                }
                propQString=propQString+')';
                return propQString;
    }

    public List<Lead> makeUpdateLeads(List<Lead>leads,List<Property__c>props,Map<Id,Id>leadIdToPropIdMap){
        List<Lead> updateLeads=new List<Lead>();
        for(Property__c p : props){
            String pAddressString=p.Address__Street__s.toUpperCase()+','+p.Address__City__s.toUpperCase()+','+p.Address__StateCode__s.toUpperCase()+','+p.Address__PostalCode__s.toUpperCase();
            ldAddressToLdIndex.get(pAddressString);
            Integer leadIndex=ldAddressToLdIndex.get(pAddressString);
            if(leadIndex!=null){
                leadIdToPropId.put(leads[leadIndex].Id,p.Id);
            }
        }
        for(Id leadId : leadIdToPropId.keySet()){
            Lead updateL=new Lead(Id=leadId,Property__c=leadIdToPropId.get(leadId));
            updateLeads.add(updateL);
        }
        System.debug('\rupdateLeads (size='+updateLeads.size()+')—>\r'+updateLeads);
        return updateLeads;
    }
    public static void markForInitializedProperty(Set<Id>scopeIds){
        List<Lead>leads=[SELECT Id,Property__c,InitializedProperty__c FROM Lead WHERE Id IN :scopeIds];
        for(Lead l : leads){
            if(l.Property__c!=null){
                l.InitializedProperty__c=true;
            }
        }
        update leads;
    }
}