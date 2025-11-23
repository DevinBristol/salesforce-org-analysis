/**
 * Created by AdrienP on 10/17/2025.
 */

public without sharing class AppointmentCalendarController {

    // ----- Appointment Wrapper -----
    public class AppointmentWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String apptNumber { get; set; }
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String parentWorkOrderId { get; set; }
        @AuraEnabled public Datetime startDate { get; set; }
        @AuraEnabled public Datetime scheduledEnd { get; set; }

        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public String accountName { get; set; }

        @AuraEnabled public String startDateFormatted { get; set; }
        @AuraEnabled public String scheduledEndFormatted { get; set; }
        @AuraEnabled public String dayLabel { get; set; }
        @AuraEnabled public String monthLabel { get; set; }
        @AuraEnabled public String statusColor { get; set; }
        @AuraEnabled public String workOrderName { get; set; }
        @AuraEnabled public String customerName { get; set; }

        @AuraEnabled public String Appointment_Result_1 { get; set; }

        public AppointmentWrapper(ServiceAppointment sa) {
            this.id = sa.Id;
            this.apptNumber = sa.AppointmentNumber;
            this.subject = sa.Subject;
            this.status = sa.Status;
            this.parentWorkOrderId = sa.ParentRecordId;
            this.startDate = (sa.SchedStartTime != null) ? sa.SchedStartTime : sa.EarliestStartTime;
            this.scheduledEnd = sa.SchedEndTime;

            this.accountId = sa.AccountId;
            this.accountName = (sa.Account != null) ? sa.Account.Name : null;

            // Assign the field value directly
            this.Appointment_Result_1 = sa.Appointment_Result_1__c;

            TimeZone userTz = UserInfo.getTimeZone();

            if (this.startDate != null) {
                this.startDateFormatted = this.startDate.format('MMMM d, yyyy h:mm a', userTz.getID());
                this.dayLabel = this.startDate.format('d');
                this.monthLabel = this.startDate.format('MMM');
            }

            if (this.scheduledEnd != null) {
                this.scheduledEndFormatted = this.scheduledEnd.format('MMMM d, yyyy h:mm a', userTz.getID());
            }

            // Basic status color map — tweak as needed
            if (sa.Status == 'Completed') {
                this.statusColor = 'green';
            } else if (sa.Status == 'In Progress') {
                this.statusColor = 'orange';
            } else if (sa.Status == 'Scheduled') {
                this.statusColor = 'blue';
            } else {
                this.statusColor = 'neutral';
            }

            try {
                this.workOrderName = sa.ParentRecord?.Name;
            } catch (Exception e) {
                this.workOrderName = null;
            }

            this.customerName = null;
        }
    }

    // ----- MAIN METHOD: FETCH APPOINTMENTS FOR MONTH -----
    @AuraEnabled(Cacheable=true)
    public static List<AppointmentWrapper> getAppointmentsForMonth(Id userId, Integer year, Integer month) {
        System.debug('### [ACCtr] ENTER getAppointmentsForMonth userId=' + userId + ' y=' + year + ' m=' + month);

        Datetime monthStartUtc = Datetime.newInstanceGmt(year, month, 1, 0, 0, 0);
        Datetime monthEndExclusiveUtc = monthStartUtc.addMonths(1);
        System.debug('### [ACCtr] Window >= ' + monthStartUtc + ' and < ' + monthEndExclusiveUtc);

        // ----- STEP 1: OPPORTUNITIES (owner OR team member) -----
        Set<Id> oppIds = new Set<Id>();
        for (Opportunity o : [SELECT Id FROM Opportunity WHERE OwnerId = :userId LIMIT 5000]) {
            oppIds.add(o.Id);
        }
        for (OpportunityTeamMember tm : [SELECT OpportunityId FROM OpportunityTeamMember WHERE UserId = :userId LIMIT 5000]) {
            oppIds.add(tm.OpportunityId);
        }
        if (oppIds.isEmpty()) {
            System.debug('### [ACCtr] No oppIds. RETURN []');
            return new List<AppointmentWrapper>();
        }

        // ----- STEP 2: WORK ORDERS FOR THOSE OPPS -----
        Set<Id> woIds = new Set<Id>();
        for (WorkOrder wo : [SELECT Id FROM WorkOrder WHERE Opportunity__c IN :oppIds LIMIT 5000]) {
            woIds.add(wo.Id);
        }
        if (woIds.isEmpty()) {
            System.debug('### [ACCtr] No woIds. RETURN []');
            return new List<AppointmentWrapper>();
        }

        // ----- STEP 3: SERVICE APPOINTMENTS WITHIN WINDOW -----
        List<ServiceAppointment> appts = [
                SELECT Id, AppointmentNumber, Subject, ParentRecordId, Status,
                        SchedStartTime, SchedEndTime, EarliestStartTime,
                        AccountId, Account.Name,
                        Appointment_Result_1__c
                FROM ServiceAppointment
                WHERE ParentRecordId IN :woIds
                AND (
                        (SchedStartTime >= :monthStartUtc AND SchedStartTime < :monthEndExclusiveUtc) OR
                        (EarliestStartTime >= :monthStartUtc AND EarliestStartTime < :monthEndExclusiveUtc)
                )
                ORDER BY EarliestStartTime
        ];
        System.debug('### [ACCtr] SA count=' + appts.size());

        // ----- STEP 4: WRAP RESULTS -----
        List<AppointmentWrapper> wrapped = new List<AppointmentWrapper>();
        for (ServiceAppointment sa : appts) {
            wrapped.add(new AppointmentWrapper(sa));
        }
        System.debug('### [ACCtr] Wrapped count=' + wrapped.size());
        return wrapped;
    }

    @AuraEnabled
    public static List<AppointmentWrapper> getOverdueAppointments(Id userId) {

        Datetime nowUtc = System.now();

        // Get work orders user owns (same logic as monthly query)
        Set<Id> woIds = new Set<Id>();
        for (WorkOrder wo : [
                SELECT Id
                FROM WorkOrder
                WHERE OwnerId = :userId
                LIMIT 5000
        ]) {
            woIds.add(wo.Id);
        }
        if (woIds.isEmpty()) return new List<AppointmentWrapper>();

        // Get overdue pending appointments
        List<ServiceAppointment> appts = [
                SELECT Id, AppointmentNumber, Subject, ParentRecordId, Status,
                        SchedStartTime, SchedEndTime, EarliestStartTime,
                        AccountId, Account.Name, Appointment_Result_1__c
                FROM ServiceAppointment
                WHERE ParentRecordId IN :woIds
                AND (
                        Appointment_Result_1__c = null OR
                        Appointment_Result_1__c = 'Pending'
                )
                AND SchedEndTime < :nowUtc
                ORDER BY SchedEndTime ASC
                LIMIT 2000
        ];

        List<AppointmentWrapper> wrapped = new List<AppointmentWrapper>();
        for (ServiceAppointment sa : appts) {
            wrapped.add(new AppointmentWrapper(sa));
        }
        return wrapped;
    }


}