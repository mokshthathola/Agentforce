@IsTest
private class CheckAgentAvailabilityTest {
    @IsTest
    static void returnsUnavailableWhenNobodyOnline() {
        CheckAgentAvailability.Request r = new CheckAgentAvailability.Request();
        r.queueDeveloperName = 'Customer_Support_Queue';
        CheckAgentAvailability.Response res = CheckAgentAvailability.check(
            new List<CheckAgentAvailability.Request>{ r })[0];
        Assert.isFalse(res.available);
        Assert.areEqual(0, res.availableAgentCount);
    }

    @IsTest
    static void returnsUnavailableForUnknownQueue() {
        CheckAgentAvailability.Request r = new CheckAgentAvailability.Request();
        r.queueDeveloperName = 'No_Such_Queue';
        Assert.isFalse(CheckAgentAvailability.check(
            new List<CheckAgentAvailability.Request>{ r })[0].available);
    }
}