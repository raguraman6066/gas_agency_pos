import 'dart:math';

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
  int _nextOrder = 1041;

  @override
  Future<AgencySnapshot> load() async => AgencySnapshot(
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
      Product(
        id: 'p3',
        name: 'Small LPG',
        type: 'Domestic',
        sizeKg: 5,
        price: 420,
      ),
      Product(
        id: 'p4',
        name: 'Commercial LPG XL',
        type: 'Commercial',
        sizeKg: 47,
        price: 3920,
      ),
      Product(
        id: 'p5',
        name: 'Domestic LPG 14.2 kg',
        type: 'Domestic',
        sizeKg: 14,
        price: 1010,
      ),
    ];
    const firstNames = [
      'Aarav',
      'Ananya',
      'Vijay',
      'Priya',
      'Rahul',
      'Meera',
      'Arjun',
      'Kavya',
      'Rohan',
      'Divya',
    ];
    const lastNames = [
      'Sharma',
      'Patel',
      'Kumar',
      'Reddy',
      'Nair',
      'Singh',
      'Joshi',
      'Iyer',
      'Das',
      'Gupta',
    ];
    const areas = [
      'Central',
      'North Park',
      'Lake View',
      'Market Road',
      'Green Valley',
      'Old Town',
    ];
    _customers = List.generate(30, (i) {
      final name =
          '${firstNames[i % firstNames.length]} ${lastNames[(i * 3) % lastNames.length]}';
      return Customer(
        id: 'c${i + 1}',
        name: name,
        consumerNumber: 'CN-${24001 + i}',
        phone: '98${(10000000 + i * 17391).toString().substring(0, 8)}',
        alternativePhone: i % 3 == 0
            ? '97${(10000000 + i * 10111).toString().substring(0, 8)}'
            : '',
        address: '${12 + i} ${areas[i % areas.length]} Main Road',
        area: areas[i % areas.length],
        createdAt: now.subtract(Duration(days: 60 + i)),
      );
    });
    _staff = const [
      StaffMember(
        id: 's1',
        name: 'Anil Kumar',
        email: 'admin@gasagency.demo',
        phone: '9876500001',
        role: 'Admin',
      ),
      StaffMember(
        id: 's2',
        name: 'Suresh Rao',
        email: 'staff@gasagency.demo',
        phone: '9876500002',
        role: 'Staff',
      ),
      StaffMember(
        id: 's3',
        name: 'Kiran Das',
        email: 'kiran@gasagency.demo',
        phone: '9876500003',
        role: 'Staff',
      ),
    ];
    _inventory = [
      const Inventory(
        productId: 'p1',
        filled: 58,
        empty: 21,
        booked: 5,
        minimum: 12,
      ),
      const Inventory(
        productId: 'p2',
        filled: 24,
        empty: 9,
        booked: 3,
        minimum: 8,
      ),
      const Inventory(
        productId: 'p3',
        filled: 36,
        empty: 14,
        booked: 4,
        minimum: 10,
      ),
      const Inventory(
        productId: 'p4',
        filled: 8,
        empty: 5,
        booked: 1,
        minimum: 5,
      ),
      const Inventory(
        productId: 'p5',
        filled: 42,
        empty: 18,
        booked: 4,
        minimum: 12,
      ),
    ];
    final random = Random(31);
    _orders = List.generate(40, (i) {
      final product = _products[i % _products.length];
      final status = i < 8
          ? 'Pending'
          : i < 12
          ? 'Confirmed'
          : i < 16
          ? 'Assigned'
          : i < 20
          ? 'Out for Delivery'
          : i < 34
          ? 'Delivered'
          : 'Cancelled';
      return AgencyOrder(
        id: 'o${i + 1}',
        number: 'GA-${(1001 + i).toString()}',
        customerId: _customers[(i * 7) % _customers.length].id,
        productId: product.id,
        quantity: 1 + random.nextInt(2),
        unitPrice: product.price,
        status: status,
        createdAt: now.subtract(
          Duration(
            days: i == 20
                ? 0
                : i < 7
                ? i
                : (i * 4) % 170,
            hours: i % 11,
          ),
        ),
        notes: i % 6 == 0 ? 'Please call before delivery' : '',
      );
    });
    _inventory = _inventory.map((item) {
      final booked = _orders
          .where(
            (order) =>
                order.productId == item.productId &&
                order.status != 'Cancelled' &&
                order.status != 'Delivered',
          )
          .fold<int>(0, (total, order) => total + order.quantity);
      return Inventory(
        productId: item.productId,
        filled: item.filled < booked + 5 ? booked + 5 : item.filled,
        empty: item.empty,
        booked: booked,
        delivered: item.delivered,
        minimum: item.minimum,
      );
    }).toList();
    _nextOrder = 1041;
    _deliveries = _orders.where((o) => o.status != 'Cancelled').map((o) {
      final status = switch (o.status) {
        'Delivered' => 'Delivered',
        'Assigned' => 'Assigned',
        'Out for Delivery' => 'Out for Delivery',
        _ => 'Pending',
      };
      return Delivery(
        id: 'd${o.id.substring(1)}',
        orderId: o.id,
        status: status,
        staffId: status == 'Pending'
            ? null
            : _staff[1 + (int.parse(o.id.substring(1)) % 2)].id,
        deliveredAt: status == 'Delivered'
            ? o.createdAt.add(const Duration(hours: 3))
            : null,
        notes: '',
      );
    }).toList();
    _payments = [];
    for (final order in _orders.where((o) => o.status == 'Delivered')) {
      final ratio = 1 + (int.parse(order.id.substring(1)) % 3);
      if (ratio == 1) {
        _payments.add(
          Payment(
            id: 'pay-${order.id}',
            orderId: order.id,
            amount: order.total,
            method: 'UPI',
            date: order.createdAt.add(const Duration(hours: 4)),
          ),
        );
      } else {
        _payments.add(
          Payment(
            id: 'pay-${order.id}',
            orderId: order.id,
            amount: order.total / 2,
            method: 'Cash',
            date: order.createdAt.add(const Duration(hours: 4)),
          ),
        );
      }
    }
    _movements = _inventory
        .map(
          (item) => InventoryMovement(
            id: _uuid.v4(),
            productId: item.productId,
            kind: 'Opening stock',
            filledChange: item.filled,
            emptyChange: item.empty,
            bookedChange: item.booked,
            createdAt: now.subtract(const Duration(days: 30)),
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
    final number = 'GA-${_nextOrder++}';
    final saved = AgencyOrder(
      id: _uuid.v4(),
      number: number,
      customerId: order.customerId,
      productId: order.productId,
      quantity: order.quantity,
      unitPrice: product.price,
      status: 'Pending',
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
      Delivery(id: _uuid.v4(), orderId: saved.id, status: 'Pending'),
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
        _payments.any((payment) => payment.orderId == order.id)) {
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
            status: 'Failed',
            staffId: delivery.staffId,
            notes: 'Order cancelled',
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
      );
      _inventory[_inventory.indexOf(newInventory)] = Inventory(
        productId: newInventory.productId,
        filled: newInventory.filled,
        empty: newInventory.empty,
        booked: newInventory.booked + order.quantity,
        delivered: newInventory.delivered,
        minimum: newInventory.minimum,
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
              status: order.status,
              createdAt: order.createdAt,
              notes: order.notes,
            ),
      (item) => item.id,
    );
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
    if (old.status != 'Delivered' && delivery.status == 'Delivered') {
      final item = _inventory.firstWhere(
        (entry) => entry.productId == order.productId,
      );
      if (item.filled < order.quantity || item.booked < order.quantity) {
        throw StateError('Inventory no longer has the booked quantity.');
      }
      final updated = Inventory(
        productId: item.productId,
        filled: item.filled - order.quantity,
        empty: item.empty + order.quantity,
        booked: item.booked - order.quantity,
        delivered: item.delivered + order.quantity,
        minimum: item.minimum,
      );
      _inventory[_inventory.indexOf(item)] = updated;
      _movements.insert(
        0,
        InventoryMovement(
          id: _uuid.v4(),
          productId: item.productId,
          kind: 'Delivery',
          filledChange: -order.quantity,
          emptyChange: order.quantity,
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
      final orderStatus = switch (delivery.status) {
        'Assigned' => 'Assigned',
        'Out for Delivery' => 'Out for Delivery',
        'Failed' => 'Confirmed',
        _ => 'Pending',
      };
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
      staffId: delivery.staffId,
      deliveredAt: delivery.status == 'Delivered' ? DateTime.now() : null,
      notes: delivery.notes,
    );
    _replace(_deliveries, saved, (item) => item.orderId);
  }

  @override
  Future<void> recordPayment(Payment payment) async {
    final order = _orders.firstWhere((item) => item.id == payment.orderId);
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
    String note,
  ) async {
    final item = _inventory.firstWhere((entry) => entry.productId == productId);
    if (item.filled + filledChange < item.booked ||
        item.empty + emptyChange < 0) {
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
    );
    _movements.insert(
      0,
      InventoryMovement(
        id: _uuid.v4(),
        productId: productId,
        kind: 'Adjustment',
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
