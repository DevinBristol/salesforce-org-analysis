/**
 * Created by Devin on 2/7/2025.
 */

global class RefreshCompanyCamTokenJob implements Schedulable {
    global void execute(SchedulableContext SC) {
        // Retrieve stored refresh token (from Custom Metadata, Custom Setting, etc.)
        String storedRefreshToken = Company_Cam_Bearer_Token__c.getInstance(UserInfo.getProfileId()).RefreshToken__c;

        // Refresh token
        Map<String,String> tokens = CompanyCamAuthService.refreshAccessToken(storedRefreshToken);
        if (tokens != null) {
            // Store new tokens securely (e.g., in Custom Metadata)
            System.debug('New Access Token: ' + tokens.get('access_token'));
            System.debug('New Refresh Token: ' + tokens.get('refresh_token'));
        }
    }
}