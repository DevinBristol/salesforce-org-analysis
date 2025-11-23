/**
 * Created by noahr on 5/6/2024.
 */

@IsTest
global with sharing class HttpCalloutTests {
    @IsTest
    static void it_should_properly_stub_response() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, 'Success', '{}'));
        HttpResponse res = HttpCallout.makeRequest(new HttpRequest());
        System.assertEquals(200, res.getStatusCode());
    }

    @IsTest
    static void it_should_callout_successfully() {
        String key = 'key';
        String value = 'value';
        Map<String,String> headers = new Map<String,String>{key => value};
        Callout fakeCallout = new Callout('{parameter1: perhaps a serialized list or id!}', 'https://api.com', 'POST',headers);
        String jsonString = JSON.serialize(fakeCallout);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, 'Success', '{}'));

        Test.startTest();
        HttpCallout.process(jsonString);
        Test.stopTest();

        System.assert(true, 'should make it here!');
    }

    @IsTest
    static void it_should_callout_successfully2() {
        String Testkey = 'key';
        String Testvalue = 'value';
        Blob blobvalue = Blob.valueOf('TestBlob');

        Map<String,String> header = Callout.setHeader(Testkey,Testvalue);

        Callout fakeCallout = new Callout(blobvalue, 'https://api.com', 'POST',header);
        String jsonString = JSON.serialize(fakeCallout);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, 'Success', '{}'));

        Test.startTest();
        HttpCallout.process(jsonString);
        Test.stopTest();
        System.assert(true, 'should make it here!');
        System.assertEquals(fakeCallout.headers, header, 'headers not assigned');

    }

}