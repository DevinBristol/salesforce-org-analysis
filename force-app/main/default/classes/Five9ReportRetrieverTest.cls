/**
 * Created by Ben on 9/5/2025.
 */
@IsTest
public with sharing class Five9ReportRetrieverTest {
    @IsTest
    static void testRunReportSuccess() {
        String mockRes=
                '<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">' +
                '  <env:Body>' +
                '    <ns2:runReportResponse xmlns:ns2="http://service.admin.ws.five9.com/">' +
                '      <return>xReportId</return>' +
                '    </ns2:runReportResponse>' +
                '  </env:Body>' +
                '</env:Envelope>';
        Test.setMock(HttpCalloutMock.class,new MockHttpResponse(200,'OK',mockRes));
        String startString=Datetime.newInstance(2020,5,1,0,0,0).format();
        String endString=Datetime.newInstance(2020,5,10,23,0,0).format();
        String reportIdString=Five9ReportRetriever.runReportRequest(endString,startString,'Call Logs','Call Logs Expanded');
        System.assertEquals('xReportId',reportIdString,'identifier field has gotta parse');
    }

    @IsTest
    static void testIsReportRunning_false() {
        String mockRes =
                '<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">' +
                        '  <env:Body>' +
                        '    <ns2:isReportRunningResponse xmlns:ns2="http://service.admin.ws.five9.com/">' +
                        '      <return>false</return>' +
                        '    </ns2:isReportRunningResponse>' +
                        '  </env:Body>' +
                        '</env:Envelope>';
        Test.setMock(HttpCalloutMock.class,new MockHttpResponse(200,'OK',mockRes));
        Boolean running=Five9ReportRetriever.isReportRunningRequest('hooray');
        System.assertEquals(false,running,'Get your finger between the damn return tags. <return>false</return>');
    }

    @IsTest
    static void testGetReportResultCsvSuccess() {
        String mockRes=
                '<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">' +
                '  <env:Body>' +
                '    <ns2:getReportResultCsvResponse xmlns:ns2="http://service.admin.ws.five9.com/">' +
                '      <return>CALL ID count,Other\r\n1,2</return>' +
                '    </ns2:getReportResultCsvResponse>' +
                '  </env:Body>' +
                '</env:Envelope>';
        Test.setMock(HttpCalloutMock.class,new MockHttpResponse(200,'OK',mockRes));
        String csv=Five9ReportRetriever.getReportResultCsvRequest('good');
        System.debug('\nrawCSV->\n'+csv);
    }
    @IsTest
    static void testErrors_bubble() {
        Test.setMock(HttpCalloutMock.class,new MockHttpResponse(500,'IDIOT','YOU STOOGE'));
        try {
            Five9ReportRetriever.isReportRunningRequest('x');
            System.assert(false,'Should have thrown');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('isReportRunning failed'));
        }
    }

}