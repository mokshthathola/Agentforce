public with sharing class ChatTranscriptService {

    public static final String API_VERSION = 'v62.0';

    // Calls the Conversation Entries API through the SelfOrg Named Credential
    public static String fetchTranscript(String conversationIdentifier) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:SelfOrg/services/data/' + API_VERSION
            + '/connect/conversation/'
            + EncodingUtil.urlEncode(conversationIdentifier, 'UTF-8') + '/entries');
        req.setMethod('GET');
        req.setTimeout(20000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            System.debug(LoggingLevel.ERROR, 'Transcript fetch failed: '
                + res.getStatusCode() + ' ' + res.getBody());
            return null;
        }
        return buildTranscript(res.getBody());
    }

    // Parses the JSON, drops empty entries, sorts oldest first, labels each speaker
    public static String buildTranscript(String jsonBody) {
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        List<Object> entries = (List<Object>) body.get('conversationEntries');
        if (entries == null || entries.isEmpty()) {
            return null;
        }

        List<Line> lines = new List<Line>();
        for (Object o : entries) {
            Map<String, Object> e = (Map<String, Object>) o;
            String text = (String) e.get('messageText');
            if (String.isBlank(text)) {
                continue;
            }
            Map<String, Object> sender = (Map<String, Object>) e.get('sender');
            String role = sender == null ? null : (String) sender.get('role');
            Object ts = e.get('clientTimestamp');
            Long timestamp = ts == null ? 0 : Long.valueOf(String.valueOf(ts));
            lines.add(new Line(timestamp, label(role), text.trim()));
        }
        if (lines.isEmpty()) {
            return null;
        }

        lines.sort(); // uses Line.compareTo: oldest first

        List<String> output = new List<String>();
        for (Line l : lines) {
            output.add(l.speaker + ': ' + l.text);
        }
        return String.join(output, '\n').left(131072); // field limit
    }

    private static String label(String role) {
        if (role == 'EndUser') { return 'Customer'; }
        if (role == 'Chatbot') { return 'Bot'; }
        if (role == 'Agent')   { return 'Agent'; }
        return String.isBlank(role) ? 'Unknown' : role;
    }

    public class Line implements Comparable {
        public Long ts;
        public String speaker;
        public String text;

        public Line(Long ts, String speaker, String text) {
            this.ts = ts;
            this.speaker = speaker;
            this.text = text;
        }

        public Integer compareTo(Object other) {
            Long otherTs = ((Line) other).ts;
            if (ts == otherTs) { return 0; }
            return ts > otherTs ? 1 : -1;
        }
    }
}