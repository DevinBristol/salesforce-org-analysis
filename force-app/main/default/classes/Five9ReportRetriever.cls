/**
 * Created by Ben on 9/4/2025.
 */

public class Five9ReportRetriever {
    private static final String ENDPOINT='callout:Five9_AdminWebService';
    private static HttpResponse sendSoapRequest(String action,String bodyContent){
        HttpRequest req=new HttpRequest();
        req.setEndpoint(ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type','text/xml; charset=UTF-8');
        req.setHeader('SOAPAction',action);
        String envelope =
            '<?xml version="1.0" encoding="UTF-8"?>'+
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ser="http://service.admin.ws.five9.com/">'+
                '<soapenv:Header/>'+
                '<soapenv:Body>'+bodyContent+'</soapenv:Body>'+
            '</soapenv:Envelope>';
        req.setBody(envelope);
        Http http=new Http();
        return http.send(req);
    }
    public static String runReportRequest(String endString,String startString,String folderName,String reportName){
        String bodyContent=
                '<ser:runReport>'+
                    '<folderName>'+folderName+'</folderName>'+
                    '<reportName>'+reportName+'</reportName>'+
                    '<criteria>'+
                        '<time>'+
                            '<end>'+endString+'</end>'+
                            '<start>'+startString+'</start>'+
                        '</time>'+
                    '</criteria>'+
                '</ser:runReport>';
        HttpResponse res=sendSoapRequest('runReport',bodyContent);
        System.debug('\r\rReport Request Response:\r'+JSON.serializePretty(res.getBody()));
        if(res.getStatusCode()!=200){
            throw new CalloutException('runReport DIDNT GO! '+res.getStatus()+'\n'+res.getBody());
        }
        String reportId=res.getBody().substringBetween('<return>','</return>');
        System.debug('\r\r\t—reportId–> '+reportId);
        return reportId;
    }
    public static Boolean isReportRunningRequest(String identifier){
        String bodyContent=
                '<ser:isReportRunning>' +
                        '<identifier>'+identifier+'</identifier>' +
                '</ser:isReportRunning>';
        HttpResponse res=sendSoapRequest('isReportRunning',bodyContent);
        System.debug('\r\rReport Polling Response:\r'+res.getBody());

        if(res.getStatusCode()!=200){
            throw new CalloutException('isReportRunning failed: '+res.getStatus()+ '\n'+res.getBody());
        }
        Dom.Document doc=res.getBodyDocument();
        Dom.XmlNode payload=payloadNode(doc);
        Boolean answerXml;
        String answer=res.getBody().substringBetween('<return>','</return>');
        System.debug('\r\r\t—answer–> '+answer);
        if(payload!=null){
            Dom.XmlNode returnNode=childByLocal(payload,'return');
            answerXml=Boolean.valueOf(returnNode.getText());
            System.debug('\r\r\t—answerXml–> '+answerXml);
        }
        // YOU DUMBASS. WE WANTED FALSE. THIS WAS USELESS TO MAKE.
        return Boolean.valueOf(answer);
    }
    public static String getReportResultCsvRequest(String identifier){
        String bodyContent =
                '<ser:getReportResultCsv>'+
                        '<identifier>'+identifier+'</identifier>'+
                '</ser:getReportResultCsv>';
        HttpResponse res=sendSoapRequest('getReportResultCsv',bodyContent);
        String body;
        if(res.getStatusCode()!=200){
            throw new CalloutException('getReportResultCsv failed: '+res.getStatus()+ '\n'+res.getBody());
        }
        Dom.Document doc=res.getBodyDocument();
        Dom.XmlNode payload=payloadNode(doc);
        if(payload!=null){
            Dom.XmlNode rawCsv=childByLocal(payload,'return');
            if(rawCsv!=null){ // getText() fucks up newlines for csv,so we gotta go join child text nodes(if any)or fallback to getText()
                String val='';
                if(!rawCsv.getChildElements().isEmpty()){
                    val=rawCsv.getText();
                } else {
                    val=rawCsv.getText();//.escapeCsv();
                }
                body=val.trim();
            }
        }
        return body; //result.rawCsv=res.getBody().substringBetween('<return>','</return>');
    }
    private static Dom.XmlNode childByLocal(Dom.XmlNode parent,String localName){
        Dom.XmlNode localMatch; //this is gonna be the first childnode(with namespace chopped) whose name=the param
        for(Dom.XmlNode c:parent.getChildElements()){
            String q=c.getName();
            if(q==localName||(q!=null&&q.endsWith(':'+localName))){
                localMatch=c;
            }
        }
        return localMatch;
    }
    //gets right into envelope then body then whatever the payloadnode's named
    private static Dom.XmlNode payloadNode(Dom.Document doc){
        Dom.XmlNode payload;
        Dom.XmlNode env=doc.getRootElement();
        if(env!=null){
            Dom.XmlNode body=childByLocal(env,'Body');
            if(body!=null){
                List<Dom.XmlNode>kids=body.getChildElements();
                if(!kids.isEmpty()){
                    payload=kids[0];
                }
            }
        }
        return payload;
    }
}

//numeric
//{
//                    "description": "",
//                    "fullyQualifiedName": "SalesData.Amount",
//                    "label": "Opportunity Amount",
//                    "name": "Amount",
//                    "isSystemField": false,
//                    "defaultValue": "0",
//                    "isUniqueId": false,
//                    "type": "Numeric",
//                    "precision": 10,
//                    "scale": 2,
//                },
//date
//{
//                    "description": "",
//                    "fullyQualifiedName": "SalesData.CloseDate",
//                    "label": "Opportunity Close Date",
//                    "name": "CloseDate",
//                    "isSystemField": false,
//                    "isUniqueId": false,
//                    "type": "Date",
//                    "format": "MM/dd/yyyy",
//                    "fiscalMonthOffset": 0
//                }