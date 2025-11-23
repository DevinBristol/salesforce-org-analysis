/**
 * Created by NoahR on 7/22/2025.
 */

public with sharing class BatchAbleAniHelper implements Queueable {

    private List<SObject> recordsToUpdate;

    public BatchAbleAniHelper(List<SObject> recordsToUpdate) {
        this.recordsToUpdate = recordsToUpdate;
    }

    public void execute(QueueableContext context) {
        TriggerHandler.bypass('LeadTriggerHandler');
        TriggerHandler.bypass('ContactTriggerHandler');

        System.debug('Update: Size - ' + recordsToUpdate.size() + ' Vals ' + recordsToUpdate);

        try {
            update recordsToUpdate;
        } catch (Exception e) {
            System.debug('Error updating records in queueable: ' + e.getMessage());
        }
    }
}