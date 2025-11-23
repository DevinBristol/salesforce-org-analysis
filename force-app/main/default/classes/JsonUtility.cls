/**
 * Created by Devin on 5/9/2024.
 */

public class JsonUtility {

    public static String ParseByToken(String body, String tokenName){
        String returnValue;
        JSONParser parser = JSON.createParser(body);

        while(parser.nextToken() != null){
            if(parser.getCurrentToken() == JSONToken.FIELD_NAME && parser.getText() == tokenName){
                parser.nextToken();
                returnValue = parser.getText();
            }
        }
        return returnValue;
    }
    //Alternative JsonParser that goes until {{tokenBreak}} is found...
    public static String ParseByTokenUntil(String body, String tokenName, String tokenBreak){
        String returnValue;
        JSONParser parser = JSON.createParser(body);

        while (parser.nextToken() != null && parser.getText() != tokenBreak) {
            if (parser.getCurrentToken() == JSONToken.FIELD_NAME && parser.getText() == 'id'){
                parser.nextToken();
                returnValue = parser.getText();
            }
        }
        return returnValue;
    }
//    public static List<Property__c> ParseBySFMapsResponse(String body,String matchTopic){
//        List<Property__c> updateableProperties = new List<Property__c>();
//        String value;
//        String empt = '';
//        String z = '0';
//        JSONParser parser = JSON.createParser(body);
//        Property__c prop = new Property__c();
//        System.debug(SfMapsRetriever.keyMap);
//        System.debug(JSON.serializePretty(SfMapsRetriever.keyMap));
//        Integer matchTopicStart=body.indexOf(matchTopic);
//
//        while(parser.nextToken() != null){
//            switch on parser.getText() {
//
//                when 'value'{
//                    parser.nextToken();
//                    value = parser.getText();
//                    if (value == 'null') {
//                        value = null;
//                    }
//                }
//                when 'topic_id'{
//                    parser.nextToken();
//                    switch on parser.getText(){
//                        when 'propertyaddressfull'{
//                            System.debug('\rmatchTopic='+matchTopic+' (current value='+value+') '+prop.get(matchTopic+'__c')+' filterStreetMaps=='+ SfMapsRetriever.keyMap.get((String)prop.get(matchTopic+'__c')));
//                            prop.Id=SfMapsRetriever.keyMap.get((String)prop.get(matchTopic+'__c')); //matching property here
//                            System.debug(prop.get(matchTopic+'__c')+'...FOUND->'+prop);
//                            prop.propertyaddressfull__c=String.valueOf(value) ?? empt;
//                        }
//                        when 'partyowner1namefull'{
//                            prop.partyowner1namefull__c=String.valueOf(value) ?? empt;
//                        }
//                        when 'partyowner2namefull'{
//                            prop.partyowner2namefull__c=String.valueOf(value) ?? empt;
//                        }
//                        when 'contactownermailaddressfull'{
//                            prop.contactownermailaddressfull__c=String.valueOf(value) ?? empt;
//                        }
//                        when 'statusowneroccupiedflag'{
//                            prop.statusowneroccupiedflag__c = Boolean.valueOf(value ?? 'false');
//                        }
//                        when 'construction'{
//                            prop.construction__c=String.valueOf(value) ?? empt;
//                        }
//                        when 'structurestyle'{
//                            prop.structurestyle__c=String.valueOf(value) ?? empt;
//                        }
//                        when 'legalsubdivision'{
//                            prop.legalsubdivision__c=String.valueOf(value) ?? empt;
//                        }
//                        when 'situscounty'{
//                            prop.situscounty__c=String.valueOf(value) ?? empt;
//                        }
//                        when 'parcelnumberformatted'{
//                            prop.parcelnumberformatted__c=String.valueOf(value) ?? empt;
//                        }
//                        when 'foundation'{
//                            prop.foundation__c=String.valueOf(value) ?? empt;
//                        }
//                        when 'roofmaterial'{
//                            prop.roofmaterial__c=String.valueOf(value) ?? empt;
//                        }
//                        when 'roomscount'{
//                            prop.roomscount__c = Integer.valueOf(value ?? z);
//                        }
//                        when 'bathcount'{
//                            prop.bathcount__c = Decimal.valueOf(String.valueOf(value ?? z));
//                        }
//                        when 'bedroomscount'{
//                            prop.bedroomscount__c = Integer.valueOf(value ?? z);
//                        }
//                        when 'storiescount'{
//                            prop.storiescount__c = Integer.valueOf(value?? z);
//                        }
//                        when 'unitscount'{
//                            prop.unitscount__c = Integer.valueOf(value ?? z);
//                        }
//                        when 'buildingscount'{
//                            prop.buildingscount__c = Decimal.valueOf(String.valueOf(value ?? z));
//                        }
//                        when 'areabuilding'{
//                            prop.areabuilding__c = Decimal.valueOf(String.valueOf(value ?? z));
//                        }
//                        when 'areagross'{
//                            prop.areagross__c = Decimal.valueOf(String.valueOf(value ?? z));
//                        }
//                        when 'arealotsf'{
//                            prop.arealotsf__c = Decimal.valueOf(String.valueOf(value?? z));
//                        }
//                        when 'ownertypedescription1'{
//                            prop.ownertypedescription1__c=String.valueOf(value ?? empt);
//                        }
//                        when 'currentfirstpositionmortgagetype'{
//                            prop.currentfirstpositionmortgagetype__c=String.valueOf(value ?? empt);
//                        }
//                        when 'availableequity'{
//
//                            prop.availableequity__c = Decimal.valueOf(String.valueOf(value ?? z));
//                        }
//                        when 'ltv'{
//
//                            prop.ltv__c=Decimal.valueOf(String.valueOf(value ?? z));
//                        }
//                        when 'taxassessedvaluetotal'{
//                            prop.taxassessedvaluetotal__c = Decimal.valueOf(String.valueOf(value ?? z));
//                        }
//                        when 'taxassessedvalueimprovements'{
//                            prop.taxassessedvalueimprovements__c = Decimal.valueOf(String.valueOf(value ?? z));
//                        }
//                        when 'previousassessedvalue'{
//                            prop.previousassessedvalue__c=Decimal.valueOf(String.valueOf(value ?? z));
//                        }
//                        when 'taxbilledamount'{
//                            prop.taxbilledamount__c=Decimal.valueOf(String.valueOf(value ?? z));
//                        }
//                        when 'taxmarketvalueimprovements'{
//                            prop.taxmarketvalueimprovements__c=Decimal.valueOf(String.valueOf(value ?? z));
//                        }
//                        when 'taxmarketvaluetotal'{
//                            prop.taxmarketvaluetotal__c=Decimal.valueOf(String.valueOf(value ?? z));
//                        }
//                        when 'yearbuilt'{
//                            prop.yearbuilt__c = Decimal.valueOf(String.valueOf(value ?? z));
//                        }
//                        when 'deedlastsaleprice'{
//                            prop.deedlastsaleprice__c=Decimal.valueOf(String.valueOf(value ?? z));
//                        }
//                        when 'exterior1code'{
//                            prop.exterior1code__c=String.valueOf(value);
//                        }
//                        when 'propertyusestandardized'{
//                            prop.propertyusestandardized__c=String.valueOf(value) ?? empt;
//                        }
//                    }
//                }
//                when 'geoid'{
//                    parser.nextToken();
//                    parser.nextToken();
//                    parser.nextToken();
//                    updateableProperties.add(prop);
//                }
//                when 'popup'{
//                    prop = new Property__c();
//                }
//            }
//        }
//        System.debug(JSON.serializePretty(updateableProperties));
//        return updateableProperties;
//    }

    public static String escapeCSV(String value) {
        if (value == null) return ''; if (value.contains(',') || value.contains('\n') || value.contains('"')) { value = value.replace('"', '""');
            return '"' + value + '"';
        }
        return value;
    }

}