/**
 * Created by Devin on 1/9/2025.
 */

public without sharing class CompanyCamAPI {
    static final String TokenValue = Company_Cam_Bearer_Token__c.getInstance(UserInfo.getProfileId()).Token_Value__c;
    static final String RefreshToken = Company_Cam_Bearer_Token__c.getInstance(UserInfo.getProfileId()).RefreshToken__c;

    @TestVisible
    private static Boolean isTestExecution = false;
    @InvocableMethod(label='Link CompanyCam with Opportunity' description='Links CompanyCam projects and comments with Opportunities.')
    public static void LinkCompanyCamWithOpportunity(List<Id> opIds) {
        CompanyCamAPI api = new CompanyCamAPI();
        api.LinkCompanyCamWithOpportunity1(opIds);
    }
    public static List<String> GetUserCompanyCamIds(List<OpportunityTeamMember> opportunityTeamMembers){
        List<String> CompanyCamUserIds = new List<String>();
        List<Id> UserIds = new List<Id>();
        for (OpportunityTeamMember opportunityTeamMember : opportunityTeamMembers){
                UserIds.add(opportunityTeamMember.UserId);
        }
        List<User> OutsideSalesReps = [SELECT Id, CompanyCamUserId__c FROM User WHERE Id IN :UserIds]; // this is all users now.
        for(User Osr : OutsideSalesReps){
            if(Osr.CompanyCamUserId__c!= null){
                CompanyCamUserIds.add(Osr.CompanyCamUserId__c);

            }
        }
        return CompanyCamUserIds;
    }
    public void LinkCompanyCamWithOpportunity1(List<Id> opIds){
        List<Opportunity> Ops = [SELECT Id,Name,AccountId,(SELECT Id,Topic.Name FROM TopicAssignments),Opportunity_Property__r.Address__c,companycam__ProjectID__c,Opportunity_Property__r.Address__Latitude__s, Opportunity_Property__r.Address__Longitude__s FROM Opportunity WHERE Id IN :opIds];
        Map<String,Id> topicMap = MakeTopicMap();
        System.debug(topicMap);
        List<TopicAssignment> creatableTopicAssignments = new List<TopicAssignment>();
        List<TopicAssignment> DeleteableTopicAssignments = new List<TopicAssignment>();
        Map<Id,List<String>> OpportunityTopicNameMap = new Map<Id,List<String>>();
        Set<String> AllTopics = new Set<String>();
        for (Opportunity op : Ops){
            List<String> TopicNames = new List<String>();
            if(op.Opportunity_Property__r != null) {
                if(op.companycam__ProjectID__c==null){
                    op.companycam__ProjectID__c = GetCompanyCamProjectId(op);
                }
                TopicNames = FetchOpportunityTopics(op,op.companycam__ProjectID__c);
                op = FetchCompanyCamComments(op,TopicNames);
                OpportunityTopicNameMap.put(op.Id,TopicNames);
                AllTopics.addAll(TopicNames);
            }
        }
        Set<String> TopicNamesCreatable = MakeTopicNamesCreatable(topicMap,AllTopics);
        System.debug(AllTopics);
        topicMap = MakeUnmadeTopics(topicMap,new List<String>(TopicNamesCreatable));
        System.debug(topicMap);
        for (Opportunity op : Ops){
            if(op.Opportunity_Property__r != null) {
                List<String> TopicNames = OpportunityTopicNameMap.get(op.Id);
                List<String> OldTopicNames = new List<String>();
                List<String> TopicAssignmentNamesDeletable = new List<String>();
                for(TopicAssignment ta : op.TopicAssignments){
                    OldTopicNames.add(ta.Topic.Name.toLowerCase());
                    if(!TopicNames.contains(ta.Topic.Name.toLowerCase())){
                        TopicAssignmentNamesDeletable.add(ta.Topic.Name.toLowerCase());
                        DeleteableTopicAssignments.add(ta);
                    }
                }
                List<String> TopicAssignmentNamesCreatable = MakeTopicAssignmentNamesCreateable(OldTopicNames,TopicNames);
                creatableTopicAssignments.addAll(MakeTopicCreateableTopicAssignments(op.Id,topicMap,TopicAssignmentNamesCreatable));
            }
        }
        System.debug(creatableTopicAssignments);
        System.debug(DeleteableTopicAssignments);
        delete DeleteableTopicAssignments;
        upsert creatableTopicAssignments;
        update Ops;
    }
    public static List<TopicAssignment>  MakeTopicCreateableTopicAssignments(Id opId,Map<String,Id> topicMap,List<String> TopicAssignmentNamesCreatable){
        List<TopicAssignment> CreateableTopicAssignments = new List<TopicAssignment>();
        for(String tanc : TopicAssignmentNamesCreatable){
            TopicAssignment newTopicAssignment = new TopicAssignment(TopicId = topicMap.get(tanc.toLowerCase()),EntityId = opId);
            CreateableTopicAssignments.add(newTopicAssignment);
        }
        return CreateableTopicAssignments;
    }
    public static List<String> MakeTopicAssignmentNamesCreateable(List<String> OldTopicNames,List<String> TopicNames){
        List<String> TopicAssignmentNamesCreatable = new List<String>();
        for (String tn : TopicNames){
            if(!OldTopicNames.contains(tn)) {
                TopicAssignmentNamesCreatable.add(tn);
            }
        }
        return TopicAssignmentNamesCreatable;
    }
    public static Set<String> MakeTopicNamesCreatable(Map<String,Id> topicMap,Set<String> AllTopics){
        Set<String> TopicNamesCreatable = new Set<String>();
        for(String tn : AllTopics){
            if(topicMap.get(tn.toLowerCase()) == null){
                TopicNamesCreatable.add(tn);
            }
        }
        return TopicNamesCreatable;
    }
    public static Map<Id,String> MakeTopicsKeepable(List<String>TopicNames,Map<String,Id> topicMap){
        Map<Id,String> TopicsKeepable = new Map<Id,String>();
        for(String tn : TopicNames){
            TopicsKeepable.put(topicMap.get(tn.toLowerCase()),tn.toLowerCase());
        }
        System.debug(TopicsKeepable.values());
        return TopicsKeepable;
    }
    public static Map<String,Id> MakeUnmadeTopics(Map<String,Id> topicMap,List<String>TopicNames){
        List<Topic> topicsCreatable = MakeTopicsCreatable(topicMap,TopicNames);
        insert topicsCreatable;
        for (Topic t : topicsCreatable){
            topicMap.put(t.Name.toLowerCase(),t.Id);
        }
        return topicMap;
    }
    public static List<Topic> MakeTopicsCreatable(Map<String,Id> topicMap,List<String>TopicNames){
        List<Topic> topicsCreatable = new List<Topic>();
        for(String tn : TopicNames){
            if(topicMap.get(tn.toLowerCase()) == null){
                Topic newTopic = new Topic(Name = tn.capitalize());
                topicsCreatable.add(newTopic);
            }
        }
        return topicsCreatable;
    }
    public static Map<String,Id> MakeTopicMap(){
        List<Topic> topics = [SELECT Id,Name FROM Topic];
        Map<String,Id> topicMap = new Map<String,Id>();
        for (Topic t : topics){
            topicMap.put(t.Name.toLowerCase(),t.Id);
        }
        return topicMap;
    }
    //CompanyCamHelpers
    public static cls_primary_contact MakePrimaryContact(Id accId){
        cls_primary_contact primaryContact = new cls_primary_contact();
        List<Contact> accountContacts = new List<Contact>([SELECT Id, FirstName, LastName, Email, MobilePhone, Phone FROM Contact WHERE AccountId = :accId]);
        for (Contact c : accountContacts){
            primaryContact.name = c.FirstName + ' ' + c.LastName;
            if (c.MobilePhone != null){
                primaryContact.phone_number = c.MobilePhone;
            } else if(c.Phone != null) {
                primaryContact.phone_number = c.Phone;
            }
            if(primaryContact.phone_number != null){
                break;
            }
        }
        primaryContact.email = '';
        if(primaryContact.name == null) {
            primaryContact.name = '';
        }
        if(primaryContact.phone_number == null) {
            primaryContact.phone_number = '';
        }
        return primaryContact;
    }

    public static String MakeCompanyCamProjectBody(Opportunity op){
        String accId = op.AccountId;
        cls_primary_contact contactF = MakePrimaryContact(accId);
        Map<String,Object> bodymap = new Map<String,Object>{'name'=> op.Name, 'address' => new Map<String,String>{'street_address_1' => op.Opportunity_Property__r.Address__c.getStreet(),'city' => op.Opportunity_Property__r.Address__c.getCity(),'state' => op.Opportunity_Property__r.Address__c.getStateCode(),'postal_code' => op.Opportunity_Property__r.Address__c.getPostalCode(),'country' => op.Opportunity_Property__r.Address__c.getCountryCode()},
        'primary_contact' => new Map<String,String>{'name' => contactF.name, 'email' => contactF.email, 'phone_number' => contactF.phone_number}};
        return JSON.serialize(bodymap);
    }
    public String GetCompanyCamProjectId(Opportunity op){
        String CompanyCamProjectId;
        if(op.Opportunity_Property__r.Address__Latitude__s == null || op.Opportunity_Property__r.Address__Longitude__s == null) { // null check to see if we need to geocode the prop
            op.Opportunity_Property__r = GeoCodeProperty(op.Opportunity_Property__r);
        }
        HttpResponse response = RetrieveCompanyCamProjectList(op.Opportunity_Property__r.Address__c.getStreet().substringBefore(' '));
        CompanyCamProjectId = FilterCompanyCamProjectList(response,op.Opportunity_Property__r.Address__Latitude__s,op.Opportunity_Property__r.Address__Longitude__s);
        if(CompanyCamProjectId == null){ // No Company Cam Project was matched with the projects found in company cam... Create one and return its ProjectId
            CompanyCamProjectId = GetCompanyCamProjectIdFromNewCompanyCamProject(op);
        }
        return CompanyCamProjectId;
    }
    public String FilterCompanyCamProjectList(HttpResponse response1, Decimal Lat, Decimal Lng){
        String companycamProjectID;
        System.debug(response1);
        List<Object> responseSerialized = (List<Object>)JSON.deserializeUntyped(response1.getBody());
        for(Object obj : responseSerialized){
            Map<String,Object> resItem = new Map<String,Object>();
            resItem.putAll((Map<String,Object>)obj);
            Map<String,Object> coords = (Map<String,Object>)resItem.get('coordinates');
            Decimal resLat = (Decimal)coords.get('lat');
            Decimal resLng = (Decimal)coords.get('lon');
            Decimal latDif = Math.abs(Lat-resLat);
            Decimal lngDif = Math.abs(Lng-resLng);
            if(latDif < 0.002 && lngDif < 0.002){
                if(resItem.get('status') != 'deleted'){ // Check for CompanyCamProject status to NOT equal deleted. If deleted, return null to create new project.
                    companycamProjectID = (String)resItem.get('id');
                }
            }
        }
        return companycamProjectID;
    }
    private String GetCompanyCamProjectIdFromNewCompanyCamProject(Opportunity op){
        String CompanyCamProjectId;
        HttpResponse res = CreateCompanyCamProject(op);
        CompanyCamProjectId = FilterCreatedCompanyCamProjectForCompanyCamId(res);
        return CompanyCamProjectId;
    }
    public static String FilterCreatedCompanyCamProjectForCompanyCamId(HttpResponse res){
        Map<String,Object> ResObjects = (Map<String,Object>)JSON.deserializeUntyped(res.getBody());
        String CompanyCamId = (String)ResObjects.get('id');
        return CompanyCamId;
    }
    //TopicsHelpers
    public List<String> FetchOpportunityTopics(Opportunity op, String companyCamProjectId){
            HttpResponse res = GetCompanyCamLabels(companyCamProjectId);
            System.debug(res.getBody());
            return MakeTopicNames(res);
    }
    private static List<String> MakeTopicNames(HttpResponse res){
        List<Object> ListResObjects = (List<Object>)JSON.deserializeUntyped(res.getBody());
        List<String> topicNames = new List<String>();
        for (Object o : ListResObjects){
            Map<String,Object> itemMap = (Map<String,Object>)o;
            String TopicName = (String)itemMap.get('display_value');
            topicNames.add(TopicName.toLowerCase());
        }
        return topicNames;
    }
    //MapsHelpers
    //CALLS
    public HttpResponse RetrieveCompanyCamProjectList(String StreetNumber) {
            HttpRequest request1 = new HttpRequest();
            request1.setEndpoint('https://app.companycam.com/v2/projects?query=' + StreetNumber);
            request1.setHeader('accept','application/json');
            request1.setHeader('content-type','application/json');
            request1.setHeader('authorization','Bearer '+TokenValue);
            request1.setMethod('GET');
            Http http1 = new Http();
            HttpResponse response1 = http1.send(request1);
            System.debug('CompanyCamAPI ::: RetrieveCompanyCamProjectList Body ::: ' + response1.getBody());
            return response1;
    }
    public HttpResponse CreateCompanyCamProject(Opportunity op){
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://app.companycam.com/v2/projects');
        request.setHeader('accept', 'application/json');
        request.setHeader('content-type', 'application/json');
        request.setHeader('authorization', 'Bearer ' + TokenValue);
        request.setMethod('POST');
        request.setBody(MakeCompanyCamProjectBody(op));
        Http http = new Http();
        HttpResponse response = http.send(request);
        System.debug('CompanyCamAPI ::: CreateCompanyCamProject Body ::: ' + response.getBody());
        return response;
    }
    public HttpResponse GetCompanyCamLabels(String CompanyCamProjectId){
        HttpRequest request1 = new HttpRequest();
        request1.setEndpoint('https://app.companycam.com/v2/projects/' + CompanyCamProjectId + '/labels');
        request1.setHeader('accept','application/json');
        request1.setHeader('content-type','application/json');
        request1.setHeader('authorization','Bearer '+ TokenValue);
        request1.setMethod('GET');
        Http http1 = new Http();
        HttpResponse response1 = http1.send(request1);
        System.debug('CompanyCamAPI ::: GetCompanyCamLabels Body ::: ' + response1.getBody());
        return response1;
    }
    public HttpResponse GetCompanyCamComments(String CompanyCamProjectId){
        HttpRequest request2 = new HttpRequest();
        request2.setEndpoint('https://app.companycam.com/v2/projects/' + CompanyCamProjectId + '/comments');
        request2.setHeader('accept','application/json');
        request2.setHeader('content-type','application/json');
        request2.setHeader('authorization','Bearer '+ TokenValue);
        request2.setMethod('GET');
        Http http = new Http();
        HttpResponse response2 = http.send(request2);
        System.debug('CompanyCamAPI ::: GetCompanyCamComments Body ::: ' + response2.getBody());
        return response2;
    }
    public HttpResponse GetCompanyCamProject(String CompanyCamProjectId){
        HttpRequest request2 = new HttpRequest();
        request2.setEndpoint('https://app.companycam.com/v2/projects/' + CompanyCamProjectId);
        request2.setHeader('accept','application/json');
        request2.setHeader('content-type','application/json');
        request2.setHeader('authorization','Bearer '+ TokenValue);
        request2.setMethod('GET');
        Http http = new Http();
        HttpResponse response2 = http.send(request2);
        return response2;
    }
    public HttpResponse PutCompanyCamUsers(String CompanyCamProjectId,String UserCompanyCamId){
        HttpRequest request2 = new HttpRequest();
        request2.setEndpoint('https://app.companycam.com/v2/projects/' + CompanyCamProjectId + '/assigned_users/' + UserCompanyCamId);
        request2.setHeader('accept','application/json');
        request2.setHeader('content-type','application/json');
        request2.setHeader('authorization','Bearer '+ TokenValue);
        request2.setMethod('PUT');
        Http http = new Http();
        HttpResponse response2 = http.send(request2);
        return response2;
    }
    public Opportunity FetchCompanyCamComments(Opportunity op, List<String> topics){
        HttpResponse res = GetCompanyCamComments(op.companycam__ProjectID__c);
        op = AssignOpportunityComments(op,res,topics);
        return op;
    }
    private static Opportunity AssignOpportunityComments(Opportunity op, HttpResponse res,List<String> topics){
        List<Object> ListResObjects = (List<Object>)JSON.deserializeUntyped(res.getBody());
        List<CommentFormatter.CommentWrapper> comments = new List<CommentFormatter.CommentWrapper>();
        for (Object o : ListResObjects){
            Map<String,Object> itemMap = (Map<String,Object>)o;
            comments.add(new CommentFormatter.CommentWrapper((String)itemMap.get('creator_name'),(String)itemMap.get('content'),makeCommentTime((Long)itemMap.get('created_at'))));
        }
        op.CompanyCam_Chat_History__c = CommentFormatter.formatComments(comments,topics);
        return op;
    }
    private static Datetime makeCommentTime(Long UnixTime){
        UnixTime = UnixTime*1000;
        Datetime CommentTime = Datetime.newInstance(UnixTime);
        return CommentTime;
    }
    public static Property__c GeoCodeProperty(Property__c prop) {
        try {
            if (prop.Address__c.getStreet() != null && prop.Address__c.getCity() != null && prop.Address__c.getStateCode() != null) {
                Map<String, Object> response = maps.API.Geocode(MakeMapsAPIOptions(prop));
                prop = handleMapsResponseValues(prop, response);
                System.debug('CompanyCamAPI ::: Geocoded Property: ' + prop.Address__Longitude__s + ', ' + prop.Address__Latitude__s);
            }
        } catch (Exception e) {
            System.debug('CompanyCamAPI ::: Error in GeoCodeProperty: ' + e.getMessage());
        }
        return prop;
    }
    public static Map<String, Object> MakeMapsAPIOptions(Property__c prop) {
        String address = prop.Address__c.getStreet() + ', ' + prop.Address__c.getCity() + ', ' + prop.Address__c.getStateCode();
        return new Map<String, Object>{
                'version' => '1',
                'address' => address
        };
    }
    private static Property__c handleMapsResponseValues(Property__c prop, Map<String, Object> response) {
        try {
            Map<String, Object> data = (Map<String, Object>) response.get('data');
            Map<String, Object> LatLng = (Map<String, Object>) data.get('position');
            prop.Address__Latitude__s = (Decimal) LatLng.get('lat');
            prop.Address__Longitude__s = (Decimal) LatLng.get('lng');
        } catch (Exception e) {
            System.debug('CompanyCamAPI ::: Error parsing geocoding response: ' + e.getMessage());
        }
        return prop;
    }
    public class CompanyCamProject{
        public String id;	//77032344
        public String company_id;	//908415
        public String creator_id;	//3058494
        public String creator_type;	//User
        public String creator_name;	//Devin OBrien
        public cls_integration_relation_id integration_relation_id;
        public String status;	//active
        public boolean archived;
        public String name;	//Anderson, Dave & Nadean Household – 420 West 5th Street Tea, SD – 12/7/2023
        public cls_address address;
        public cls_feature_image[] feature_image;
        public String slug;	//AWJmG71iTRYDRmRY
        public String project_url;	//https://app.companycam.com/projects/77032344
        public String public_url;	//https://app.companycam.com/timeline/AWJmG71iTRYDRmRY
        public cls_coordinates coordinates;
        public cls_geofence[] geofence;
        public cls_primary_contact primary_contact;
        public Integer created_at;	//1738118263
        public Integer updated_at;	//1738134707
        public String embedded_project_url;	//https://app.companycam.com/embed/projects/AWJmG71iTRYDRmRY
        public Integer photo_count;	//0
        public String capture_photo_deeplink;	//ccam://camera/77032344/QW5kZXJzb24sIERhdmUgJiBOYWRlYW4gSG91c2Vob2xkIOKAkyA0MjAgV2VzdCA1dGggU3RyZWV0IFRlYSwgU0Qg4oCTIDEyLzcvMjAyMw%3D%3D
        public cls_integrations[] integrations;
        public cls_notepad notepad;
//        static testMethod void testParse() {
//            String json=		'{"id":"77032344","company_id":"908415","creator_id":"3058494","creator_type":"User","creator_name":"Devin OBrien","integration_relation_id":null,"status":"active","archived":false,"public":true,"name":"Anderson, Dave \u0026 Nadean Household – 420 West 5th Street Tea, SD – 12/7/2023","address":{"street_address_1":"420 West 5th Street","street_address_2":null,"city":"Tea","state":"SD","postal_code":"57064","country":"US"},"feature_image":[],"slug":"AWJmG71iTRYDRmRY","project_url":"https://app.companycam.com/projects/77032344","public_url":"https://app.companycam.com/timeline/AWJmG71iTRYDRmRY","coordinates":{"lat":43.4430416,"lon":-96.84100439999999},"geofence":[],"primary_contact":null,"created_at":1738118263,"updated_at":1738134707,"embedded_project_url":"https://app.companycam.com/embed/projects/AWJmG71iTRYDRmRY","photo_count":0,"capture_photo_deeplink":"ccam://camera/77032344/QW5kZXJzb24sIERhdmUgJiBOYWRlYW4gSG91c2Vob2xkIOKAkyA0MjAgV2VzdCA1dGggU3RyZWV0IFRlYSwgU0Qg4oCTIDEyLzcvMjAyMw%3D%3D","integrations":[{"type":"Salesforce","relation_id":null}],"notepad":null}';
//            fromJSON obj = parse(json);
//            System.assert(obj != null);
//        }

    }
    public class cls_integration_relation_id {
    }
    public class cls_address {
        public String street_address_1;	//420 West 5th Street
        public cls_street_address_2 street_address_2;
        public String city;	//Tea
        public String state;	//SD
        public String postal_code;	//57064
        public String country;	//US
    }
    public class cls_street_address_2 {
    }
    public class cls_feature_image {
    }
    public class cls_coordinates {
        public Double lat;	//43.4430416
        public Double lon;	//-96.84100439999999
    }
    public class cls_geofence {
    }
    public class cls_primary_contact {
        public String name;
        public String email;
        public String phone_number;
    }
    public class cls_integrations {
        public String type;	//Salesforce
        public cls_relation_id relation_id;
    }
    public class cls_relation_id {
    }
    public class cls_notepad {
    }
    public static CompanyCamProject parseCompanyCamProject(String json){
        return (CompanyCamProject) System.JSON.deserialize(json, CompanyCamProject.class);
    }
}