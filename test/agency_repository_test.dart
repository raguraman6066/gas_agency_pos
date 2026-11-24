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
    expect(snapshot.customers, hasLength(30));
    expect(snapshot.products, hasLength(5));
    expect(snapshot.orders, hasLength(40));
    expect(snapshot.deliveries, isNotEmpty);
    expect(snapshot.inventory, hasLength(5));
    expect(snapshot.payments, isNotEmpty);
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
    await repository.updateOrder(order.copyWith(status: 'Cancelled'));
    await repository.updateOrder(order.copyWith(status: 'Cancelled'));
    snapshot = await repository.load();
    expect(
      snapshot.inventory
          .firstWhere((item) => item.productId == product.id)
          .booked,
      booked - order.quantity,
    );
    expect(
      snapshot.orders.firstWhere((item) => item.id == order.id).status,
      'Cancelled',
    );
  });
}
