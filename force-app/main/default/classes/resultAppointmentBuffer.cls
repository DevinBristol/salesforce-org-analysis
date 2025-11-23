/**
 * Created by noahr on 6/27/2024.
 */

public with sharing class resultAppointmentBuffer {

    @AuraEnabled(Cacheable=false)
    public static void UpdateVisitResultSoldBuffer(String appointmentId, String reasonOne, String reasonTwo, String reasonThree, Decimal amount,
            String closingNotes, Date closedDate, String assignedUserId) {
        ResultAppointment.UpdateVisitResultSold(appointmentId, reasonOne, reasonTwo, reasonThree, amount, closingNotes, closedDate, assignedUserId);
    }
    @AuraEnabled(Cacheable=false)
    public static void UpdateFollowUpVisitResultBuffer(String appointmentId, String reasonOne, String reasonTwo, String reasonThree,
                                                       String sDescription,Datetime followUpDate, String ownedUserId, String propId, String workType) {
        ResultAppointment.UpdateFollowUpVisitResult(appointmentId, reasonOne, reasonTwo, reasonThree,sDescription,followUpDate,ownedUserId,propId,workType);
    }
    @AuraEnabled(Cacheable=false)
    public static void UpdateNoDemoOrCancelledBuffer(String appointmentId, String reasonOne, String reasonTwo, String reasonThree,
                                                     String sDescription,Datetime followUpDate, String ownedUserId) {
        ResultAppointment.UpdateNoDemoOrCancelled(appointmentId,reasonOne,reasonTwo,reasonThree,sDescription,followUpDate,ownedUserId);
    }
}