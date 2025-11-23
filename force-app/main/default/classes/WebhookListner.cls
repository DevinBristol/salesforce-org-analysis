/**
 * Created by Devin on 1/28/2025.
 */

@RestResource(urlMapping ='/application-name')
global without sharing class WebhookListner{

    @HttpPost
    global static void doPost(){
        RestRequest request = RestContext.request;
        System.debug('MyService.newMessage body:\n ' + request.requestBody.toString());
        CompanyCamComment camComment = parse(request.requestBody.toString());
        CompanyCamAPI.CompanyCamProject companyCamProject = GetCompanyCamProject(camComment);
        LinkCompanyCamToOpportunity(companyCamProject.coordinates.lat,companyCamProject.coordinates.lon,companyCamProject.id,companyCamProject.address.street_address_1);
    }
    public static void LinkCompanyCamToOpportunity(Double lat, Double lon,String companyCamProjectId,String street_address_1){
        List<Opportunity> foundOpportunities = getOpportunityByCompanyCamProjectId(companyCamProjectId);
        if(!foundOpportunities.isEmpty()){
            CallCompanyCamAPIFromFoundOpportunities(foundOpportunities);
        } else {
            List<Opportunity> matchableOpportunities = [SELECT Id,Name,Opportunity_Property__r.Address__c,Opportunity_Property__r.Address__Latitude__s,Opportunity_Property__r.Address__Longitude__s FROM Opportunity WHERE Name LIKE :'%'+street_address_1.substringBefore(' ')+'%'];
            List<Opportunity> linkeableOpportunities = MakeLinkeableOpportunities(matchableOpportunities,lat,lon,companyCamProjectId);
            if(!linkeableOpportunities.isEmpty()){
                CallCompanyCamAPIFromFoundOpportunities(linkeableOpportunities);
            }
        }
    }
    public static CompanyCamAPI.CompanyCamProject GetCompanyCamProject(CompanyCamComment camComment){
        CompanyCamAPI api = new CompanyCamAPI();
        HttpResponse res = api.GetCompanyCamProject(camComment.payload.comment.commentable_id);
        CompanyCamAPI.CompanyCamProject companyCamProject = CompanyCamAPI.parseCompanyCamProject(res.getBody().toString());
        return companyCamProject;
    }
    public static List<Opportunity> MakeLinkeableOpportunities(List<Opportunity> matchableOpportunities,Double lat, Double lon,String companyCamProjectId){
        List<Opportunity> linkeableOpportunities = new List<Opportunity>();
        for(Opportunity o : matchableOpportunities){
            if(o.Opportunity_Property__r.Address__Latitude__s == null|| o.Opportunity_Property__r.Address__Longitude__s == null){
                o.Opportunity_Property__r = CompanyCamAPI.GeoCodeProperty(o.Opportunity_Property__r);
            }
            Decimal resLat = o.Opportunity_Property__r.Address__Latitude__s;
            Decimal resLng = o.Opportunity_Property__r.Address__Longitude__s;
            Decimal latDif = Math.abs(lat-resLat);
            Decimal lngDif = Math.abs(lon-resLng);
            if(latDif < 0.002 && lngDif < 0.002){
                o.companycam__ProjectID__c = companyCamProjectId;
                System.debug(o.companycam__ProjectID__c);
                linkeableOpportunities.add(o);
            }
        }
        return linkeableOpportunities;
    }
    public static void CallCompanyCamAPIFromFoundOpportunities(List<Opportunity> foundOpportunities){
        List<Id> opIds = new List<Id>();
        for(Opportunity o : foundOpportunities){
            opIds.add(o.Id);
        }
        CompanyCamAPI.LinkCompanyCamWithOpportunity(opIds);
    }
    public static List<Opportunity> getOpportunityByCompanyCamProjectId(String commentable_id){
        List<Opportunity> foundOpportunities = [SELECT Id FROM Opportunity WHERE companycam__ProjectID__c = :commentable_id];
        System.debug(foundOpportunities);
        return foundOpportunities;
    }
    public class CompanyCamComment{
        public String event_type;	//comment.created
        public Integer created_at;	//1738699103
        public cls_payload payload;
        public Integer webhook_id;	//111247
    }
    public static CompanyCamComment parse(String json){
        return (CompanyCamComment) System.JSON.deserialize(json, CompanyCamComment.class);
    }
    private class cls_payload {
        public cls_comment comment;
    }
    private class cls_comment {
        public String id;	//35644697
        public String commentable_id;	//77032344
        public String commentable_type;	//Location
        public String status;	//active
        public String content;	//test
        public String creator_id;	//3058494
        public String creator_type;	//User
        public String creator_name;	//Devin OBrien
        public Integer created_at;	//1738699102
        public Integer updated_at;	//1738699102
    }
}