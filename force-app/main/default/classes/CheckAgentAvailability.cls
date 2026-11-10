public without sharing class CheckAgentAvailability {
    // without sharing: reads only staff presence data (no customer data).
    // The bot user's license can't read Omni presence objects in user mode.

    public class Request {
        @InvocableVariable(label='Queue Developer Name'
            description='API name of the human support queue, for example Customer_Support_Queue.'
            required=true)
        public String queueDeveloperName;
    }

    public class Response {
        @InvocableVariable(label='Agents Available'
            description='True if at least one human agent in the queue is online and available right now.')
        public Boolean available;
        @InvocableVariable(label='Available Agent Count'
            description='Number of human agents currently online for the queue.')
        public Integer availableAgentCount;
    }

    @InvocableMethod(
        label='Check Agent Availability'
        description='Checks whether any human support agent is online and available right now. Run this before transferring a customer to a human agent.'
    )
    public static List<Response> check(List<Request> requests) {
        Set<String> queueNames = new Set<String>();
        for (Request r : requests) {
            queueNames.add(r.queueDeveloperName);
        }

        // Queue members (users) per queue
        Map<String, Set<Id>> usersByQueue = new Map<String, Set<Id>>();
        Set<Id> allUserIds = new Set<Id>();
        for (GroupMember gm : [
            SELECT UserOrGroupId, Group.DeveloperName
            FROM GroupMember
            WHERE Group.Type = 'Queue' AND Group.DeveloperName IN :queueNames
        ]) {
            if (String.valueOf(gm.UserOrGroupId).startsWith('005')) { // users only
                if (!usersByQueue.containsKey(gm.Group.DeveloperName)) {
                    usersByQueue.put(gm.Group.DeveloperName, new Set<Id>());
                }
                usersByQueue.get(gm.Group.DeveloperName).add(gm.UserOrGroupId);
                allUserIds.add(gm.UserOrGroupId);
            }
        }

        // Users whose current Omni-Channel status is online (not away)
        Set<Id> onlineUserIds = new Set<Id>();
        if (!allUserIds.isEmpty()) {
            for (UserServicePresence p : [
                SELECT UserId
                FROM UserServicePresence
                WHERE UserId IN :allUserIds AND IsCurrentState = true AND IsAway = false
            ]) {
                onlineUserIds.add(p.UserId);
            }
        }

        List<Response> results = new List<Response>();
        for (Request r : requests) {
            Integer count = 0;
            Set<Id> members = usersByQueue.get(r.queueDeveloperName);
            if (members != null) {
                for (Id userId : members) {
                    if (onlineUserIds.contains(userId)) {
                        count++;
                    }
                }
            }
            Response res = new Response();
            res.availableAgentCount = count;
            res.available = count > 0;
            results.add(res);
        }
        return results;
    }
}