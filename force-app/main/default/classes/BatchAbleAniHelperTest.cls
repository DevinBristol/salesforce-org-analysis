/**
 * Created by benra on 7/29/2025.
 */

@IsTest
public class BatchAbleAniHelperTest{
    @IsTest
    static void testQueueableWithLeads(){
        List<Lead> leads=new List<Lead>();
        for (Integer i=0;i<3;i++){
            leads.add(new Lead(FirstName = 'Test', LastName = 'User' + i, Company = 'Test Company'));
        }
        insert leads;
        for(Lead l : leads){l.Company = 'Updated Company'; }
        Test.startTest();
        System.enqueueJob(new BatchAbleAniHelper(leads));
        Test.stopTest();
        List<Lead>updatedLeads=[SELECT Id, Company FROM Lead WHERE Id IN :leads];
        for (Lead l:updatedLeads){
            System.assertEquals('Updated Company', l.Company, 'Lead company should be updated');
        }
    }
}