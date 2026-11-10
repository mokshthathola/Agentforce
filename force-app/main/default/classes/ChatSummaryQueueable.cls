public with sharing class ChatSummaryQueueable implements Queueable, Database.AllowsCallouts {

    private static final String TEMPLATE_API_NAME = 'Chat_Summary'; // check in Prompt Builder
    private final Set<Id> sessionIds;

    public ChatSummaryQueueable(Set<Id> sessionIds) {
        this.sessionIds = sessionIds;
    }

    public void execute(QueueableContext context) {
        List<MessagingSession> toUpdate = new List<MessagingSession>();

        // Long text fields can't be filtered in WHERE, so check the transcript in Apex
        for (MessagingSession s : [
            SELECT Id, Chat_Transcript__c
            FROM MessagingSession
            WHERE Id IN :sessionIds
            WITH USER_MODE
        ]) {
            if (String.isBlank(s.Chat_Transcript__c)) {
                continue;
            }
            try {
                String summary = generate(s.Id);
                if (String.isNotBlank(summary)) {
                    toUpdate.add(new MessagingSession(Id = s.Id, Chat_Summary__c = summary));
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Summary error for ' + s.Id + ': ' + e.getMessage());
            }
        }
        if (!toUpdate.isEmpty()) {
            update as user toUpdate; // fires "Copy Chat Summary to Case"
        }
    }

    @TestVisible
    private static String generate(Id sessionId) {
        if (Test.isRunningTest()) {
            return 'Test chat summary';
        }
        ConnectApi.WrappedValue sessionValue = new ConnectApi.WrappedValue();
        sessionValue.value = new Map<String, String>{ 'id' => sessionId };

        ConnectApi.EinsteinPromptTemplateGenerationsInput input =
            new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        input.isPreview = false;
        input.inputParams = new Map<String, ConnectApi.WrappedValue>{ 'Input:MessagingSession' => sessionValue };
        input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        input.additionalConfig.applicationName = 'PromptBuilderPreview';

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(TEMPLATE_API_NAME, input);
        if (result.generations == null || result.generations.isEmpty()) {
            return null;
        }
        return result.generations[0].text;
    }
}