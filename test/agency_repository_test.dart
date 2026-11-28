import 'package:flutter_test/flutter_test.dart';
import 'package:gas_agencies/core/data/dummy_agency_repository.dart';
import 'package:gas_agencies/core/domain/models.dart';

void main() {
  late DummyAgencyRepository repository;

  setUp(() {
    repository = DummyAgencyRepository();
  });

  test('dummy repository seeds the requested core records', () async {
    final snapshot = await repository.load();
    expect(snapshot.customers, hasLength(2));
    expect(
      snapshot.customers.map((customer) => customer.name).toSet(),
      hasLength(2),
    );
    expect(snapshot.products, hasLength(2));
    expect(snapshot.orders, hasLength(2));
    expect(snapshot.deliveries, hasLength(2));
    expect(snapshot.inventory, hasLength(2));
    expect(snapshot.payments, hasLength(1));
    expect(snapshot.staff, hasLength(2));
    expect(snapshot.movements, hasLength(2));
  });

  test('customer tax and gas service fields survive map conversion', () {
    final customer = Customer(
      id: 'customer-1',
      name: 'Test Customer',
      consumerNumber: 'CN-123',
      phone: '9876543210',
      address: '12 Main Road',
      area: 'Central',
      gstNumber: 'GST-123',
      identityDocumentType: 'PAN',
      identityDocumentNumber: 'ABCDE1234F',
      gasProvider: 'Indane',
      createdAt: DateTime(2026, 1, 1),
    );

    expect(Customer.fromMap(customer.toMap()).toMap(), customer.toMap());
    expect(customer.copyWith(gasProvider: 'HP Gas').gasProvider, 'HP Gas');
  });

  test(
    'delivery deducts stock once and payment balance is validated',
    () async {
      var before = await repository.load();
      final product = before.products.first;
      final customer = before.customers.first;
      final startingInventory = before.inventory.firstWhere(
        (item) => item.productId == product.id,
      );
      final newOrder = AgencyOrder(
        id: 'temporary',
        number: '',
        customerId: customer.id,
        productId: product.id,
        quantity: 1,
        unitPrice: product.price,
        status: 'Pending',
        createdAt: DateTime.now(),
      );
      await repository.createOrder(newOrder);
      var snapshot = await repository.load();
      final order = snapshot.orders.first;
      final delivery = snapshot.deliveries.firstWhere(
        (item) => item.orderId == order.id,
      );
      expect(
        snapshot.inventory
            .firstWhere((item) => item.productId == product.id)
            .booked,
        startingInventory.booked + 1,
      );

      await repository.updateDelivery(
        Delivery(
          id: delivery.id,
          orderId: order.id,
          status: 'Assigned',
          staffId: snapshot.staff.last.id,
        ),
      );
      await repository.updateDelivery(
        Delivery(
          id: delivery.id,
          orderId: order.id,
          status: 'Delivered',
          staffId: snapshot.staff.last.id,
        ),
      );
      snapshot = await repository.load();
      final deliveredInventory = snapshot.inventory.firstWhere(
        (item) => item.productId == product.id,
      );
      expect(deliveredInventory.filled, startingInventory.filled - 1);
      expect(deliveredInventory.empty, startingInventory.empty + 1);
      expect(deliveredInventory.booked, startingInventory.booked);

      await expectLater(
        repository.updateDelivery(
          Delivery(id: delivery.id, orderId: order.id, status: 'Delivered'),
        ),
        throwsStateError,
      );
      await repository.recordPayment(
        Payment(
          id: 'payment-1',
          orderId: order.id,
          amount: order.total / 2,
          method: 'Cash',
          date: DateTime.now(),
        ),
      );
      await repository.recordPayment(
        Payment(
          id: 'payment-2',
          orderId: order.id,
          amount: order.total / 2,
          method: 'UPI',
          date: DateTime.now(),
        ),
      );
      await expectLater(
        repository.recordPayment(
          Payment(
            id: 'payment-3',
            orderId: order.id,
            amount: 1,
            method: 'Other',
            date: DateTime.now(),
          ),
        ),
        throwsStateError,
      );
    },
  );

  test('booking reserves stock and empty returns update stock once', () async {
    final before = await repository.load();
    final product = before.products.first;
    Inventory stock(AgencySnapshot data) =>
        data.inventory.firstWhere((item) => item.productId == product.id);
    await repository.createOrder(
      AgencyOrder(
        id: 'temporary',
        number: '',
        customerId: before.customers.first.id,
        productId: product.id,
        quantity: 3,
        unitPrice: product.price,
        status: 'Ready for Delivery',
        createdAt: DateTime.now(),
      ),
    );
    final booked = await repository.load();
    final order = booked.orders.first;
    final delivery = booked.deliveries.firstWhere(
      (item) => item.orderId == order.id,
    );
    expect(order.status, 'Ready for Delivery');
    expect(stock(booked).available, stock(before).available - 3);
    expect(stock(booked).filled, stock(before).filled);

    expect(delivery.status, 'Pending');
    expect(delivery.staffId, isNull);
    await expectLater(
      repository.updateDelivery(
        Delivery(id: delivery.id, orderId: order.id, status: 'Delivered'),
      ),
      throwsStateError,
    );
    await repository.updateDelivery(
      Delivery(
        id: delivery.id,
        orderId: order.id,
        status: 'Assigned',
        staffId: booked.staff.last.id,
      ),
    );
    await repository.updateDelivery(
      Delivery(
        id: delivery.id,
        orderId: order.id,
        status: 'Delivered',
        deliveredQuantity: 3,
        returnedEmpty: 1,
        damagedEmpty: 1,
      ),
    );
    final completed = await repository.load();
    expect(stock(completed).available, stock(booked).available);
    expect(
      completed.deliveries
          .firstWhere((item) => item.id == delivery.id)
          .pendingEmpty,
      1,
    );
    expect(stock(completed).empty, stock(before).empty + 1);
    expect(stock(completed).damaged, stock(before).damaged + 1);

    await repository.recordEmptyReturns(order.id, 2, 1);
    await repository.recordEmptyReturns(order.id, 2, 1);
    await expectLater(
      repository.recordEmptyReturns(order.id, 3, 1),
      throwsStateError,
    );
    final collected = await repository.load();
    expect(
      collected.deliveries
          .firstWhere((item) => item.id == delivery.id)
          .pendingEmpty,
      0,
    );
    expect(stock(collected).empty, stock(before).empty + 2);
    expect(stock(collected).damaged, stock(before).damaged + 1);
    expect(stock(collected).filled, stock(before).filled - 3);
  });

  test('cancelling an order releases booked stock exactly once', () async {
    final before = await repository.load();
    final product = before.products.first;
    await repository.createOrder(
      AgencyOrder(
        id: 'temporary',
        number: '',
        customerId: before.customers.first.id,
        productId: product.id,
        quantity: 2,
        unitPrice: product.price,
        status: 'Pending',
        createdAt: DateTime.now(),
      ),
    );
    var snapshot = await repository.load();
    final order = snapshot.orders.first;
    final booked = snapshot.inventory
        .firstWhere((item) => item.productId == product.id)
        .booked;
    final delivery = snapshot.deliveries.firstWhere(
      (item) => item.orderId == order.id,
    );
    await repository.updateDelivery(
      Delivery(
        id: delivery.id,
        orderId: order.id,
        status: 'Assigned',
        staffId: snapshot.staff.last.id,
      ),
    );
    await repository.deleteOrder(order.id);
    await repository.deleteOrder(order.id);
    snapshot = await repository.load();
    expect(
      snapshot.inventory
          .firstWhere((item) => item.productId == product.id)
          .booked,
      booked - order.quantity,
    );
    final originalStock = before.inventory.firstWhere(
      (item) => item.productId == product.id,
    );
    final restoredStock = snapshot.inventory.firstWhere(
      (item) => item.productId == product.id,
    );
    expect(restoredStock.available, originalStock.available);
    expect(restoredStock.filled, originalStock.filled);
    expect(
      snapshot.deliveries
          .firstWhere((item) => item.orderId == order.id)
          .staffId,
      isNull,
    );
    expect(
      snapshot.orders.firstWhere((item) => item.id == order.id).status,
      'Cancelled',
    );
  });
}
