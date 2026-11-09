public with sharing class ChatTranscriptQueueable implements Queueable, Database.AllowsCallouts {

    private final Set<Id> sessionIds;

    public ChatTranscriptQueueable(Set<Id> sessionIds) {
        this.sessionIds = sessionIds;
    }

    public void execute(QueueableContext context) {
        List<MessagingSession> sessions = [
            SELECT Id, Conversation.ConversationIdentifier
            FROM MessagingSession
            WHERE Id IN :sessionIds
            WITH USER_MODE
        ];

        // 1. All callouts first: no DML is allowed before a callout in the same transaction
        List<MessagingSession> toUpdate = new List<MessagingSession>();
        for (MessagingSession s : sessions) {
            String conversationId = s.Conversation?.ConversationIdentifier;
            if (String.isBlank(conversationId)) {
                continue;
            }
            try {
                String transcript = ChatTranscriptService.fetchTranscript(conversationId);
                if (String.isNotBlank(transcript)) {
                    toUpdate.add(new MessagingSession(Id = s.Id, Chat_Transcript__c = transcript));
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Transcript error for ' + s.Id + ': ' + e.getMessage());
            }
        }
        if (toUpdate.isEmpty()) {
            return;
        }

        // 2. Then one DML for all sessions
        update as user toUpdate;

        // 3. Chain Job 2 (prompt template) in a new transaction
        if (!Test.isRunningTest()) {
            System.enqueueJob(new ChatSummaryQueueable(new Map<Id, MessagingSession>(toUpdate).keySet()));
        }
    }
}