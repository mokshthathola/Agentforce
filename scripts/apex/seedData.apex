Pricebook2 stdPb = [SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
if (!stdPb.IsActive) { stdPb.IsActive = true; update stdPb; }

List<Product2> products = new List<Product2>{
    new Product2(Name='Cordless Vacuum V8', ProductCode='VAC-V8', Family='Home Appliances', Description='Cordless stick vacuum, 40-minute battery', IsActive=true),
    new Product2(Name='Air Fryer 5L', ProductCode='AF-5L', Family='Kitchen', Description='5 litre digital air fryer', IsActive=true),
    new Product2(Name='Bluetooth Headphones X2', ProductCode='HP-X2', Family='Electronics', Description='Wireless over-ear headphones', IsActive=true),
    new Product2(Name='Electric Kettle 1.7L', ProductCode='KT-17', Family='Kitchen', Description='1.7 litre stainless steel kettle', IsActive=true),
    new Product2(Name='Smart LED Bulb Pack', ProductCode='LED-4', Family='Electronics', Description='Pack of 4 Wi-Fi LED bulbs', IsActive=true),
    new Product2(Name='Protein Granola 500g', ProductCode='FD-GR500', Family='Food', Description='Oat and nut protein granola', IsActive=true)
};
insert products;

Decimal[] prices = new Decimal[]{199.99, 89.99, 59.99, 29.99, 24.99, 4.99};
List<PricebookEntry> pbes = new List<PricebookEntry>();
for (Integer i = 0; i < products.size(); i++) {
    pbes.add(new PricebookEntry(Pricebook2Id=stdPb.Id, Product2Id=products[i].Id, UnitPrice=prices[i], IsActive=true));
}
insert pbes;

List<Account> accts = new List<Account>{
    new Account(Name='Riya Sharma'), new Account(Name='Arjun Mehta'), new Account(Name='Emma Wilson')
};
insert accts;

List<Contact> cons = new List<Contact>{
    new Contact(FirstName='Riya', LastName='Sharma', Email='riya.sharma@example.com', AccountId=accts[0].Id),
    new Contact(FirstName='Arjun', LastName='Mehta', Email='arjun.mehta@example.com', AccountId=accts[1].Id),
    new Contact(FirstName='Emma', LastName='Wilson', Email='emma.wilson@example.com', AccountId=accts[2].Id)
};
insert cons;

List<Order> orders = new List<Order>{
    new Order(AccountId=accts[0].Id, BillToContactId=cons[0].Id, Pricebook2Id=stdPb.Id, EffectiveDate=Date.today().addDays(-12), Status='Draft'),
    new Order(AccountId=accts[0].Id, BillToContactId=cons[0].Id, Pricebook2Id=stdPb.Id, EffectiveDate=Date.today().addDays(-40), Status='Draft'),
    new Order(AccountId=accts[1].Id, BillToContactId=cons[1].Id, Pricebook2Id=stdPb.Id, EffectiveDate=Date.today().addDays(-5), Status='Draft'),
    new Order(AccountId=accts[2].Id, BillToContactId=cons[2].Id, Pricebook2Id=stdPb.Id, EffectiveDate=Date.today().addDays(-20), Status='Draft')
};
insert orders;

// order index => product indexes on that order
Map<Integer, List<Integer>> lines = new Map<Integer, List<Integer>>{
    0 => new List<Integer>{0, 5},
    1 => new List<Integer>{1},
    2 => new List<Integer>{2, 3},
    3 => new List<Integer>{4, 5, 1}
};
List<OrderItem> items = new List<OrderItem>();
for (Integer o : lines.keySet()) {
    for (Integer p : lines.get(o)) {
        items.add(new OrderItem(OrderId=orders[o].Id, PricebookEntryId=pbes[p].Id, Quantity=1, UnitPrice=prices[p]));
    }
}
insert items;

for (Order o : [SELECT OrderNumber, BillToContact.Email FROM Order WHERE Id IN :orders]) {
    System.debug('ORDER ' + o.OrderNumber + ' -> ' + o.BillToContact.Email);
}