/**
 * Created by Devin on 2/17/2025.
 */

public with sharing class CustomNotifications {

    public static void sendCloseDateChangeNotification(List<Opportunity> opportunities) {
        // Get Notification Type ID
        Id notificationTypeId = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Opportunity_Close_Date_Change' LIMIT 1].Id;
        for (Opportunity opp : opportunities) {
            // Get Opportunity Owner as recipient
            Id recipientUserId = opp.Id;
            Set<String> SendIds = new Set<String>{opp.Id};
            // Format notification message
            String message = 'The Close Date for Opportunity "' + opp.Name + '" has changed to ' + opp.CloseDate.format();
            // Create a new notification
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('Opportunity Close Date Updated');
            notification.setBody(message);
            notification.setNotificationTypeId(notificationTypeId);
            notification.setSenderId(UserInfo.getUserId()); // Current User as sender
            notification.setTargetId(opp.Id); // Notify Opportunity Owner
            notification.send(SendIds);
        }
    }

    public static void sendCompanyCamHistoryChangeNotification(List<Opportunity> opportunities) {
        // Get Notification Type ID
        Id notificationTypeId = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Opportunity_CompanyCam_History_Change' LIMIT 1].Id;
        for (Opportunity opp : opportunities) {
            // Get Opportunity Owner as recipient
            Id recipientUserId = opp.Id;
            Set<String> SendIds = new Set<String>{opp.Id};
            // Format notification message
            String message = 'CompanyCam on Opportunity "' + opp.Name + '" has been updated';
            // Create a new notification
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('CompanyCam Updated');
            notification.setBody(message);
            notification.setNotificationTypeId(notificationTypeId);
            notification.setSenderId(UserInfo.getUserId()); // Current User as sender
            notification.setTargetId(opp.Id); // Notify Opportunity Owner
            notification.send(SendIds);
        }
    }
}