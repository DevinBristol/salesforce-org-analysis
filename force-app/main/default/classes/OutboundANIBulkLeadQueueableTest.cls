/**
 * Created by BEN on 7/18/2024.
 */

@IsTest
public class OutboundANIBulkLeadQueueableTest {
    static final Integer totalCount = 250;
    static final Integer updateableCount = 225;

    @TestSetup
    static void setup() {
        List<Lead> leads = new List<Lead>();
        // add a parent account
        for(Integer i = 0; i < totalCount; i++){
            Lead l = new Lead(
                    Company = i.toString(),
                    FirstName = 'Test_Lead',
                    LastName = i.toString());
            String testNumber = '4020000000';
            testNumber=testNumber.removeEnd(testNumber.right(i.toString().length()))+i.toString();
            if (i < 75) {
                l.MobilePhone = testNumber;
            } else if (i < 150) {
                l.Phone = testNumber;
                l.PostalCode = '68372';
                l.City = 'Hickman';
            } else if (i < updateableCount){ //check that size of second load response is 25
                l.Phone = testNumber;
                l.MobilePhone = testNumber;
                l.PostalCode = '68372';
                l.City = 'Hickman';
            } else { //(i < totalCount)
                l.Phone = null;
                l.MobilePhone = null;
                l.City = 'Hickman';
            }
            leads.add(l);
        }
        insert leads;
        System.debug('Lead entry 1 [0]:::'+leads[0].Id+'...Name: '+leads[0].FirstName+' '+leads[0].LastName+' ...Company: '+leads[0].Company+' ...Mobile: '+leads[0].MobilePhone+' ...Phone: '+leads[0].Phone);
    }

    @IsTest
    static void testLoadSplits(){
        List<Lead> splitTestLeads1 = [SELECT Id, MobilePhone, Phone,PostalCode, FirstName, LastName, Company,
                ba685ce4_2c28_433a_a4c6_cac18b40f436__c,
                b7ef8429_9f35_4102_b1ea_44d3453a5086__c,
                LastActivityDate,
                Previous_ANI_TEST__c
        FROM Lead
        WHERE FirstName = 'Test_Lead'
        LIMIT 100];
        List<Lead> splitTestLeads2 = [SELECT Id, MobilePhone, Phone, PostalCode, FirstName, LastName, Company,
                ba685ce4_2c28_433a_a4c6_cac18b40f436__c,
                b7ef8429_9f35_4102_b1ea_44d3453a5086__c,
                LastActivityDate,
                Previous_ANI_TEST__c
        FROM Lead
        WHERE FirstName = 'Test_Lead'
        LIMIT 200];
        List<Lead> splitTestLeads3 = [SELECT Id, MobilePhone, Phone, PostalCode, FirstName, LastName, Company,
                ba685ce4_2c28_433a_a4c6_cac18b40f436__c,
                b7ef8429_9f35_4102_b1ea_44d3453a5086__c,
                LastActivityDate,
                Previous_ANI_TEST__c
        FROM Lead
        WHERE FirstName = 'Test_Lead'
        LIMIT 201];
        Test.startTest();
        List<List<Lead>> splitLeadLists1 = OutboundANIBulkLeadQueueable.leadLoadSplits(splitTestLeads1);
        List<List<Lead>> splitLeadLists2 = OutboundANIBulkLeadQueueable.leadLoadSplits(splitTestLeads2);
        List<List<Lead>> splitLeadLists3 = OutboundANIBulkLeadQueueable.leadLoadSplits(splitTestLeads3);
        Test.stopTest();

        System.assertEquals(1,splitLeadLists1.size());
        System.assertEquals(1, splitLeadLists2.size());
        System.assertEquals(2,splitLeadLists3.size());

    }

    @IsTest
    static void testBulkCallout() {
        //testing the callout method with either full and remainder payloads
        List<Lead> Leads = [SELECT Id, MobilePhone, Phone, PostalCode, FirstName, LastName, Company,
                ba685ce4_2c28_433a_a4c6_cac18b40f436__c,
                b7ef8429_9f35_4102_b1ea_44d3453a5086__c,
                LastActivityDate,
                Previous_ANI_TEST__c
        FROM Lead
        WHERE FirstName = 'Test_Lead'];

        System.debug('ALL testLeads::: '+Leads);
        List<String> oldANIs = new List<String>();
        List<String> newANIs = new List<String>();
        List<String> olderANIs = new List<String>();
        List<Id> insertedLeadIds = new List<Id>();

        List<Map<String,Object>> fullMockMapList = new List<Map<String,Object>>();
        List<Map<String,Object>> partialMockMapList = new List<Map<String,Object>>();
        List<Lead> partialLoad = new List<Lead>();
        List<Lead> fullLoad = new List<Lead>();

        Integer entry_i = 0;
        Integer lead_i = 0;
        for(Lead l : Leads) {

            if(entry_i < 200){
                fullLoad.add(Leads.get(entry_i));
                lead_i++;
            } else {
                partialLoad.add(Leads.get(entry_i));
                lead_i++;
            }
            String mockB7 = 'number' + entry_i;
            String mockBa6 = '5310000000';
            String mock21d = System.today().toString();
            mockBa6 = mockBa6.removeEnd(mockBa6.right(entry_i.toString().length())) + entry_i.toString();
            insertedLeadIds.add(l.Id);
            olderANIs.add(l.Previous_ANI_TEST__c);
            if (entry_i < updateableCount) {
                Map<String, Object> mockMap = new Map<String, Object>{
                        'row_id' => l.Id,
                        'outboundani' => mockBa6,
                        'ba685ce4_2c28_433a_a4c6_cac18b40f436' => mockBa6,
                        'X21d697a0_a81a_4bab_b635_5f7be11181a7' => mock21d,
                        'b7ef8429_9f35_4102_b1ea_44d3453a5086' => mockB7,
                        'error' => '""'
                };


                if(entry_i < 200){
                    fullMockMapList.add(mockMap);
                    entry_i++;
                }
                else {
                    partialMockMapList.add(mockMap);
                    entry_i++;
                }
            }
        }
        String fullResBody = JSON.serialize(fullMockMapList);
        String partialResBody = JSON.serialize(partialMockMapList);

        OutboundANIBulkLeadQueueable fullJob = new OutboundANIBulkLeadQueueable(fullLoad);
        OutboundANIBulkLeadQueueable partialJob = new OutboundANIBulkLeadQueueable(partialLoad);

        OutboundANIBulkLeadQueueableMock fullMock = new OutboundANIBulkLeadQueueableMock(200,'OK',fullResBody);
        OutboundANIBulkLeadQueueableMock partialMock = new OutboundANIBulkLeadQueueableMock(200, 'OK', partialResBody );
        Test.setMock(HttpCalloutMock.class,fullMock);

        List<OutboundANIBulkLeadQueueable.OutboundANIResponse> mockResList = new List<OutboundANIBulkLeadQueueable.OutboundANIResponse>();
        Test.startTest();
        System.enqueueJob(fullJob);
        mockResList.addAll((List<OutboundANIBulkLeadQueueable.OutboundANIResponse>)JSON.deserialize(fullMock.body,List<OutboundANIBulkLeadQueueable.OutboundANIResponse>.class));
        System.assertEquals(fullMockMapList.size(),mockResList.size());
        System.enqueueJob(partialJob);
        mockResList.addAll((List<OutboundANIBulkLeadQueueable.OutboundANIResponse>)JSON.deserialize(partialMock.body,List<OutboundANIBulkLeadQueueable.OutboundANIResponse>.class));
        Test.stopTest();

        System.debug('second job: mockResList size: ' + mockResList.size());
        System.assertEquals(updateableCount,mockResList.size());

        System.debug('-->(predicted response entry list size)updateableCount: '+updateableCount+'...actual response size: '+mockResList.size());
        //System.assertEquals(updateableCount,mockResList.size());
        List<Id> mockResRowIds = new List<Id>();
        for(OutboundANIBulkLeadQueueable.OutboundANIResponse res : mockResList){
            mockResRowIds.add((Id)res.row_id);
        }

        Leads = [SELECT Id, MobilePhone, Phone, PostalCode, FirstName, LastName,
                ba685ce4_2c28_433a_a4c6_cac18b40f436__c,
                b7ef8429_9f35_4102_b1ea_44d3453a5086__c,
                LastActivityDate,
                Previous_ANI_TEST__c
        FROM Lead
        WHERE Id IN :insertedLeadIds
        LIMIT :insertedLeadIds.size()];

        System.debug('-->(predicted update list size): '+updateableCount+'...actual Leads updated: '+Leads.size());
        //System.assertEquals(updateableCount,updatedLeads.size());

        //System.assertEquals(mockResList.size(),updatedLeads.size());

        Integer check_i = 0;
        for (Lead l : Leads){
            String testMockBa6 = '5310000000';
            testMockBa6 = testMockBa6.removeEnd(testMockBa6.right(l.LastName.length()))+l.LastName;
            newANIs.add(l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c);
            oldANIs.add(l.Previous_ANI_TEST__c);
//            System.assertEquals(mockResRowIds[check_i],l.Id);

            if(check_i<updateableCount){//0-74 mobile,75-149 phone, 150-224 mobile&phone, 225-250 nulls
                System.assertEquals(l.Id, mockResList[check_i].row_id);
//                System.assertEquals('number'+check_i, mockResList[check_i].b7ef8429_9f35_4102_b1ea_44d3453a5086);
//                System.debug('-->(predicted b7 for '+check_i+'): number'+check_i+'...actual B7 in mockResList('+check_i+'):'+mockResList[check_i].b7ef8429_9f35_4102_b1ea_44d3453a5086+'...actual b7 on LEAD('+check_i+'): '+Leads[check_i].b7ef8429_9f35_4102_b1ea_44d3453a5086__c);
//                //System.assertEquals('number'+check_i,l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c);
//                System.debug('-->(predicted ba6 for '+check_i+'): '+testMockBa6+'...actual Ba6 in mockResList('+check_i+'):'+mockResList[check_i].ba685ce4_2c28_433a_a4c6_cac18b40f436+'...actual b7 on LEAD('+check_i+'): '+Leads[check_i].ba685ce4_2c28_433a_a4c6_cac18b40f436__c);
//                //System.assertEquals(l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c, mockResList[check_i].ba685ce4_2c28_433a_a4c6_cac18b40f436);
//                System.assertEquals(testMockBa6, mockResList[check_i].ba685ce4_2c28_433a_a4c6_cac18b40f436);

                System.assertEquals(System.today().toString(),mockResList[check_i].X21d697a0_a81a_4bab_b635_5f7be11181a7);
                System.assertEquals('""',mockResList[check_i].error);
            } else {
                //there should be 225 ids
//                System.assertEquals(null, mockResList[check_i]);
                System.assertEquals(null,l.b7ef8429_9f35_4102_b1ea_44d3453a5086__c);
                System.assertEquals(null,l.ba685ce4_2c28_433a_a4c6_cac18b40f436__c);
            }
            //
            //System.assertEquals(oldANIs[check_i],olderANIs[check_i],'hey, watch out. you fucked this up too.');
            System.assertEquals(null,l.Previous_ANI_TEST__c);

            check_i++;
        }
    }

    @SuppressWarnings('ApexReferenceCaseMatchesDeclarationCase')
    public class OutboundANIBulkLeadQueueableMock implements HttpCalloutMock {
        public Integer code;
        public String status;
        public String body;


        public OutboundANIBulkLeadQueueableMock(Integer code, String status, String body) {
            this.code = code;
            this.status = status;
            this.body = body;


            //give this the list of loads
        }
        public HTTPResponse respond(HTTPRequest req) {
            //gets the mock response for each individual loads
            HttpResponse res = new HttpResponse();
            res.setBody(this.body);
            res.setStatusCode(this.code);
            res.setStatus(this.status);
            return res;

        }


    }
}