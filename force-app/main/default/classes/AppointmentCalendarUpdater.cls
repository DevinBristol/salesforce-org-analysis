/**
 * Created by AdrienP on 10/30/2025.
 */

public with sharing class AppointmentCalendarUpdater {
    @AuraEnabled
    public static void rescheduleAppointment(Id serviceAppointmentId, Datetime newDateTime) {
        ServiceAppointment sa = [SELECT Id, SchedStartTime, SchedEndTime FROM ServiceAppointment WHERE Id = :serviceAppointmentId LIMIT 1];

        sa.SchedStartTime = newDateTime;
        sa.SchedEndTime = newDateTime.addHours(1); // adjust if needed

        update sa;
    }
}