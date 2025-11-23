/**
 * Created by Devin on 2/5/2025.
 */

@RestResource(urlMapping ='/CompanyCamLabel')
global without sharing class WebhookCompanyCamLabels {

    @HttpPost
    global static void doPost(){
        RestRequest request = RestContext.request;
        System.debug('MyService.newMessage body:\n ' + request.requestBody.toString());
        CompanyCamLabel companyCamLabel = parseCompanyCamLabel(request.requestBody.toString());
        WebhookListner.LinkCompanyCamToOpportunity(companyCamLabel.payload.project.coordinates.lat,companyCamLabel.payload.project.coordinates.lon,companyCamLabel.payload.project.id,companyCamLabel.payload.project.address.street_address_1);
    }

    public class CompanyCamLabel{
        public String event_type;	//project.label_added
        public Integer created_at;	//1738781270
        public cls_payload payload;
        public Integer webhook_id;	//111393

//        static testMethod void testParse() {
//            String json=		''+
//                    ' {"event_type":"project.label_added","created_at":1738781270,"payload":{"project":{"id":"77032344","company_id":"908415","creator_id":"3058494","creator_type":"User","creator_name":"Devin OBrien","integration_relation_id":null,"status":"active","archived":false,"public":true,"name":"Anderson, Dave \u0026 Nadean Household – 420 West 5th Street Tea, SD – 12/7/2023","address":{"street_address_1":"420 West 5th Street","street_address_2":null,"city":"Tea","state":"SD","postal_code":"57064","country":"US"},"feature_image":[],"slug":"AWJmG71iTRYDRmRY","project_url":"https://app.companycam.com/projects/77032344","public_url":"https://app.companycam.com/timeline/AWJmG71iTRYDRmRY","coordinates":{"lat":43.4430416,"lon":-96.84100439999999},"geofence":[],"primary_contact":null,"created_at":1738118263,"updated_at":1738134707,"embedded_project_url":"https://app.companycam.com/embed/projects/AWJmG71iTRYDRmRY","photo_count":0,"capture_photo_deeplink":"ccam://camera/77032344/QW5kZXJzb24sIERhdmUgJiBOYWRlYW4gSG91c2Vob2xkIOKAkyA0MjAgV2VzdCA1dGggU3RyZWV0IFRlYSwgU0Qg4oCTIDEyLzcvMjAyMw%3D%3D","integrations":[{"type":"Salesforce","relation_id":null}],"notepad":null},"label":{"id":"11518598","company_id":"908415","display_value":"DNC","value":"dnc","created_at":1688138238,"updated_at":1688138238,"tag_type":"project"}},"webhook_id":111393}';
//            fromJSON obj = parse(json);
//            System.assert(obj != null);
//        }
    }
    public static CompanyCamLabel parseCompanyCamLabel(String json){
        return (CompanyCamLabel) System.JSON.deserialize(json, CompanyCamLabel.class);
    }
    class cls_payload {
        public cls_project project;
        public cls_label label;
    }
    class cls_project {
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
    }
    class cls_integration_relation_id {
    }
    class cls_address {
        public String street_address_1;	//420 West 5th Street
        public cls_street_address_2 street_address_2;
        public String city;	//Tea
        public String state;	//SD
        public String postal_code;	//57064
        public String country;	//US
    }
    class cls_street_address_2 {
    }
    class cls_feature_image {
    }
    class cls_coordinates {
        public Double lat;	//43.4430416
        public Double lon;	//-96.84100439999999
    }
    class cls_geofence {
    }
    class cls_primary_contact {
    }
    class cls_integrations {
        public String type;	//Salesforce
        public cls_relation_id relation_id;
    }
    class cls_relation_id {
    }
    class cls_notepad {
    }
    class cls_label {
        public String id;	//11518598
        public String company_id;	//908415
        public String display_value;	//DNC
        public String value;	//dnc
        public Integer created_at;	//1688138238
        public Integer updated_at;	//1688138238
        public String tag_type;	//project
    }
}