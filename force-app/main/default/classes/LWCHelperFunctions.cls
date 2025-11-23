/**
 * Created by noahr on 10/29/2024.
 */

public with sharing class LWCHelperFunctions {
    @AuraEnabled(Cacheable=true)
    public static String GetCurrentDomain(){
        String baseUrl = Url.getOrgDomainUrl().toExternalForm();
        System.debug(baseUrl);
        return baseUrl;
    }
}