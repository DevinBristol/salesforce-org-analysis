/**
 * Created by Devin on 7/9/2024.
 */
public class OutboundANIBulkLeadQueueable implements Queueable, Database.AllowsCallouts {

    private List<Lead> Leads;
    static final String apiKey = '0466B7FE-EE9D-FFCD-FAC3-383015E77099';

    public OutboundANIBulkLeadQueueable(List<Lead> Leads){
        this.Leads = Leads;
    }

    public void execute(QueueableContext context){
        List<List<Lead>> leadLoads = leadLoadSplits(Leads);
        List<Lead> updateLeads = new List<Lead>();
        Integer currentLoad = 0;
        for(List<Lead> load : leadLoads){
            currentLoad++;
            String reqBody = OutboundANIRequest(load);
            List<Lead> returnLeads = enqueueOutboundANIBulkReq(reqBody);
            updateLeads.addAll(returnLeads);


        }
        update updateLeads;
    }

    public static List<List<Lead>> leadLoadSplits(List<Lead> Leads){
        List<List<Lead>> leadLoads = new List<List<Lead>>();
        Integer totalLeads = Leads.size();
        Integer loadSize = 200;
        Integer loads = totalLeads/loadSize;
        Integer r = Math.mod(totalLeads,loadSize);

        for (Integer i = 0; i < loads; i++){
            List<Lead> load = new List<Lead>();
            for(Integer j = 0; j < loadSize; j++){
                load.add(Leads[j]);
            }
            for(Integer j = 0; j < loadSize; j++){
                Leads.remove(0);
            }
            leadLoads.add(load);
        }
        if(r > 0){
            List<Lead> load = new List<Lead>();
            load.addAll(Leads);
            leadLoads.add(load);
        }        System.debug(leadLoads);

        return leadLoads;
    }

    private static String OutboundANIRequest(List<Lead> load) {
        List<Map<String, Object>> EntriesMapList = new List<Map<String, Object>>();

        for (Lead l : load) {

            String phone;
            if(l.MobilePhone != null | l.Phone != null){
                if (l.MobilePhone != null & l.Phone == null) {
                    phone = l.MobilePhone;
                } else if (l.Phone != null & l.MobilePhone == null) {
                    phone = l.Phone;
                } else { //for leads where MobilePhone & Phone are same non-null value
                    phone = l.MobilePhone;
                }
                if(l.PostalCode == null){
                    if(phone.startsWith('308')){
                        l.PostalCode = '69001';
                    } else if(phone.startsWith('402')){
                        l.PostalCode = '68504';
                    } else {
                        l.PostalCode = '68504';
                    }

                }
                if (phone.length() == 10 && phone != null){
                    Map<String, Object> entryMap = new Map<String, Object>{
                            'row_id' => l.Id,
                            'prospect_phone' => phone,
                            'prospect_zip' => l.PostalCode
                    };
                    EntriesMapList.add(entryMap);
                }
            }


        }

        String reqBody = '{"api_key":"'+apiKey+'","campaign_id":"Outbound - Cold Calling","json_inquiry":' + JSON.serialize(EntriesMapList) + '}';
        System.debug(reqBody);
        EntriesMapList.clear();
        return reqBody;
    }

    private static List<Lead> enqueueOutboundANIBulkReq(String reqBody) {
        List<OutboundANIResponse> loadResponses = new List<OutboundANIResponse>();
        List<Lead> returnLeads = new List<Lead>();
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://app.outboundani.com/4a77d41d-47cf-4f82-8016-ae717dbb3af2/f762d9f9-a07f-46c3-a228-4b68bffe55dd_multi.php');
        req.setMethod('GET');
        req.setHeader('api_key', apiKey);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(reqBody);


        HttpResponse res = http.send(req);
        String resBody = res.getBody();
        System.debug(resBody);
        resBody = resBody.replace('ba685ce4-2c28-433a-a4c6-cac18b40f436', 'ba685ce4_2c28_433a_a4c6_cac18b40f436');
        resBody = resBody.replace('b7ef8429-9f35-4102-b1ea-44d3453a5086', 'b7ef8429_9f35_4102_b1ea_44d3453a5086');
        resBody = resBody.replace('21d697a0-a81a-4bab-b635-5f7be11181a7', 'X21d697a0_a81a_4bab_b635_5f7be11181a7');
        loadResponses.addAll((List<OutboundANIResponse>) JSON.deserializeStrict(resBody, List<OutboundANIResponse>.class));

        for (OutboundANIResponse response : loadResponses) {
            Lead l = new Lead(Id = response.row_id);
            l.Previous_ANI_TEST__c = l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c;
            l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c = response.ba685ce4_2c28_433a_a4c6_cac18b40f436;
            l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c = response.b7ef8429_9f35_4102_b1ea_44d3453a5086;
            returnLeads.add(l);
        }
        return returnLeads;
    }

    public class OutboundANIResponse {
        public String row_id { get; set; }
        public String outboundani;
        public String ba685ce4_2c28_433a_a4c6_cac18b40f436 { get; set; }
        public String X21d697a0_a81a_4bab_b635_5f7be11181a7;
        public String b7ef8429_9f35_4102_b1ea_44d3453a5086 { get; set; }
        public String error;
    }

//    public PageReference campaignUpdateANIs(){
//
//        PageReference pageRef = new PageReference('/'+Id);
//        List<CampaignMember> cMbrs = new List<CampaignMember>([
//                SELECT Id, LeadOrContactId FROM CampaignMember
//                WHERE CampaignId = :ApexPages.currentPage().getParameters().get('Id')
//        ]);
//        List<Lead> cmpLeads = new List<Lead>();
//        List<Contact> cmpContacts = new List<Contact>();
//        for (CampaignMember cMbr : cMbrs){
//            if (cMbr.LeadOrContactId.toString().startsWith('00Q')) {
//                Lead cmpLead = new Lead(Id = cMbr.LeadOrContactId);
//                cmpLeads.add(cmpLead);
//            } else if (cMbr.LeadOrContactId.toString().startsWith('003')) {
//                Contact cmpContact = new Contact(Id = cMbr.LeadOrContactId);
//                cmpContacts.add(cmpContact);
//            }
//        }
//        pageRef.setRedirect(true);
//        return pageRef;
//
//    }
//    public class CampaignANIUpdateController{
//
//        public static void Camp(Set<Id> cMbrIds){
//            List<CampaignMember> cMbrs = [SELECT Id, CampaignId, LeadOrContactId FROM CampaignMember WHERE Id IN :cMbrIds];
//
//        }
//
//
//    }

}