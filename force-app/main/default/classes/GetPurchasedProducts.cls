public with sharing class GetPurchasedProducts {

    public class Request {
        @InvocableVariable(label='Customer Email' description='The email address the customer used for the order.' required=true)
        public String email;
        @InvocableVariable(label='Order Number' description='The order number the customer gave, for example 00000100 or 100.' required=true)
        public String orderNumber;
    }

    public class Response {
        @InvocableVariable(label='Verified' description='True only if the email and order number belong to the same order.')
        public Boolean verified;
        @InvocableVariable(label='Order Id' description='Salesforce Id of the verified order. Pass this to the case action.')
        public String orderId;
        @InvocableVariable(label='Contact Id' description='Salesforce Id of the customer. Pass this to the case action.')
        public String contactId;
        @InvocableVariable(label='Products' description='Numbered list of products on the order, each with its Product Id.')
        public String products;
        @InvocableVariable(label='Message' description='Short result message for the agent.')
        public String message;
    }

    @InvocableMethod(
        label='Get Purchased Products'
        description='Verifies a customer by email and order number, then returns the products on that order. Use this before showing any order or product details.'
    )
    public static List<Response> getPurchasedProducts(List<Request> requests) {
        // Normalise order numbers: "100" -> "00000100"
        Set<String> orderNumbers = new Set<String>();
        for (Request r : requests) {
            orderNumbers.add(normalise(r.orderNumber));
        }

        // Query 1: orders. Binds are passed by name (avoids the tmpVar issue in the agent runtime).
        // USER_MODE enforces the bot user's object access, field access and sharing.
        Map<String, Order> ordersByNumber = new Map<String, Order>();
        List<Order> foundOrders = Database.queryWithBinds(
            'SELECT Id, OrderNumber, BillToContactId, BillToContact.Email ' +
            'FROM Order WHERE OrderNumber IN :orderNumbers',
            new Map<String, Object>{ 'orderNumbers' => orderNumbers },
            AccessLevel.USER_MODE
        );
        for (Order o : foundOrders) {
            ordersByNumber.put(o.OrderNumber, o);
        }

        // Query 2: the order lines for those orders.
        Set<Id> orderIds = new Set<Id>();
        for (Order o : ordersByNumber.values()) {
            orderIds.add(o.Id);
        }
        Map<Id, List<OrderItem>> itemsByOrder = new Map<Id, List<OrderItem>>();
        if (!orderIds.isEmpty()) {
            List<OrderItem> lines = Database.queryWithBinds(
                'SELECT OrderId, Product2Id, Product2.Name, Product2.ProductCode ' +
                'FROM OrderItem WHERE OrderId IN :orderIds',
                new Map<String, Object>{ 'orderIds' => orderIds },
                AccessLevel.USER_MODE
            );
            for (OrderItem oi : lines) {
                if (!itemsByOrder.containsKey(oi.OrderId)) {
                    itemsByOrder.put(oi.OrderId, new List<OrderItem>());
                }
                itemsByOrder.get(oi.OrderId).add(oi);
            }
        }

        // Build one response per request.
        List<Response> results = new List<Response>();
        for (Request r : requests) {
            Response res = new Response();
            Order o = ordersByNumber.get(normalise(r.orderNumber));

            Boolean match = o != null
                && o.BillToContact != null
                && o.BillToContact.Email != null
                && r.email != null
                && o.BillToContact.Email.equalsIgnoreCase(r.email.trim());

            if (!match) {
                // Same message whether the email or the order number was wrong, so nothing is leaked.
                res.verified = false;
                res.message = 'The email and order number could not be matched.';
            } else {
                res.verified = true;
                res.orderId = o.Id;
                res.contactId = o.BillToContactId;

                List<OrderItem> orderLines = itemsByOrder.containsKey(o.Id)
                    ? itemsByOrder.get(o.Id)
                    : new List<OrderItem>();

                List<String> productLines = new List<String>();
                Integer i = 1;
                for (OrderItem item : orderLines) {
                    productLines.add(i + '. ' + item.Product2.Name + ' (' + item.Product2.ProductCode
                        + ') - Product Id: ' + item.Product2Id);
                    i++;
                }
                res.products = String.join(productLines, '\n');
                res.message = 'Customer verified. ' + productLines.size() + ' product(s) found.';
            }
            results.add(res);
        }
        return results;
    }

    private static String normalise(String orderNumber) {
        String s = orderNumber == null ? '' : orderNumber.trim();
        if (s.isNumeric() && s.length() < 8) {
            s = s.leftPad(8, '0');
        }
        return s;
    }
}