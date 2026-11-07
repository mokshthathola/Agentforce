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
        public Id orderId;
        @InvocableVariable(label='Contact Id' description='Salesforce Id of the customer. Pass this to the case action.')
        public Id contactId;
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

        // One query for all requests (bulk-safe). USER_MODE enforces the bot user's CRUD/FLS.
        Map<String, Order> ordersByNumber = new Map<String, Order>();
        for (Order o : [
            SELECT Id, OrderNumber, BillToContactId, BillToContact.Email,
                   (SELECT Product2Id, Product2.Name, Product2.ProductCode FROM OrderItems)
            FROM Order
            WHERE OrderNumber IN :orderNumbers
            WITH USER_MODE
        ]) {
            ordersByNumber.put(o.OrderNumber, o);
        }

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
                List<String> lines = new List<String>();
                Integer i = 1;
                for (OrderItem item : o.OrderItems) {
                    lines.add(i + '. ' + item.Product2.Name + ' (' + item.Product2.ProductCode
                        + ') - Product Id: ' + item.Product2Id);
                    i++;
                }
                res.products = String.join(lines, '\n');
                res.message = 'Customer verified. ' + lines.size() + ' product(s) found.';
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