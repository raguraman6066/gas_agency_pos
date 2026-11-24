class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.consumerNumber,
    required this.phone,
    this.alternativePhone = '',
    required this.address,
    required this.area,
    required this.createdAt,
    this.active = true,
  });

  final String id;
  final String name;
  final String consumerNumber;
  final String phone;
  final String alternativePhone;
  final String address;
  final String area;
  final DateTime createdAt;
  final bool active;

  Customer copyWith({
    String? name,
    String? consumerNumber,
    String? phone,
    String? alternativePhone,
    String? address,
    String? area,
    bool? active,
  }) => Customer(
    id: id,
    name: name ?? this.name,
    consumerNumber: consumerNumber ?? this.consumerNumber,
    phone: phone ?? this.phone,
    alternativePhone: alternativePhone ?? this.alternativePhone,
    address: address ?? this.address,
    area: area ?? this.area,
    createdAt: createdAt,
    active: active ?? this.active,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'consumer_number': consumerNumber,
    'phone': phone,
    'alternative_phone': alternativePhone,
    'address': address,
    'area': area,
    'created_at': createdAt.toIso8601String(),
    'active': active,
  };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
    id: map['id'].toString(),
    name: map['name'] as String,
    consumerNumber: map['consumer_number'] as String,
    phone: map['phone'] as String,
    alternativePhone: map['alternative_phone'] as String? ?? '',
    address: map['address'] as String,
    area: map['area'] as String,
    createdAt: DateTime.parse(map['created_at'].toString()),
    active: map['active'] as bool? ?? true,
  );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.type,
    required this.sizeKg,
    required this.price,
    this.active = true,
  });

  final String id;
  final String name;
  final String type;
  final int sizeKg;
  final double price;
  final bool active;

  Product copyWith({
    String? name,
    String? type,
    int? sizeKg,
    double? price,
    bool? active,
  }) => Product(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    sizeKg: sizeKg ?? this.sizeKg,
    price: price ?? this.price,
    active: active ?? this.active,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type,
    'size_kg': sizeKg,
    'price': price,
    'active': active,
  };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
    id: map['id'].toString(),
    name: map['name'] as String,
    type: map['type'] as String,
    sizeKg: (map['size_kg'] as num).toInt(),
    price: (map['price'] as num).toDouble(),
    active: map['active'] as bool? ?? true,
  );
}

class AgencyOrder {
  const AgencyOrder({
    required this.id,
    required this.number,
    required this.customerId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.status,
    required this.createdAt,
    this.notes = '',
  });

  final String id;
  final String number;
  final String customerId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final String status;
  final DateTime createdAt;
  final String notes;
  double get total => quantity * unitPrice;

  AgencyOrder copyWith({String? status, String? notes}) => AgencyOrder(
    id: id,
    number: number,
    customerId: customerId,
    productId: productId,
    quantity: quantity,
    unitPrice: unitPrice,
    status: status ?? this.status,
    createdAt: createdAt,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'order_number': number,
    'customer_id': customerId,
    'product_id': productId,
    'quantity': quantity,
    'unit_price': unitPrice,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'notes': notes,
  };

  factory AgencyOrder.fromMap(Map<String, dynamic> map) => AgencyOrder(
    id: map['id'].toString(),
    number: map['order_number'] as String,
    customerId: map['customer_id'].toString(),
    productId: map['product_id'].toString(),
    quantity: (map['quantity'] as num).toInt(),
    unitPrice: (map['unit_price'] as num).toDouble(),
    status: map['status'] as String,
    createdAt: DateTime.parse(map['created_at'].toString()),
    notes: map['notes'] as String? ?? '',
  );
}

class Delivery {
  const Delivery({
    required this.id,
    required this.orderId,
    required this.status,
    this.staffId,
    this.deliveredAt,
    this.notes = '',
  });

  final String id;
  final String orderId;
  final String status;
  final String? staffId;
  final DateTime? deliveredAt;
  final String notes;

  Map<String, dynamic> toMap() => {
    'id': id,
    'order_id': orderId,
    'status': status,
    'staff_id': staffId,
    'delivered_at': deliveredAt?.toIso8601String(),
    'notes': notes,
  };

  factory Delivery.fromMap(Map<String, dynamic> map) => Delivery(
    id: map['id'].toString(),
    orderId: map['order_id'].toString(),
    status: map['status'] as String,
    staffId: map['staff_id']?.toString(),
    deliveredAt: map['delivered_at'] == null
        ? null
        : DateTime.parse(map['delivered_at'].toString()),
    notes: map['notes'] as String? ?? '',
  );
}

class Inventory {
  const Inventory({
    required this.productId,
    required this.filled,
    required this.empty,
    this.booked = 0,
    this.delivered = 0,
    this.minimum = 10,
  });

  final String productId;
  final int filled;
  final int empty;
  final int booked;
  final int delivered;
  final int minimum;
  int get available => filled - booked;

  Map<String, dynamic> toMap() => {
    'product_id': productId,
    'filled': filled,
    'empty': empty,
    'booked': booked,
    'delivered': delivered,
    'minimum': minimum,
  };

  factory Inventory.fromMap(Map<String, dynamic> map) => Inventory(
    productId: map['product_id'].toString(),
    filled: (map['filled'] as num).toInt(),
    empty: (map['empty'] as num).toInt(),
    booked: (map['booked'] as num?)?.toInt() ?? 0,
    delivered: (map['delivered'] as num?)?.toInt() ?? 0,
    minimum: (map['minimum'] as num?)?.toInt() ?? 10,
  );
}

class Payment {
  const Payment({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.method,
    required this.date,
    this.reference = '',
    this.notes = '',
  });

  final String id;
  final String orderId;
  final double amount;
  final String method;
  final DateTime date;
  final String reference;
  final String notes;

  Map<String, dynamic> toMap() => {
    'id': id,
    'order_id': orderId,
    'amount': amount,
    'method': method,
    'payment_date': date.toIso8601String(),
    'reference': reference,
    'notes': notes,
  };

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
    id: map['id'].toString(),
    orderId: map['order_id'].toString(),
    amount: (map['amount'] as num).toDouble(),
    method: map['method'] as String,
    date: DateTime.parse(map['payment_date'].toString()),
    reference: map['reference'] as String? ?? '',
    notes: map['notes'] as String? ?? '',
  );
}

class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.active = true,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool active;

  StaffMember copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
    bool? active,
  }) => StaffMember(
    id: id,
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    active: active ?? this.active,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'full_name': name,
    'email': email,
    'phone': phone,
    'role': role,
    'active': active,
  };

  factory StaffMember.fromMap(Map<String, dynamic> map) => StaffMember(
    id: map['id'].toString(),
    name: map['full_name'] as String,
    email: map['email'] as String,
    phone: map['phone'] as String? ?? '',
    role: map['role'] as String,
    active: map['active'] as bool? ?? true,
  );
}

class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.kind,
    required this.filledChange,
    required this.emptyChange,
    this.bookedChange = 0,
    required this.createdAt,
    this.note = '',
  });
  final String id;
  final String productId;
  final String kind;
  final int filledChange;
  final int emptyChange;
  final int bookedChange;
  final DateTime createdAt;
  final String note;
}

class AgencySnapshot {
  const AgencySnapshot({
    required this.customers,
    required this.products,
    required this.orders,
    required this.deliveries,
    required this.inventory,
    required this.payments,
    required this.staff,
    required this.movements,
  });
  final List<Customer> customers;
  final List<Product> products;
  final List<AgencyOrder> orders;
  final List<Delivery> deliveries;
  final List<Inventory> inventory;
  final List<Payment> payments;
  final List<StaffMember> staff;
  final List<InventoryMovement> movements;
}
