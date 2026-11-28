import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import 'agency_repository.dart';

class DummyAgencyRepository implements AgencyRepository {
  DummyAgencyRepository() {
    _seed();
  }

  final _uuid = const Uuid();
  late List<Customer> _customers;
  late List<Product> _products;
  late List<AgencyOrder> _orders;
  late List<Delivery> _deliveries;
  late List<Inventory> _inventory;
  late List<Payment> _payments;
  late List<StaffMember> _staff;
  late List<InventoryMovement> _movements;
  int _nextOrder = 1003;
  AgencySettings _settings = const AgencySettings();

  @override
  Future<void> saveSettings(AgencySettings settings) async {
    _settings = settings;
  }

  @override
  Future<AgencySnapshot> load() async => AgencySnapshot(
    settings: _settings,
    customers: List.unmodifiable(_customers),
    products: List.unmodifiable(_products),
    orders: List.unmodifiable(_orders),
    deliveries: List.unmodifiable(_deliveries),
    inventory: List.unmodifiable(_inventory),
    payments: List.unmodifiable(_payments),
    staff: List.unmodifiable(_staff),
    movements: List.unmodifiable(_movements),
  );
  void _seed() {
    final now = DateTime.now();
    _products = const [
      Product(
        id: 'p1',
        name: 'Domestic LPG',
        type: 'Domestic',
        sizeKg: 14,
        price: 980,
      ),
      Product(
        id: 'p2',
        name: 'Commercial LPG',
        type: 'Commercial',
        sizeKg: 19,
        price: 1680,
      ),
    ];
    final customerSince = now.subtract(const Duration(days: 30));
    _customers = [
      Customer(
        id: 'c1',
        name: 'Aarav Sharma',
        consumerNumber: 'CN-24001',
        phone: '9810000000',
        address: '12 Central Main Road',
        area: 'Central',
        createdAt: customerSince,
        type: 'Domestic',
      ),
      Customer(
        id: 'c2',
        name: 'Ananya Reddy',
        consumerNumber: 'CN-24002',
        phone: '9810017391',
        address: '13 North Park Main Road',
        area: 'North Park',
        createdAt: customerSince,
        type: 'Commercial',
      ),
    ];
    _staff = [
      const StaffMember(
        id: 's1',
        name: 'Anil Kumar',
        email: 'admin@gasagency.demo',
        phone: '9876500001',
        role: 'Admin',
      ),
      const StaffMember(
        id: 's2',
        name: 'Suresh Rao',
        email: 'staff@gasagency.demo',
        phone: '9876500002',
        role: 'Staff',
      ),
    ];
    final pending = AgencyOrder(
      id: 'o1',
      number: 'GA-1001',
      customerId: 'c1',
      productId: 'p1',
      quantity: 2,
      unitPrice: _products[0].price,
      status: 'Ready for Delivery',
      createdAt: now,
      notes: 'Please call before delivery',
    );
    final delivered = AgencyOrder(
      id: 'o2',
      number: 'GA-1002',
      customerId: 'c2',
      productId: 'p2',
      quantity: 3,
      unitPrice: _products[1].price,
      status: 'Delivered',
      createdAt: now,
    );
    _orders = [pending, delivered];
    _deliveries = [
      Delivery(
        id: 'd1',
        orderId: pending.id,
        status: 'Pending',
        createdAt: now,
      ),
      Delivery(
        id: 'd2',
        orderId: delivered.id,
        status: 'Delivered',
        staffId: 's2',
        createdAt: now,
        deliveredAt: now,
        deliveredQuantity: delivered.quantity,
        returnedEmpty: 1,
        damagedEmpty: 1,
      ),
    ];
    _inventory = [
      Inventory(
        productId: pending.productId,
        filled: 12,
        empty: 4,
        booked: pending.quantity,
      ),
      Inventory(
        productId: delivered.productId,
        filled: 7,
        empty: 3,
        damaged: 1,
        delivered: delivered.quantity,
      ),
    ];
    _payments = [
      Payment(
        id: 'pay-o2',
        orderId: delivered.id,
        amount: delivered.total / 2,
        method: 'UPI',
        date: now,
        reference: 'DEMO-UPI-2',
      ),
    ];
    _movements = _inventory
        .map(
          (item) => InventoryMovement(
            id: _uuid.v4(),
            productId: item.productId,
            kind: 'Demo stock balance',
            filledChange: item.filled,
            emptyChange: item.empty,
            bookedChange: item.booked,
            damagedChange: item.damaged,
            createdAt: now,
          ),
        )
        .toList();
  }

  @override
  Future<void> saveCustomer(Customer customer) async {
    if (_customers.any(
      (c) => c.consumerNumber == customer.consumerNumber && c.id != customer.id,
    )) {
      throw StateError('Consumer number already exists.');
    }
    _replace(_customers, customer, (item) => item.id);
  }

  @override
  Future<void> saveProduct(Product product) async {
    _replace(_products, product, (item) => item.id);
    if (!_inventory.any((item) => item.productId == product.id)) {
      _inventory.add(Inventory(productId: product.id, filled: 0, empty: 0));
    }
  }

  @override
  Future<void> saveStaff(StaffMember member) async => _saveStaff(member);

  void _saveStaff(StaffMember member) {
    if (_staff.any(
      (item) =>
          item.email.toLowerCase() == member.email.toLowerCase() &&
          item.id != member.id,
    )) {
      throw StateError('A staff member already uses this email address.');
    }
    _replace(_staff, member, (item) => item.id);
  }

  @override
  Future<void> createOrder(AgencyOrder order) async {
    if (order.quantity <= 0) {
      throw StateError('Quantity must be greater than zero.');
    }
    final customer = _customers
        .where((item) => item.id == order.customerId)
        .firstOrNull;
    if (customer == null || !customer.active) {
      throw StateError('Customer is unavailable.');
    }
    final product = _products
        .where((item) => item.id == order.productId)
        .firstOrNull;
    if (product == null || !product.active) {
      throw StateError('Product is unavailable.');
    }
    final inventory = _inventory.firstWhere(
      (item) => item.productId == order.productId,
    );
    if (inventory.available < order.quantity) {
      throw StateError('Not enough filled cylinders available.');
    }
    _validateOrderPrice(order, product.price);
    final number = 'GA-${_nextOrder++}';
    final saved = AgencyOrder(
      id: _uuid.v4(),
      number: number,
      customerId: order.customerId,
      productId: order.productId,
      quantity: order.quantity,
      unitPrice: product.price,
      deliveryCharge: order.deliveryCharge,
      discount: order.discount,
      status: 'Ready for Delivery',
      createdAt: DateTime.now(),
      notes: order.notes,
    );
    _orders.insert(0, saved);
    _inventory[_inventory.indexOf(inventory)] = Inventory(
      productId: inventory.productId,
      filled: inventory.filled,
      empty: inventory.empty,
      booked: inventory.booked + order.quantity,
      delivered: inventory.delivered,
      minimum: inventory.minimum,
      damaged: inventory.damaged,
    );
    _movements.insert(
      0,
      InventoryMovement(
        id: _uuid.v4(),
        productId: product.id,
        kind: 'Order booked',
        filledChange: 0,
        emptyChange: 0,
        bookedChange: order.quantity,
        createdAt: DateTime.now(),
        note: number,
      ),
    );
    _deliveries.insert(
      0,
      Delivery(
        id: _uuid.v4(),
        orderId: saved.id,
        status: 'Pending',
        createdAt: saved.createdAt,
      ),
    );
  }

  @override
  Future<void> updateOrder(AgencyOrder order) async {
    final old = _orders.firstWhere((item) => item.id == order.id);
    if (old.status == 'Cancelled' && order.status == 'Cancelled') return;
    if (old.status == 'Delivered' || old.status == 'Cancelled') {
      throw StateError('This order can no longer be edited.');
    }
    if (order.status == 'Cancelled' &&
        _payments
                .where((payment) => payment.orderId == order.id)
                .fold<double>(0, (total, payment) => total + payment.amount) >
            0.001) {
      throw StateError('An order with recorded payments cannot be cancelled.');
    }
    if (order.quantity <= 0) {
      throw StateError('Quantity must be greater than zero.');
    }
    final oldInventory = _inventory.firstWhere(
      (item) => item.productId == old.productId,
    );
    final newInventory = _inventory.firstWhere(
      (item) => item.productId == order.productId,
    );
    if (order.status != 'Cancelled') {
      final customer = _customers
          .where((item) => item.id == order.customerId)
          .firstOrNull;
      final product = _products
          .where((item) => item.id == order.productId)
          .firstOrNull;
      if (customer == null || !customer.active) {
        throw StateError('Customer is unavailable.');
      }
      if (product == null || !product.active) {
        throw StateError('Product is unavailable.');
      }
      _validateOrderPrice(order, product.price);
      final paid = _payments
          .where((payment) => payment.orderId == old.id)
          .fold<double>(0, (sum, payment) => sum + payment.amount);
      if (paid > 0 &&
          (order.customerId != old.customerId ||
              paid >
                  product.price * order.quantity +
                      order.deliveryCharge -
                      order.discount +
                      0.001)) {
        throw StateError(
          'The booking change conflicts with recorded payments.',
        );
      }
    }
    final sameProduct = old.productId == order.productId;
    final available = sameProduct
        ? oldInventory.available + old.quantity
        : newInventory.available;
    if (order.status != 'Cancelled' && available < order.quantity) {
      throw StateError('Not enough filled cylinders available.');
    }
    if (order.status == 'Cancelled') {
      _inventory[_inventory.indexOf(oldInventory)] = Inventory(
        productId: oldInventory.productId,
        filled: oldInventory.filled,
        empty: oldInventory.empty,
        booked: oldInventory.booked - old.quantity,
        delivered: oldInventory.delivered,
        minimum: oldInventory.minimum,
        damaged: oldInventory.damaged,
      );
      _movements.insert(
        0,
        InventoryMovement(
          id: _uuid.v4(),
          productId: oldInventory.productId,
          kind: 'Order cancelled',
          filledChange: 0,
          emptyChange: 0,
          bookedChange: -old.quantity,
          createdAt: DateTime.now(),
          note: old.number,
        ),
      );
      final delivery = _deliveries
          .where((item) => item.orderId == order.id)
          .firstOrNull;
      if (delivery != null) {
        _replace(
          _deliveries,
          Delivery(
            id: delivery.id,
            orderId: delivery.orderId,
            status: 'Pending',
            createdAt: delivery.createdAt,
            updatedAt: DateTime.now(),
            notes: delivery.notes,
          ),
          (item) => item.orderId,
        );
      }
    } else if (sameProduct) {
      _inventory[_inventory.indexOf(oldInventory)] = Inventory(
        productId: oldInventory.productId,
        filled: oldInventory.filled,
        empty: oldInventory.empty,
        booked: oldInventory.booked - old.quantity + order.quantity,
        delivered: oldInventory.delivered,
        minimum: oldInventory.minimum,
        damaged: oldInventory.damaged,
      );
      if (order.quantity != old.quantity) {
        _movements.insert(
          0,
          InventoryMovement(
            id: _uuid.v4(),
            productId: oldInventory.productId,
            kind: 'Order changed',
            filledChange: 0,
            emptyChange: 0,
            bookedChange: order.quantity - old.quantity,
            createdAt: DateTime.now(),
            note: old.number,
          ),
        );
      }
    } else {
      _inventory[_inventory.indexOf(oldInventory)] = Inventory(
        productId: oldInventory.productId,
        filled: oldInventory.filled,
        empty: oldInventory.empty,
        booked: oldInventory.booked - old.quantity,
        delivered: oldInventory.delivered,
        minimum: oldInventory.minimum,
        damaged: oldInventory.damaged,
      );
      _inventory[_inventory.indexOf(newInventory)] = Inventory(
        productId: newInventory.productId,
        filled: newInventory.filled,
        empty: newInventory.empty,
        booked: newInventory.booked + order.quantity,
        delivered: newInventory.delivered,
        minimum: newInventory.minimum,
        damaged: newInventory.damaged,
      );
      _movements.insertAll(0, [
        InventoryMovement(
          id: _uuid.v4(),
          productId: oldInventory.productId,
          kind: 'Order changed',
          filledChange: 0,
          emptyChange: 0,
          bookedChange: -old.quantity,
          createdAt: DateTime.now(),
          note: old.number,
        ),
        InventoryMovement(
          id: _uuid.v4(),
          productId: newInventory.productId,
          kind: 'Order changed',
          filledChange: 0,
          emptyChange: 0,
          bookedChange: order.quantity,
          createdAt: DateTime.now(),
          note: old.number,
        ),
      ]);
    }
    final product = _products
        .where((item) => item.id == order.productId)
        .firstOrNull;
    _replace(
      _orders,
      order.status == 'Cancelled' || product == null
          ? order
          : AgencyOrder(
              id: order.id,
              number: order.number,
              customerId: order.customerId,
              productId: order.productId,
              quantity: order.quantity,
              unitPrice: product.price,
              deliveryCharge: order.deliveryCharge,
              discount: order.discount,
              status: order.status,
              createdAt: order.createdAt,
              notes: order.notes,
            ),
      (item) => item.id,
    );
  }

  void _validateOrderPrice(AgencyOrder order, double price) {
    if (!order.deliveryCharge.isFinite ||
        !order.discount.isFinite ||
        order.deliveryCharge < 0 ||
        order.discount < 0 ||
        order.discount > price * order.quantity + order.deliveryCharge) {
      throw StateError(
        'Enter valid charges and a discount within the booking total.',
      );
    }
  }

  @override
  Future<void> advanceBooking(String id, String status) async {
    final order = _orders.firstWhere((item) => item.id == id);
    if (!((order.status == 'Pending' && status == 'Confirmed') ||
        (order.status == 'Confirmed' && status == 'Ready for Delivery'))) {
      throw StateError('Booking status has changed. Refresh and try again.');
    }
    _replace(_orders, order.copyWith(status: status), (item) => item.id);
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    final order = _orders.firstWhere((item) => item.id == orderId);
    if (order.status != 'Cancelled') {
      await updateOrder(order.copyWith(status: 'Cancelled'));
    }
  }

  @override
  Future<void> updateDelivery(Delivery delivery) async {
    final old = _deliveries.firstWhere(
      (item) => item.orderId == delivery.orderId,
    );
    final order = _orders.firstWhere((item) => item.id == delivery.orderId);
    if (old.status == 'Delivered') {
      throw StateError('Delivery already completed.');
    }
    if (order.status == 'Cancelled' ||
        order.status == 'Delivered' && delivery.status != 'Delivered') {
      throw StateError('This order is not available for delivery.');
    }
    if (!const ['Pending', 'Assigned', 'Delivered'].contains(delivery.status)) {
      throw StateError('Select Pending, Assigned, or Delivered.');
    }
    if (delivery.status == 'Delivered' && old.status != 'Assigned') {
      throw StateError('Assign the delivery before marking it delivered.');
    }
    final staffId =
        delivery.staffId ??
        (delivery.status == 'Delivered' ? old.staffId : null);
    if (delivery.status != 'Pending' &&
        !_staff.any(
          (member) =>
              member.id == staffId && member.active && member.role == 'Staff',
        )) {
      throw StateError('Select an active delivery person.');
    }
    final deliveredQuantity = delivery.deliveredQuantity ?? order.quantity;
    final returnedEmpty = delivery.returnedEmpty ?? order.quantity;
    if (delivery.status == 'Delivered') {
      if (deliveredQuantity != order.quantity ||
          returnedEmpty < 0 ||
          delivery.damagedEmpty < 0 ||
          returnedEmpty + delivery.damagedEmpty > deliveredQuantity) {
        throw StateError('Record the booked quantity and a valid empty count.');
      }
      final item = _inventory.firstWhere(
        (entry) => entry.productId == order.productId,
      );
      if (item.filled < order.quantity || item.booked < order.quantity) {
        throw StateError('Inventory no longer has the booked quantity.');
      }
      final updated = Inventory(
        productId: item.productId,
        filled: item.filled - order.quantity,
        empty: item.empty + returnedEmpty,
        booked: item.booked - order.quantity,
        delivered: item.delivered + order.quantity,
        minimum: item.minimum,
        damaged: item.damaged + delivery.damagedEmpty,
      );
      _inventory[_inventory.indexOf(item)] = updated;
      _movements.insert(
        0,
        InventoryMovement(
          id: _uuid.v4(),
          productId: item.productId,
          kind: 'Delivery',
          filledChange: -order.quantity,
          emptyChange: returnedEmpty,
          damagedChange: delivery.damagedEmpty,
          bookedChange: -order.quantity,
          createdAt: DateTime.now(),
          note: order.number,
        ),
      );
      _replace(
        _orders,
        order.copyWith(status: 'Delivered'),
        (value) => value.id,
      );
    } else {
      final orderStatus = delivery.status == 'Assigned'
          ? 'Assigned'
          : 'Ready for Delivery';
      _replace(
        _orders,
        order.copyWith(status: orderStatus),
        (value) => value.id,
      );
    }
    final saved = Delivery(
      id: delivery.id,
      orderId: delivery.orderId,
      status: delivery.status,
      staffId: delivery.status == 'Pending' ? null : staffId,
      deliveredAt: delivery.status == 'Delivered' ? DateTime.now() : null,
      notes: delivery.notes,
      createdAt: old.createdAt ?? order.createdAt,
      updatedAt: DateTime.now(),
      damagedEmpty: delivery.status == 'Delivered' ? delivery.damagedEmpty : 0,
      deliveredQuantity: delivery.status == 'Delivered'
          ? deliveredQuantity
          : null,
      returnedEmpty: delivery.status == 'Delivered' ? returnedEmpty : null,
    );
    _replace(_deliveries, saved, (item) => item.orderId);
  }

  @override
  Future<void> recordEmptyReturns(
    String orderId,
    int serviceable,
    int damaged,
  ) async {
    final delivery = _deliveries.firstWhere((item) => item.orderId == orderId);
    final previousGood = delivery.returnedEmpty;
    final quantity = delivery.deliveredQuantity;
    if (delivery.status != 'Delivered' ||
        previousGood == null ||
        quantity == null ||
        serviceable < previousGood ||
        damaged < delivery.damagedEmpty ||
        serviceable + damaged > quantity) {
      throw StateError(
        'Enter valid return totals within the delivered quantity.',
      );
    }
    final extraGood = serviceable - previousGood;
    final extraDamaged = damaged - delivery.damagedEmpty;
    if (extraGood == 0 && extraDamaged == 0) return;

    final order = _orders.firstWhere((item) => item.id == orderId);
    final stock = _inventory.firstWhere(
      (item) => item.productId == order.productId,
    );
    _inventory[_inventory.indexOf(stock)] = Inventory(
      productId: stock.productId,
      filled: stock.filled,
      empty: stock.empty + extraGood,
      booked: stock.booked,
      delivered: stock.delivered,
      minimum: stock.minimum,
      damaged: stock.damaged + extraDamaged,
    );
    _replace(
      _deliveries,
      Delivery(
        id: delivery.id,
        orderId: orderId,
        status: delivery.status,
        staffId: delivery.staffId,
        deliveredAt: delivery.deliveredAt,
        createdAt: delivery.createdAt,
        updatedAt: DateTime.now(),
        notes: delivery.notes,
        deliveredQuantity: quantity,
        returnedEmpty: serviceable,
        damagedEmpty: damaged,
      ),
      (item) => item.orderId,
    );
    _movements.insert(
      0,
      InventoryMovement(
        id: _uuid.v4(),
        productId: order.productId,
        kind: 'Empty return',
        filledChange: 0,
        emptyChange: extraGood,
        damagedChange: extraDamaged,
        createdAt: DateTime.now(),
        note: order.number,
      ),
    );
  }

  @override
  Future<void> recordPayment(Payment payment) async {
    final order = _orders.firstWhere((item) => item.id == payment.orderId);
    if (payment.refundOf != null) {
      final original = _payments.firstWhere(
        (entry) => entry.id == payment.refundOf,
      );
      final refunded = _payments
          .where((entry) => entry.refundOf == original.id)
          .fold<double>(0, (total, entry) => total - entry.amount);
      if (original.orderId != order.id ||
          original.method != payment.method ||
          original.amount <= 0 ||
          payment.amount >= 0 ||
          -payment.amount > original.amount - refunded + 0.001 ||
          payment.notes.trim().isEmpty) {
        throw StateError(
          'Enter a refund within the refundable balance and provide a reason.',
        );
      }
      _payments.insert(0, payment);
      return;
    }
    if (order.status == 'Cancelled') {
      throw StateError('Order is unavailable for payment.');
    }
    if (!_settings.paymentMethods.contains(payment.method)) {
      throw StateError('This payment method is disabled in Settings.');
    }
    final paid = _payments
        .where((item) => item.orderId == payment.orderId)
        .fold<double>(0, (total, item) => total + item.amount);
    if (payment.amount <= 0 || payment.amount > order.total - paid + 0.001) {
      throw StateError(
        'Payment must be greater than zero and cannot exceed the remaining balance.',
      );
    }
    _payments.insert(0, payment);
  }

  @override
  Future<void> adjustInventory(
    String productId,
    int filledChange,
    int emptyChange,
    String note, {
    String kind = 'Adjustment',
    int damagedChange = 0,
  }) async {
    final valid = switch (kind) {
      'Adjustment' =>
        damagedChange == 0 && (filledChange != 0 || emptyChange != 0),
      'Distributor receipt' =>
        filledChange >= 0 &&
            emptyChange >= 0 &&
            (filledChange > 0 || emptyChange > 0) &&
            damagedChange == 0,
      'Exchange' =>
        filledChange < 0 && emptyChange == -filledChange && damagedChange == 0,
      'Damage' =>
        filledChange <= 0 &&
            emptyChange <= 0 &&
            damagedChange > 0 &&
            damagedChange == -filledChange - emptyChange,
      _ => false,
    };
    if (!valid || note.trim().isEmpty) {
      throw StateError('Invalid stock movement or missing reason.');
    }
    final item = _inventory.firstWhere((entry) => entry.productId == productId);
    if (item.filled + filledChange < item.booked ||
        item.empty + emptyChange < 0 ||
        item.damaged + damagedChange < 0) {
      throw StateError(
        'Adjustment would create negative or already-booked stock.',
      );
    }
    _inventory[_inventory.indexOf(item)] = Inventory(
      productId: item.productId,
      filled: item.filled + filledChange,
      empty: item.empty + emptyChange,
      booked: item.booked,
      delivered: item.delivered,
      minimum: item.minimum,
      damaged: item.damaged + damagedChange,
    );
    _movements.insert(
      0,
      InventoryMovement(
        id: _uuid.v4(),
        productId: productId,
        kind: kind,
        damagedChange: damagedChange,
        filledChange: filledChange,
        emptyChange: emptyChange,
        createdAt: DateTime.now(),
        note: note,
      ),
    );
  }

  @override
  Future<void> signIn(String email, String password) async {
    if (password != 'demo123' ||
        !_staff.any(
          (member) =>
              member.email.toLowerCase() == email.toLowerCase() &&
              member.active,
        )) {
      throw StateError(
        'Invalid email or password. Use the demo password demo123.',
      );
    }
  }

  @override
  Future<StaffMember?> restoreSession() async => null;

  @override
  Future<void> signOut() async {}

  void _replace<T>(List<T> list, T item, String Function(T) key) {
    final index = list.indexWhere((value) => key(value) == key(item));
    if (index == -1) {
      list.insert(0, item);
    } else {
      list[index] = item;
    }
  }
}
