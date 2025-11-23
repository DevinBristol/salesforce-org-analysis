/**
 * Created by Devin on 6/4/2024.
 */

public with sharing class PhoneNumberSelector {

    public Phonenumber__c GetPhoneNumbersByValues(List<String> phoneNumberValues){

        Phonenumber__c foundNumbers = [SELECT Id,Name FROM Phonenumber__c WHERE Name IN :phoneNumberValues];

        return foundNumbers;
    }
}