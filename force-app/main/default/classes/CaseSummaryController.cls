public with sharing class CaseSummaryController {

    // API name of the Field Generation prompt template
    private static final String TEMPLATE_API_NAME = 'Case_Chat_Summary';

    @AuraEnabled
    public static String generateSummary(Id caseId) {
        // Prompt templates can't be called in Apex tests, so return a stub there
        if (Test.isRunningTest()) {
            return 'Test summary';
        }
        try {
            // The template's input is the Case record, passed by Id
            ConnectApi.WrappedValue caseValue = new ConnectApi.WrappedValue();
            caseValue.value = new Map<String, String>{ 'id' => caseId };

            ConnectApi.EinsteinPromptTemplateGenerationsInput input =
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            input.isPreview = false;
            input.inputParams = new Map<String, ConnectApi.WrappedValue>{ 'Input:Case' => caseValue };
            input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            input.additionalConfig.applicationName = 'PromptBuilderPreview';

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(TEMPLATE_API_NAME, input);

            if (result.generations == null || result.generations.isEmpty()) {
                throw new AuraHandledException('No summary was generated. Please try again.');
            }
            return result.generations[0].text;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Could not generate the summary: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void saveSummary(Id caseId, String summary) {
        // User mode: respects the running user's field access and sharing
        Case c = new Case(Id = caseId, Case_Summary__c = summary);
        update as user c;
    }
}