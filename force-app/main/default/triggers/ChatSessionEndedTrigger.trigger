trigger ChatSessionEndedTrigger on Chat_Session_Ended__e (after insert) {
    Set<Id> sessionIds = new Set<Id>();
    for (Chat_Session_Ended__e evt : Trigger.new) {
        if (String.isNotBlank(evt.Messaging_Session_Id__c)) {
            sessionIds.add((Id) evt.Messaging_Session_Id__c);
        }
    }
    if (!sessionIds.isEmpty()) {
        System.enqueueJob(new ChatTranscriptQueueable(sessionIds));
    }
}