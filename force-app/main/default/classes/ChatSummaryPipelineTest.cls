@IsTest
private class ChatSummaryPipelineTest {

    // Out of order, with one empty message, to test sorting and filtering
    private static final String SAMPLE_JSON = '{"conversationEntries":['
        + '{"clientTimestamp":3000,"messageText":"Your case number is 00001001.","sender":{"role":"Chatbot"}},'
        + '{"clientTimestamp":1000,"messageText":"My kettle is leaking","sender":{"role":"EndUser"}},'
        + '{"clientTimestamp":2000,"messageText":"","sender":{"role":"Chatbot"}},'
        + '{"clientTimestamp":2500,"messageText":"I can help with that.","sender":{"role":"Agent"}}'
        + ']}';

    private class TranscriptMock implements HttpCalloutMock {
        private Integer statusCode;
        TranscriptMock(Integer statusCode) { this.statusCode = statusCode; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(statusCode == 200 ? SAMPLE_JSON : '{"error":"failed"}');
            return res;
        }
    }

    private static Id fakeSessionId() {
        return Id.valueOf('0Mw000000000000');
    }

    @IsTest
    static void buildsTranscriptOldestFirstWithLabels() {
        String transcript = ChatTranscriptService.buildTranscript(SAMPLE_JSON);
        Assert.areEqual(
            'Customer: My kettle is leaking\nAgent: I can help with that.\nBot: Your case number is 00001001.',
            transcript);
    }

    @IsTest
    static void returnsNullWhenNoEntries() {
        Assert.isNull(ChatTranscriptService.buildTranscript('{"conversationEntries":[]}'));
    }

    @IsTest
    static void fetchesTranscriptThroughCallout() {
        Test.setMock(HttpCalloutMock.class, new TranscriptMock(200));
        Test.startTest();
        String transcript = ChatTranscriptService.fetchTranscript('abc-123');
        Test.stopTest();
        Assert.isTrue(transcript.startsWith('Customer:'));
    }

    @IsTest
    static void returnsNullWhenCalloutFails() {
        Test.setMock(HttpCalloutMock.class, new TranscriptMock(500));
        Test.startTest();
        String transcript = ChatTranscriptService.fetchTranscript('abc-123');
        Test.stopTest();
        Assert.isNull(transcript);
    }

    @IsTest
    static void eventRunsPipelineWithoutErrors() {
        Test.setMock(HttpCalloutMock.class, new TranscriptMock(200));
        Test.startTest();
        EventBus.publish(new Chat_Session_Ended__e(Messaging_Session_Id__c = fakeSessionId()));
        Test.getEventBus().deliver();
        System.enqueueJob(new ChatSummaryQueueable(new Set<Id>{ fakeSessionId() }));
        Test.stopTest();
        Assert.areEqual('Test chat summary', ChatSummaryQueueable.generate(fakeSessionId()));
    }
}