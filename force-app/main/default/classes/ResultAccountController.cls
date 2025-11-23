/**
 * Created by noahr on 7/2/2024.
 */

public with sharing class ResultAccountController {
    @AuraEnabled(Cacheable=true)
    public static List<ServiceAppointment> GetServiceAppointmentBuffer(String accId){
       return ResultAccountService.GetServiceAppointment(accId);
    }
}