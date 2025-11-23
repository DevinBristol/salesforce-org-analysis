/**
 * Created by AdrienP on 11/6/2025.
 * Controller for generating the daily Rundown export file as Excel.
 */
public without sharing class RundownExportController {

    // DTO for LWC preview table
    public class RundownAppointmentDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String accountName;
        @AuraEnabled public String timeStr;
        @AuraEnabled public String result1;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String address;
    }


    // Fetch today's Service Appointments for LWC display
    @AuraEnabled(Cacheable=false)
    public static List<RundownAppointmentDTO> getTodayAppointments() {

        Date today = System.today();
        Datetime startOfDay = Datetime.newInstance(today.year(), today.month(), today.day(), 0, 0, 0);
        Datetime endOfDay   = startOfDay.addDays(1);

        List<ServiceAppointment> appts = [
                SELECT Id, AppointmentNumber, Subject, Status,
                        SchedStartTime, SchedEndTime,
                        Appointment_Result_1__c, Description,
                        Account.Name, Account.Phone,
                        Street, City, State, PostalCode,
                        Owner.Name, AccountId
                FROM ServiceAppointment
                WHERE SchedStartTime >= :startOfDay
                AND SchedStartTime <  :endOfDay
                AND (Status != 'Cancelled' AND Status != 'Cannot Complete')
                ORDER BY SchedStartTime ASC
        ];

        List<RundownAppointmentDTO> dtos = new List<RundownAppointmentDTO>();

        for (ServiceAppointment sa : appts) {

            RundownAppointmentDTO dto = new RundownAppointmentDTO();
            dto.id = sa.Id;

            dto.accountName = (sa.Account != null ? sa.Account.Name : '');

            dto.timeStr = sa.SchedStartTime.format('h:mm a', UserInfo.getTimeZone().getID());
            dto.result1 = sa.Appointment_Result_1__c;
            dto.ownerName = (sa.Owner != null ? sa.Owner.Name : '');

            String addressBlock = '';
            if (sa.Account != null && sa.Account.Phone != null) {
                addressBlock += formatPhone(sa.Account.Phone) + ' - ';
            }

            List<String> addr = new List<String>();
            if (sa.Street != null)     addr.add(sa.Street);
            if (sa.City != null)       addr.add(sa.City);
            if (sa.State != null)      addr.add(sa.State);
            if (sa.PostalCode != null) addr.add(sa.PostalCode);
            if (!addr.isEmpty())       addressBlock += String.join(addr, ' ');

            dto.address = addressBlock;

            dtos.add(dto);
        }

        return dtos;
    }



    // Generate the Excel Rundown — full corrected border logic
    @AuraEnabled(Cacheable=false)
    public static String generateRundownExcel(List<Id> selectedAppointmentIds) {

        if (selectedAppointmentIds == null || selectedAppointmentIds.isEmpty()) {
            throw new AuraHandledException('No appointments selected for Rundown.');
        }

        Date today = System.today();
        Datetime todayDt = Datetime.newInstance(today.year(), today.month(), today.day(), 0, 0, 0);

        String dayOfWeek = todayDt.format('EEEE', UserInfo.getTimeZone().getID());
        String dateStr   = todayDt.format('M/d/yy', UserInfo.getTimeZone().getID());

        List<ServiceAppointment> appts = [
                SELECT Id, AppointmentNumber, Subject, Status,
                        SchedStartTime, SchedEndTime,
                        Appointment_Result_1__c, Description,
                        Account.Name, Account.Phone,
                        Street, City, State, PostalCode,
                        Owner.Name, Owner.FirstName, Owner.LastName,
                        AccountId
                FROM ServiceAppointment
                WHERE Id IN :selectedAppointmentIds
                AND (Status != 'Cancelled' AND Status != 'Cannot Complete')
                ORDER BY SchedStartTime ASC
        ];

        Set<Id> accountIds = new Set<Id>();
        for (ServiceAppointment sa : appts) {
            if (sa.AccountId != null) accountIds.add(sa.AccountId);
        }

        Map<Id, Opportunity> oppByAccount = new Map<Id, Opportunity>();

        if (!accountIds.isEmpty()) {
            for (Opportunity opp : [
                    SELECT Id, AccountId,
                            Campaign.Name,
                            Opportunity_Property__r.yearbuilt__c,
                            Opportunity_Property__r.deedlastsaledate__c,
                            Description,
                            Opportunity_Property__r.taxassessedvaluetotal__c,
                    (SELECT User.FirstName, User.LastName, TeamMemberRole FROM OpportunityTeamMembers),
                    (SELECT Quantity, Product2.ProductCode FROM OpportunityLineItems)
                    FROM Opportunity
                    WHERE AccountId IN :accountIds
                    ORDER BY CloseDate DESC
            ]) {
                if (!oppByAccount.containsKey(opp.AccountId)) {
                    oppByAccount.put(opp.AccountId, opp);
                }
            }
        }

        Map<Id, List<Contact>> contactsByAccount = new Map<Id, List<Contact>>();

        if (!accountIds.isEmpty()) {
            for (Contact c : [
                    SELECT Id, Phone, AccountId
                    FROM Contact
                    WHERE AccountId IN :accountIds
                    AND (Phone != NULL)
                    ORDER BY LastModifiedDate DESC
            ]) {
                if (!contactsByAccount.containsKey(c.AccountId)) {
                    contactsByAccount.put(c.AccountId, new List<Contact>());
                }
                contactsByAccount.get(c.AccountId).add(c);
            }
        }


        // === BUILD THE EXCEL XML ===

        String xml =
                '<?xml version="1.0"?>' +
                        '<?mso-application progid="Excel.Sheet"?>' +
                        '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" ' +
                        ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">' +

                        '<Styles>' +

                        // ========== FIRST COLUMN SPECIAL ==========
                        // Full box
                        '<Style ss:ID="nameTop">' +
                        '<Alignment ss:Horizontal="Left" ss:Vertical="Top" ss:WrapText="1"/>' +
                        '<Borders>' +
                        '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '</Borders>' +
                        '</Style>' +

                        // Left-only
                        '<Style ss:ID="nameMid">' +
                        '<Alignment ss:Horizontal="Left" ss:Vertical="Top" ss:WrapText="1"/>' +
                        '<Borders>' +
                        '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '</Borders>' +
                        '</Style>' +

                        // Left + Bottom
                        '<Style ss:ID="nameBottom">' +
                        '<Alignment ss:Horizontal="Left" ss:Vertical="Top" ss:WrapText="1"/>' +
                        '<Borders>' +
                        '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '</Borders>' +
                        '</Style>' +

                        // ========== BOXED COLUMN STYLES (for cols B–G) ==========

                        // Row 1 top (left, right, top)
                        '<Style ss:ID="boxTop">' +
                        '<Alignment ss:Horizontal="Center" ss:Vertical="Center" ss:WrapText="1"/>' +
                        '<Borders>' +
                        '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '</Borders>' +
                        '</Style>' +

                        // Row 2 & 3 mid (left + right only)
                        '<Style ss:ID="boxMid">' +
                        '<Alignment ss:Horizontal="Center" ss:Vertical="Center" ss:WrapText="0"/>' +
                        '<Borders>' +
                        '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '</Borders>' +
                        '</Style>' +

                        // Row 4 bottom (left, right, bottom)
                        '<Style ss:ID="boxBottom">' +
                        '<Alignment ss:Horizontal="Center" ss:Vertical="Center" ss:WrapText="1"/>' +
                        '<Borders>' +
                        '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '</Borders>' +
                        '</Style>' +

                        // Notes column uses left alignment
                        '<Style ss:ID="boxTopLeft">' +
                        '<Alignment ss:Horizontal="Left" ss:Vertical="Top" ss:WrapText="1"/>' +
                        '<Borders>' +
                        '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '</Borders>' +
                        '</Style>' +

                        '<Style ss:ID="boxMidLeftRight">' +
                        '<Alignment ss:Horizontal="Left" ss:Vertical="Top" ss:WrapText="1"/>' +
                        '<Borders>' +
                        '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '</Borders>' +
                        '</Style>' +

                        '<Style ss:ID="boxBottomLeftRight">' +
                        '<Alignment ss:Horizontal="Left" ss:Vertical="Top" ss:WrapText="1"/>' +
                        '<Borders>' +
                        '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '</Borders>' +
                        '</Style>' +

                        '<Style ss:ID="boxTime">' +
                        '<Alignment ss:Horizontal="Center" ss:Vertical="Top" ss:WrapText="1"/>' +
                        '<Borders>' +
                        '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '</Borders>' +
                        '</Style>' +

                        // Header full boxed
                        '<Style ss:ID="headerFull">' +
                        '<Alignment ss:Horizontal="Left" ss:Vertical="Center" ss:WrapText="1"/>' +
                        '<Borders>' +
                        '<Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '<Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>' +
                        '</Borders>' +
                        '</Style>' +

                        '</Styles>' +


                        '<Worksheet ss:Name="Rundown"><Table>' +
                        '<Column ss:Width="170"/>' + // name col
                        '<Column ss:Width="67"/>'  + // date
                        '<Column ss:Width="80"/>'  + // property
                        '<Column ss:Width="67"/>'  + // lead
                        '<Column ss:Width="62"/>'  + // salesperson
                        '<Column ss:Width="62"/>'  + // result
                        '<Column ss:Width="157"/>';  // notes


        // HEADER
        xml +=
                '<Row>' +
                        cell('Day of Week: ' + dayOfWeek, 'headerFull') +
                        cell('Date: ' + dateStr, 'headerFull') +
                        cell('Property Details', 'headerFull') +
                        cell('Lead Source', 'headerFull') +
                        cell('Salesperson', 'headerFull') +
                        cell('Results', 'headerFull') +
                        cell('Notes', 'headerFull') +
                        '</Row>';


        // ========== DATA BLOCKS ==========

        for (ServiceAppointment sa : appts) {

            Opportunity opp = oppByAccount.get(sa.AccountId);

            String nameOnly = (sa.Account != null ? sa.Account.Name : '');

            String street = (sa.Street != null ? sa.Street : '');
            String cityLine = (
                    (sa.City != null ? sa.City : '') + ' ' +
                            (sa.State != null ? sa.State : '') + ' ' +
                            (sa.PostalCode != null ? sa.PostalCode : '')
            ).trim();

            String phone1 = '';
            String phone2 = '';

            List<Contact> clist = contactsByAccount.get(sa.AccountId);

            if (clist != null && !clist.isEmpty()) {
                Integer count = 0;

                for (Contact c : clist) {
                    if (count == 2) break;

                    if (c.Phone != null) {
                        if (count == 0) {
                            phone1 = formatPhone(c.Phone);
                        } else if (count == 1) {
                            phone2 = formatPhone(c.Phone);
                        }
                        count++;
                    }
                }
            }

            String apptDate = sa.SchedStartTime.format('M/d/yy', UserInfo.getTimeZone().getID());
            String timeStr  = sa.SchedStartTime.format('h:mm a', UserInfo.getTimeZone().getID());

            // Property
            String yearLine = '';
            String productLine = '';
            if (opp != null && opp.Opportunity_Property__r != null) {
                String yb = opp.Opportunity_Property__r.yearbuilt__c != null ?
                        String.valueOf(opp.Opportunity_Property__r.yearbuilt__c).replace(',', '') : '';
                String yd = '';
                if (opp.Opportunity_Property__r.deedlastsaledate__c != null) {
                    yd = String.valueOf(opp.Opportunity_Property__r.deedlastsaledate__c.year());
                }

                if (yb != '' && yd != '') {
                    yearLine = yb + ' / ' + yd;
                }
                else if (yb != '') {
                    yearLine = yb;
                }
                else {
                    yearLine = yd;
                }

                List<String> pl = new List<String>();
                for (OpportunityLineItem oli : opp.OpportunityLineItems) {
                    if (oli.Product2 != null) {
                        pl.add(String.valueOf((Integer)oli.Quantity) + ' ' + oli.Product2.ProductCode);
                    }
                }
                productLine = String.join(pl, ', ');
            }

            // Lead source
            String lead = '';
            if (opp != null && opp.Campaign != null) lead = opp.Campaign.Name;

            List<String> tm = new List<String>();
            if (opp != null) {
                for (OpportunityTeamMember ot : opp.OpportunityTeamMembers) {
                    if (ot.TeamMemberRole == 'Opportunity Owner' ||
                            ot.TeamMemberRole == 'Inside Sales Rep') {
                        String first = ot.User.FirstName;
                        String lastInitial = '';

                        if (ot.User.LastName != null && ot.User.LastName.length() > 0) {
                            lastInitial = ot.User.LastName.substring(0,1);
                        }

                        tm.add(first + ' ' + lastInitial);
                    }
                }
            }

            String taxValue = '';
            if (opp != null && opp.Opportunity_Property__r != null &&
                    opp.Opportunity_Property__r.taxassessedvaluetotal__c != null) {
                taxValue = '$' + formatWithCommas(
                        opp.Opportunity_Property__r.taxassessedvaluetotal__c
                );
            }

            String notes  = (opp != null ? opp.Description : '');


            // ========== ROW 1 (TOP) — BOX TOP FOR ALL COLS EXCEPT FIRST ==========
            xml += '<Row>' +
                    cellStyled(nameOnly, 'nameTop') +       // A (unique)
                    cellStyled(phone1, 'boxTop') +        // B
                    cellStyled(yearLine, 'boxTop') +        // C
                    cellStyled(' ', 'boxTop') +         // D
                    cellStyled(' ', 'boxTop') +     // E
                    cellStyled(' ', 'boxTop') +          // F
                    '<Cell ss:StyleID="boxBottomLeftRight" ss:MergeDown="3">' +
                    '<Data ss:Type="String">' + escapeXml(notes) + '</Data>' +
                    '</Cell>' +
                    '</Row>';


            // ========== ROW 2 (MID) ==========
            xml += '<Row>' +
                    cellStyled(street, 'nameMid') +             // A
                    cellStyled(phone2, 'boxMid') +                 // B
                    cellStyled(' ', 'boxMid') +                 // C
                    cellStyled(String.join(tm, '; ') + ' ' + lead, 'boxMid') +                 // D
                    cellStyled(' ', 'boxMid') +                 // E
                    cellStyled(' ', 'boxMid') +                 // F
                    '</Row>';


            // ========== ROW 3 (MID) ==========
            xml += '<Row>' +
                    cellStyled(cityLine, 'nameMid') +           // A
                    cellStyled(apptDate, 'boxMid') +                 // B
                    cellStyled(productLine, 'boxMid') +         // C
                    cellStyled(' ', 'boxMid') +                 // D
                    cellStyled(' ', 'boxMid') +                 // E
                    cellStyled(' ', 'boxMid') +                 // F
                    '</Row>';


            // ========== ROW 4 (BOTTOM) ==========
            xml += '<Row>' +
                    cellStyled('', 'nameBottom') +           // COL A
                    cellStyled(timeStr, 'boxTime') + // COL B
                    cellStyled(' ', 'boxBottom') +              // COL C
                    cellStyled(' ', 'boxBottom') +              // COL D
                    cellStyled(taxValue, 'boxBottom') +              // COL E
                    cellStyled(' ', 'boxBottom') +              // COL F
                    '</Row>';

        }


        xml += '</Table></Worksheet></Workbook>';

        return EncodingUtil.base64Encode(Blob.valueOf(xml));
    }



    // === Helpers ===
    private static String cell(String val, String styleId) {
        return '<Cell ss:StyleID="' + styleId + '"><Data ss:Type="String">' +
                escapeXml(val) + '</Data></Cell>';
    }

    private static String cellStyled(String val, String styleId) {
        if (val == null) val = '';
        return '<Cell ss:StyleID="' + styleId + '"><Data ss:Type="String">' +
                escapeXml(val) + '</Data></Cell>';
    }

    private static String formatPhone(String p) {
        if (String.isBlank(p)) return '';
        String d = p.replaceAll('[^0-9]','');
        if (d.length() == 10) {
            return d.substring(0,3)+'-'+d.substring(3,6)+'-'+d.substring(6);
        }
        return p;
    }

    private static String escapeXml(String s) {
        if (s == null) return '';
        return s.replace('&','&amp;')
                .replace('<','&lt;')
                .replace('>','&gt;')
                .replace('"','&quot;')
                .replace('\'','&apos;');
    }

    private static String formatWithCommas(Decimal val) {
        if (val == null) return '';
        return ((Long)val.setScale(0)).format();
    }

}