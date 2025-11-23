/**
 * Created by noahr on 5/6/2024.
 */

global class Callout {

    private static final Integer DEFAULT_TIMEOUT = 10000;
    public Callout(String jsonString,
            String endpoint,
            String method,
            Map<String,String> headers,
            Integer millisecondTimeout) {
        this.bodyString = jsonString;
        this.endpoint = endpoint;
        this.method = method;
        this.headers = headers;
        this.timeout = millisecondTimeout;
    }
    public Callout(Blob audioFile,
            String endpoint,
            String method,
            Map<String,String> headers,
            Integer millisecondTimeout) {
        this.bodyBlob = audioFile;
        this.endpoint = endpoint;
        this.method = method;
        this.headers = headers;
        this.timeout = millisecondTimeout;
    }
    public Callout(String jsonString, String endpoint, String method,Map<String,String> headers) {
        this(jsonString, endpoint, method, headers, DEFAULT_TIMEOUT);
    }
    public Callout(Blob audioFile, String endpoint, String method,Map<String,String> headers) {
        this(audioFile, endpoint, method, headers, DEFAULT_TIMEOUT);
    }

    public static Map<String,String> setHeader(String key, String value) {
        Map<String,String> header = new Map<String, String>{key => value};
        return header;
    }

    // sometimes an api key is supplied as part of the URL...
    // because it's not always necessary, we make it a public member of the class
    public String apiKey { get; set; }
    public Map<String,String> headers { get; set; }
    public String bodyString { get; private set; }
    public String endpoint { get; private set; }
    public String method { get; private set; }
    public Integer timeout { get; private set; }
    public String boundary { get; set; }
    public Blob bodyBlob { get; set; }

}