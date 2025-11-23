/**
 * Created by noahr on 5/6/2024.
 */

global class MockHttpResponse implements HttpCalloutMock {
    private final Integer code;
    private final String status;
    private final String body;
    private final Blob bodyBlob;
    private final Map<String,Object> bodyMap;

    public MockHttpResponse(Integer code, String status, String body) {
        this.code = code;
        this.status = status;
        this.body = body;
    }
    public MockHttpResponse(Integer code, String status, Blob bodyBlob){
        this.code = code;
        this.status = status;
        this.bodyBlob = bodyBlob;
    }
    public MockHttpResponse(Map<String,Object> bodyMap){
        this.bodyMap = bodyMap;
        this.code=200;
        this.status='success';
    }

    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();

        if(this.body != null) {
            res.setBody(this.body);
        }
        if(this.bodyBlob != null){
            res.setBodyAsBlob(this.bodyBlob);
        }
        if(this.bodyMap!=null){
            res.setBody(JSON.serialize(this.bodyMap));
        }
        res.setStatusCode(this.code);
        res.setStatus(this.status);
        return res;
    }
}