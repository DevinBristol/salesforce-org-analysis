/**
 * Created by Devin on 8/8/2024.
 */

trigger ServiceAppointmentTrigger on ServiceAppointment (after insert, after update) {
    {
        new ServiceAppointmentTriggerHandler().run();
    }
}