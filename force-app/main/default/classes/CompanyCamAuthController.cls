/**
 * Created by Devin on 1/30/2025.
 */
@RestResource(urlMapping ='/CompanyCamAuth')
global without sharing class CompanyCamAuthController {
    private static final String CLIENT_ID = 'mz4ATCzfXwiNSFkyASLp7SUXJqieVcrUrfQ7';
    private static final String REDIRECT_URI = System.Url.getOrgDomainUrl().toString().replace('.com','-sites.com')+'/webhooks/services/apexrest/CompanyCamAuth';
    private static final String AUTH_URL = 'https://app.companycam.com/oauth/authorize';

    @HttpGet
    global static void handleAuthCallback() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        System.debug(req.params.toString().substringAfter('code=').substringBefore('}'));
        String code = req.params.toString().substringAfter('code=').substringBefore('}');
        System.debug(code);
        if (code == null) {
            res.responseBody = Blob.valueOf('Error: No authorization code received.');
            return;
        }
//         Exchange Authorization Code for Access Token
        String accessToken = CompanyCamAuthService.getAccessToken(code);
        if (accessToken == null) {
            res.responseBody = Blob.valueOf('Error: Failed to retrieve access token.');
            return;
        }
        res.responseBody = Blob.valueOf('Success! Access token retrieved.');
    }
    public static String getAuthorizationUrl() {
        return AUTH_URL + '?client_id=' + CLIENT_ID +
                '&redirect_uri=' + REDIRECT_URI +
                '&response_type=code&scope=read+write+destroy';
    }
    @InvocableMethod(label='Add Outside Sales Users' description='Add Outside Sales Users')
    public static void AddCompanyCamUserFromOpportunity(List<Id> opIds){
        Opportunity Op = [SELECT Id,companycam__ProjectID__c,(SELECT Id,UserId,TeamMemberRole FROM OpportunityTeamMembers) FROM Opportunity WHERE Id IN :opIds LIMIT 1];
        CompanyCamAPI api = new CompanyCamAPI();
        List<String> CompanyCamUserIds = CompanyCamAPI.GetUserCompanyCamIds(Op.OpportunityTeamMembers);
        for (String CompanyCamUserId : CompanyCamUserIds){
            api.PutCompanyCamUsers(Op.companycam__ProjectID__c,CompanyCamUserId);
        }
    }

}