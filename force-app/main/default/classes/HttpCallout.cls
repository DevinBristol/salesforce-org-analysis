/**
 * Created by noahr on 5/6/2024.
 */

global class HttpCallout {

    public static HttpResponse process(String calloutString,Boolean isFile) {
        System.debug(isFile);

        Callout calloutObj = (Callout)JSON.deserialize(calloutString, Callout.class);
        HttpRequest req = new HttpRequest();
        req = setupHttpRequest(calloutObj,isFile);

        HttpResponse res = makeRequest(req);
        return res;
    }
    public static HttpResponse process(String calloutString,Boolean isFile,Blob audioFile) {
        System.debug(isFile);

        Callout calloutObj = (Callout)JSON.deserialize(calloutString, Callout.class);
        calloutObj.bodyBlob = audioFile;
        HttpRequest req = new HttpRequest();
        req = setupHttpRequest(calloutObj,isFile);

        HttpResponse res = makeRequest(req);
        return res;
    }

    public static HttpResponse process(String calloutString){
        Callout calloutObj = (Callout)JSON.deserialize(calloutString, Callout.class);
        HttpRequest req = new HttpRequest();
        req = setupHttpRequest(calloutObj,false);

        HttpResponse res = makeRequest(req);
        return res;
    }

    private static HttpRequest setupHttpRequest(Callout callout,Boolean isFile) {
        System.debug(isFile);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(callout.endpoint);
        req.setMethod(callout.method);
        req.setTimeout(callout.timeout);

        if(isFile == true){
            req.setBodyAsBlob(callout.bodyBlob);
            System.debug(req.getBodyAsBlob());
        } else if(String.isNotBlank(callout.bodyString)){
            req.setBody(callout.bodyString);
        }
        if (callout.headers.size() != 0){
            for(String headerKey : callout.headers.keySet()) {
                req.setHeader(headerKey, callout.headers.get(headerKey));
            }
        }
        if(String.isNotBlank(callout.apiKey)) {
            req.setHeader('x-api-key', callout.apiKey);
        }
        return req;
    }

    @TestVisible
    private static HttpResponse makeRequest(HttpRequest req) {
        System.debug(req);
        HttpResponse res = new Http().send(req);
        return res;
    }

}