/**
 * Created by noahr on 6/3/2024.
 */

public with sharing class LeadFormHelper {

    public static Boolean CheckForAddress(String sStreet, String sCity, String sCountry, String sState, String sPostalCode){

        if(String.isBlank(sStreet) || String.isBlank(sCity) || String.isBlank(sCountry) || String.isBlank(sState) || String.isBlank(sPostalCode)){
            return false;
        }
        return true;
    }

}