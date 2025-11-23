/**
 * Created by benra on 7/10/2025.
 */
@RestResource(UrlMapping='/Five9Webhook')
global with sharing class Five9Webhook {
    public static Integer endcode;
    public static Call_Log__c cl=new Call_Log__c();
    @HttpPost
    global static String doPost(){
        RestRequest req = RestContext.request;
        RestResponse res=RestContext.response;
        String xKey='x-shared-secret';
        System.debug('doPost: req.Headers ... \r'+JSON.serializePretty(req.headers));
        System.debug('doPost: req.Params ... \r'+JSON.serializePretty(req.params));
        System.debug('doPost: req.Body ... \r'+req.requestBody.toString());
        if(turnstile(req,xKey)){
            System.debug('you\'re authorized');
            String logMsg=processPost(req.params,req.requestBody.toString(),xKey);
            res.statusCode=endcode;
            res.responseBody=Blob.valueOf(JSON.serializePretty(logMsg));
            return logMsg;
        } else {
            res.statusCode=401;
            res.responseBody=Blob.valueOf('Unauthorized');
            return 'Unauthorized';
        }
    }
    private static Boolean turnstile(RestRequest req,String xKey){
        String xSecret=Five9Reporter_Setting__mdt.getInstance('Current').Secret__c;
        if(req.headers.containsKey(xKey)){
            return(req.headers.get(xKey)==xSecret);
        } else if(req.params.containsKey(xKey)){
            return(req.params.get(xKey)==xSecret);
        } else if(req.requestBody!=null) {
            Map<String,String>fields=bodyMapper(req.requestBody.toString());
            return (fields.containsKey(xKey)&&fields.get(xKey)==xSecret);
        } else {
            return false;
        }
    }
    public static Map<String,String>bodyMapper(String body) { // body='req.requestBody.toString()';
        Map<String,String>fields=new Map<String,String>();
        for(String field:body.split('&')){
            List<String>pair=field.split('=');
            if(pair.size()==2){// URL decode the key and value
                fields.put(EncodingUtil.urlDecode(pair[0],'UTF-8'),EncodingUtil.urlDecode(pair[1],'UTF-8'));
            }
        }
        return fields;
    }
    public static String processPost(Map<String,String>params,String reqBody,String xKey){
        List<String>logMsg=new List<String>{'AUTHORIZED','reqBody='+reqBody,'params='+params};
        try{Map<String,String>payload=bodyMapper(reqBody);
            payload.putAll(params);
            payload.remove(xKey);
            makeCallLog(payload);
            System.debug('Deserialized:\r'+JSON.serializePretty(cl));
            logMsg.add('Deserialized:'+JSON.serializePretty(cl));
            try{
                insert cl;
                endcode=200;
                return'SUCCESS';
            } catch(Exception e){endcode=501;
                System.debug('ERROR ON INSERT.\r'+JSON.serializePretty(cl)+'\r\r\tError Message:\r'+e.getMessage());
                logMsg.addAll(new List<String>{'ERROR ON INSERT.',JSON.serializePretty(cl),e.getMessage()});
                return JSON.serializePretty(logMsg);
            }
        } catch(Exception e){ endcode=502;
            System.debug('ERROR ON makeCallLog\r'+e.getMessage());
            logMsg.addAll(new List<String>{'ERROR ON makeCallLog.',e.getMessage()});
            return JSON.serializePretty(logMsg);
        }
    }
    public static void makeCallLog(Map<String,String>payload){
        System.debug(payload.keySet());
        for(String key : payload.keySet()){
            String namekey=nameMap.get(key);
            System.debug('On '+key+', namekey='+namekey);
            String val=payload.get(key);
            if(val!=''&&val!=null){
                typesetter(namekey,(String)payload.get(key));
            }

        }
    }
    public static void typesetter(String namekey,String val){
        switch on namekey{
            when'Agent__c'{cl.put(namekey,val);}
            when'ANI__c'{cl.put(namekey,val);}
            when'Bill_Time__c'{cl.put(namekey,Integer.valueOf(val));}
            when'Call_Type__c'{cl.put(namekey,val);}
            when'Contact_Type__c'{cl.put(namekey,val);}
            when'Contact_Type_2__c'{cl.put(namekey,val);}
            when'Campaign__c'{cl.put(namekey,val);}
            when'Contact_Record_Date_Time__c'{
                cl.put(namekey,datemaker(val));
            }
            when'Contact_Record_Last_Modified_Date_Time__c'{
                cl.put(namekey,datemaker(val));
            }
            when'Disposition__c'{cl.put(namekey,val);}
            when'Disposition2__c'{cl.put(namekey,val);}
            when'DNIS__c'{cl.put(namekey,val);}
            when'Email__c'{cl.put(namekey,val);}
            when'First_Agent__c'{cl.put(namekey,val);}
            when'Handle_Time__c'{cl.put(namekey,Integer.valueOf(val));}
            when'Hold_Time__c'{cl.put(namekey,Integer.valueOf(val));}
            when'Last_Agent__c'{cl.put(namekey,val);}
            when'Last_Campaign__c'{cl.put(namekey,val);}
            when'Last_Dispo_Time__c'{
                cl.put(namekey,datemaker(val));
            }
            when'Last_Dispo__c'{cl.put(namekey,val);}
            when'Lead_Status__c'{cl.put(namekey,val);}
            when'Length__c'{cl.put(namekey,Integer.valueOf(val));}
            when'Original_Itc__c'{cl.put(namekey,val);}
            when'Park_Time__c'{cl.put(namekey,Integer.valueOf(val));}
            when'Queue_Time__c'{cl.put(namekey,Integer.valueOf(val));}
            when'Salesforce_Id__c'{cl.put(namekey,Id.valueOf(val.toString()));}
            when'Start_Timestamp__c'{cl.put(namekey,datemaker(val));}
            when'End_Timestamp__c'{cl.put(namekey,datemaker(val));}
            when'Wrapup_Time__c'{cl.put(namekey,Integer.valueOf(val));}
            when'Name'{cl.put(namekey,val);}
            when'Mediatype__c'{cl.put(namekey,val);}
            when'Skill_Name__c'{cl.put(namekey,val);}
            when'Session_Id__c'{cl.put(namekey,val);}
            when'Last_Module__c'{cl.put(namekey,val);}
            when'Last_Campaign_Attempts__c'{cl.put(namekey,Integer.valueOf(val));}
            when'Last_List__c'{cl.put(namekey,val);}
            when'Station_Id__c'{cl.put(namekey,val);}
            when'Last_Skill_Name__c'{cl.put(namekey,val);}
            when'Last_State__c'{cl.put(namekey,val);}
            when'Type__c'{cl.put(namekey,val);}
            when'VM__c'{cl.put(namekey,val);}
            when'Start_Time__c'{cl.put(namekey,val);}
            when'Queue_Callback_Ani__c'{cl.put(namekey,val);}
            when'Third_Party_Connected__c'{cl.put(namekey,val);}
            when else{
                System.debug('miss on typesetter: on namekey: '+namekey);

            }
        }
    }
    public static final Map<String,String>nameMap=new Map<String,String>{
            'first_agent'=>'First_Agent__c',
            'user_name'=>'Agent__c',
            'ANI'=>'ANI__c',
            'bill_time'=>'Bill_Time__c',
            'call_id'=>'Name',
            'type_name'=>'Call_Type__c',
            'campaign_name'=>'Campaign__c',
            'Contact_Record_Date_Time'=>'Contact_Record_Date_Time__c',
            'Contact_Record_Last_Modified_Date_Time'=>'Contact_Record_Last_Modified_Date_Time__c',
            'Contact Type2'=>'Contact_Type_2__c',
            'contactType'=>'Contact_Type__c',
            'DNIS'=>'DNIS__c',
            'end_timestamp'=>'End_Timestamp__c',
            'handle_time'=>'Handle_Time__c',
            'hold_time'=>'Hold_Time__c',
            'length'=>'Length__c',
            'park_time'=>'Park_Time__c',
            'start_timestamp'=>'Start_Timestamp__c',
            'wrapup_time'=>'Wrapup_Time__c',
            'queue_time'=>'Queue_Time__c',
            'disposition_name'=>'Disposition__c',
            'Disposition'=>'Disposition2__c',
            'email'=>'Email__c',
            'Last_Agent'=>'Last_Agent__c',
            'Last_Campaign'=>'Last_Campaign__c',
            'Last_Contact_Date'=>'Last_Contact_Date__c',
            'Last_Dispo'=>'Last_Dispo__c',
            'Lead_Status'=>'Lead_Status__c',
            'salesforce_id'=>'Salesforce_Id__c',
            'Last_Dispo_Time'=>'Last_Dispo_Time__c',
            'original_itc'=>'Original_Itc__c',
            'mediatype'=>'Mediatype__c',
            'skill_name'=>'Skill_Name__c',
            'session_id'=>'Session_Id__c',
            'last_module'=>'Last_Module__c',
            'f9_last_campaign_attempts'=>'Last_Campaign_Attempts__c', //integer
            'f9_last_list'=>'Last_List__c',
            'station_id'=>'Station_Id__c',
            'last_skill_name'=>'Last_Skill_Name__c',
            'last_state'=>'Last_State__c',
            'type'=>'Type__c',
            'VM'=>'VM__c',
            'start_time'=>'Start_Time__c',
            'queue_callback_ani'=>'Queue_Callback_Ani__c',
            '3rdPartyConnected'=>'Third_Party_Connected__c'

    };
    public static Datetime datemaker(String val){
        Datetime dt;
        if(val.length()>=14){
            Integer year=Integer.valueOf(val.left(4));
            Integer month=Integer.valueOf(val.mid(4,2));
            Integer day=Integer.valueOf(val.mid(6,2));
            Integer hour=Integer.valueOf(val.mid(8,2));
            Integer min=Integer.valueOf(val.mid(10,2));
            Integer sec=Integer.valueOf(val.mid(12,2));
            dt=Datetime.newInstanceGmt(year,month,day,hour,min,sec);
        }
        return dt;
    }
}