/**
 * Created by Devin on 5/15/2024.
 */

global class OrgSettings {
    public static String getFive9MediaProviderId(){
        String Five9MediaProviderId;
        if(System.Url.getOrgDomainUrl().toString().contains('Full')){
            Five9MediaProviderId = '0hnVB000000018zYAA';
        } else {
            Five9MediaProviderId = '0hnR700000000T3IAI';
        }
        return Five9MediaProviderId;
    }
}