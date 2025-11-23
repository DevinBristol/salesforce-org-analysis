/**
 * Created by noahr on 5/16/2024.
 */

public class MultiRequestFive9Mocks implements HttpCalloutMock{
    Map<String,HttpCalloutMock> requests;

    public MultiRequestFive9Mocks(Map<String,HttpCalloutMock> requests){
        this.requests = requests;
    }

    public HttpResponse respond(HttpRequest req){
        HttpCalloutMock mock = requests.get(req.getEndpoint());
            if(mock != null){
                return mock.respond(req);
            } else{
                //debug here, problem for future Noah tbh
                return mock.respond(req);
            }
    }

//    public void addRequestMock(String url, HttpCalloutMock mock){
//        requests.put(url,mock);
//    }

}