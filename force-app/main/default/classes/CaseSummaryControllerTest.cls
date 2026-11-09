@IsTest
private class CaseSummaryControllerTest {
    @IsTest
    static void generatesAndSavesSummary() {
        Case c = new Case(Subject = 'Kettle leaking', Origin = 'Web', Status = 'New');
        insert c;

        Test.startTest();
        String summary = CaseSummaryController.generateSummary(c.Id);
        CaseSummaryController.saveSummary(c.Id, summary + ' (edited)');
        Test.stopTest();

        Assert.areEqual('Test summary (edited)',
            [SELECT Case_Summary__c FROM Case WHERE Id = :c.Id].Case_Summary__c);
    }
}