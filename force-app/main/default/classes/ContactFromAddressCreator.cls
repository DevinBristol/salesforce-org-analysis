/**
 * Created by NoahR on 6/9/2025.
 */

public with sharing class ContactFromAddressCreator {
    @AuraEnabled
    public static String createContactWithAppointment(String firstName, String lastName, String phone, String email, Id campaignId,
            String address, Datetime appointmentTime, String userId)
    {
        // Validate required fields
        if (String.isBlank(firstName) || String.isBlank(lastName) || campaignId == null || appointmentTime == null)
        {
            throw new AuraHandledException('Missing required Fields');
        }

        Account newAccount = new Account(
                Name = 'Trigger Isn\'t Working Devin',
                Account_Disposition__c ='Active : Appointment Scheduled',
                Stage__c = 'Active'
        );
        insert newAccount;
        // Create Contact
        //Parse The Address
        String street;
        String city;
        String state;
        String postalCode;

        List<String> parts = address.split(',');

        if (parts.size() >= 1) {
            street = parts[0].trim();
        }
        if (parts.size() >= 2) {
            city = parts[1].trim();
        }
        if (parts.size() >= 3) {
            // Split state and postal code
            List<String> stateZip = parts[2].trim().split(' ');
            if (stateZip.size() >= 1) {
                state = stateZip[0].trim();
            }
            if (stateZip.size() >= 2) {
                postalCode = stateZip[1].trim();
            }
        }

        //Make address
        Contact newContact = new Contact(
                FirstName = firstName,
                LastName = lastName,
                MailingCity = city,
                MailingCountry = 'US',
                MailingState = state,
                MailingPostalCode = postalCode,
                MailingStreet = street,
                AccountId = newAccount.Id
        );

        if(!String.isBlank(phone) && phone != null){
            newContact.Phone = phone;
        }

        if(!String.isBlank(email) && email != email){
            newContact.Email = email;
        }
        insert newContact;

        CampaignMember cm = new CampaignMember(ContactId = newContact.Id, CampaignId = campaignId);
        insert cm;

        //Make Service Appointment using datetime
        Contact madeCon = [SELECT AccountId FROM Contact WHERE Id = :newContact.Id];

        //Account account = [SELECT Id FROM Account WHERE Id = :newContact.AccountId];

        Property__c newProp = new Property__c(
                AccountId__c = newAccount.Id,
                Address__City__s = city,
                Address__StateCode__s = state,
                Address__PostalCode__s = postalCode,
                Address__Street__s = street,
                Address__CountryCode__s = 'US'
        );

        insert  newProp;

        Account updateAccountAdr = new Account(
                Id = newAccount.Id
        );

        updateAccountAdr.ShippingCity = city;
        updateAccountAdr.ShippingStreet = street;
        updateAccountAdr.ShippingCountry = 'US';
        updateAccountAdr.ShippingState = state;
        updateAccountAdr.ShippingPostalCode = postalCode;

        updateAccountAdr.BillingCity = city;
        updateAccountAdr.BillingStreet = street;
        updateAccountAdr.BillingCountry = 'US';
        updateAccountAdr.BillingState = state;
        updateAccountAdr.BillingPostalCode = postalCode;

        update updateAccountAdr;

        //System.debug(account);
        system.debug(madeCon);
        Opportunity newOpportunity = new Opportunity(
                AccountId = madeCon.AccountId,
                OwnerId = userId,
                StageName = 'Accounting Active',
                CloseDate = appointmentTime.date(),
                Opportunity_Property__c = newProp.Id
        );
        system.debug(newOpportunity);
        insert newOpportunity;

        WorkOrder newWO = new WorkOrder(
                AccountId = newAccount.Id,
                City = city,
                Street = street,
                State = state,
                PostalCode = postalCode,
                Country = 'US',
                ServiceTerritoryId = '0HhR70000002pMbKAI',
                StartDate = appointmentTime,
                CreatedDate = Datetime.now(),
                LastModifiedDate = Datetime.now(),
                EndDate = appointmentTime.addHours(3),
                WorkTypeId = '08qHs000000kgPPIAY',
                Opportunity__c = newOpportunity.Id
        );

        insert newWO;

        ServiceAppointment sa = [SELECT Id, SchedStartTime, SchedEndTime FROM ServiceAppointment WHERE ParentRecordId = :newWO.Id];
        System.debug(sa);

        String timeSet = '';
        if(appointmentTime.hour() > 12){
            timeSet = (appointmentTime.hour() - 12).toString() + ':' + appointmentTime.minute() + ' PM';
        } else{
            timeSet = (appointmentTime.hour()).toString() + ':' + appointmentTime.minute() + ' AM';
        }

        sa.Subject = firstName + ' ' + lastName + '  : Initial Sales Visit - ' + appointmentTime.month() + '/' + appointmentTime.day() + '/' +
                appointmentTime.year() + ', ' + timeSet;

        sa.SchedStartTime = appointmentTime;
        sa.SchedEndTime = appointmentTime.addHours(2);
        update sa;
//        ServiceAppointment sa = new ServiceAppointment(
//                SchedStartTime = appointmentTime,
//                SchedEndTime = appointmentTime.addHours(2),
//                ParentRecordId = newWO.Id,
//                WorkTypeId = '08qHs000000kgPPIAY'
//        );

//        insert sa;
//        System.debug(sa);

        return madeCon.Id;
    }
}