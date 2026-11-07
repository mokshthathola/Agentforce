@IsTest
private class GetPurchasedProductsTest {
    @TestSetup
    static void setup() {
        Id pbId = Test.getStandardPricebookId();
        Product2 p = new Product2(Name='Test Kettle', ProductCode='TK-1', IsActive=true);
        insert p;
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id=pbId, Product2Id=p.Id, UnitPrice=10, IsActive=true);
        insert pbe;
        Account a = new Account(Name='Test Customer');
        insert a;
        Contact c = new Contact(LastName='Customer', Email='test@example.com', AccountId=a.Id);
        insert c;
        Order o = new Order(AccountId=a.Id, BillToContactId=c.Id, Pricebook2Id=pbId,
                            EffectiveDate=Date.today(), Status='Draft');
        insert o;
        insert new OrderItem(OrderId=o.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=10);
    }

    @IsTest
    static void verifiedCustomerGetsProducts() {
        Order o = [SELECT OrderNumber FROM Order LIMIT 1];
        GetPurchasedProducts.Request r = new GetPurchasedProducts.Request();
        r.email = 'TEST@example.com';
        r.orderNumber = o.OrderNumber;
        GetPurchasedProducts.Response res = GetPurchasedProducts.getPurchasedProducts(
            new List<GetPurchasedProducts.Request>{ r })[0];
        Assert.isTrue(res.verified);
        Assert.isTrue(res.products.contains('Test Kettle'));
    }

    @IsTest
    static void wrongEmailIsRejected() {
        Order o = [SELECT OrderNumber FROM Order LIMIT 1];
        GetPurchasedProducts.Request r = new GetPurchasedProducts.Request();
        r.email = 'someone.else@example.com';
        r.orderNumber = o.OrderNumber;
        GetPurchasedProducts.Response res = GetPurchasedProducts.getPurchasedProducts(
            new List<GetPurchasedProducts.Request>{ r })[0];
        Assert.isFalse(res.verified);
        Assert.isNull(res.products);
    }
}