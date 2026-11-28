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
    this.gstNumber = '',
    this.identityDocumentType = '',
    this.identityDocumentNumber = '',
    this.gasProvider = '',
    this.active = true,
    this.type,
  });

  final String id;
  final String name;
  final String? type;
  final String consumerNumber;
  final String phone;
  final String alternativePhone;
  final String address;
  final String area;
  final String gstNumber;
  final String identityDocumentType;
  final String identityDocumentNumber;
  final String gasProvider;
  final DateTime createdAt;
  final bool active;

  Customer copyWith({
    String? name,
    String? consumerNumber,
    String? phone,
    String? alternativePhone,
    String? address,
    String? area,
    String? gstNumber,
    String? identityDocumentType,
    String? identityDocumentNumber,
    String? gasProvider,
    bool? active,
  }) => Customer(
    id: id,
    name: name ?? this.name,
    type: type,
    consumerNumber: consumerNumber ?? this.consumerNumber,
    phone: phone ?? this.phone,
    alternativePhone: alternativePhone ?? this.alternativePhone,
    address: address ?? this.address,
    area: area ?? this.area,
    gstNumber: gstNumber ?? this.gstNumber,
    identityDocumentType: identityDocumentType ?? this.identityDocumentType,
    identityDocumentNumber:
        identityDocumentNumber ?? this.identityDocumentNumber,
    gasProvider: gasProvider ?? this.gasProvider,
    createdAt: createdAt,
    active: active ?? this.active,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'consumer_number': consumerNumber,
    'customer_type': type,
    'phone': phone,
    'alternative_phone': alternativePhone,
    'address': address,
    'area': area,
    'gst_number': gstNumber,
    'identity_document_type': identityDocumentType,
    'identity_document_number': identityDocumentNumber,
    'gas_provider': gasProvider,
    'created_at': createdAt.toIso8601String(),
    'active': active,
  };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
    id: map['id'].toString(),
    name: map['name'] as String,
    consumerNumber: map['consumer_number'] as String,
    type: map['customer_type'] as String?,
    phone: map['phone'] as String,
    alternativePhone: map['alternative_phone'] as String? ?? '',
    address: map['address'] as String,
    area: map['area'] as String,
    gstNumber: map['gst_number'] as String? ?? '',
    identityDocumentType: map['identity_document_type'] as String? ?? '',
    identityDocumentNumber: map['identity_document_number'] as String? ?? '',
    gasProvider: map['gas_provider'] as String? ?? '',
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
    this.deliveryCharge = 0,
    this.discount = 0,
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
  final double deliveryCharge;
  final double discount;
  double get total => quantity * unitPrice + deliveryCharge - discount;

  AgencyOrder copyWith({String? status, String? notes}) => AgencyOrder(
    id: id,
    number: number,
    customerId: customerId,
    productId: productId,
    quantity: quantity,
    unitPrice: unitPrice,
    deliveryCharge: deliveryCharge,
    discount: discount,
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
    'delivery_charge': deliveryCharge,
    'discount': discount,
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
    deliveryCharge: (map['delivery_charge'] as num?)?.toDouble() ?? 0,
    discount: (map['discount'] as num?)?.toDouble() ?? 0,
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
    this.deliveredQuantity,
    this.returnedEmpty,
    this.damagedEmpty = 0,
    this.createdAt,
    this.updatedAt,
    this.notes = '',
  });

  final String id;
  final String orderId;
  final String status;
  final String? staffId;
  final DateTime? deliveredAt;
  final int? deliveredQuantity;
  final int? returnedEmpty;
  final int damagedEmpty;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int? get pendingEmpty => deliveredQuantity == null || returnedEmpty == null
      ? null
      : deliveredQuantity! - returnedEmpty! - damagedEmpty;
  final String notes;

  Map<String, dynamic> toMap() => {
    'id': id,
    'order_id': orderId,
    'status': status,
    'staff_id': staffId,
    'delivered_at': deliveredAt?.toIso8601String(),
    'delivered_quantity': deliveredQuantity,
    'returned_empty': returnedEmpty,
    'damaged_empty': damagedEmpty,
    'notes': notes,
  };

  factory Delivery.fromMap(Map<String, dynamic> map) => Delivery(
    id: map['id'].toString(),
    orderId: map['order_id'].toString(),
    status: map['status'] as String,
    staffId: map['staff_id']?.toString(),
    deliveredQuantity: (map['delivered_quantity'] as num?)?.toInt(),
    returnedEmpty: (map['returned_empty'] as num?)?.toInt(),
    damagedEmpty: (map['damaged_empty'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.tryParse(map['created_at'].toString()),
    updatedAt: DateTime.tryParse(map['updated_at'].toString()),
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
    this.damaged = 0,
  });

  final String productId;
  final int filled;
  final int empty;
  final int booked;
  final int delivered;
  final int minimum;
  final int damaged;
  int get available => filled - booked;

  Map<String, dynamic> toMap() => {
    'product_id': productId,
    'filled': filled,
    'empty': empty,
    'booked': booked,
    'delivered': delivered,
    'minimum': minimum,
    'damaged': damaged,
  };

  factory Inventory.fromMap(Map<String, dynamic> map) => Inventory(
    productId: map['product_id'].toString(),
    filled: (map['filled'] as num).toInt(),
    empty: (map['empty'] as num).toInt(),
    booked: (map['booked'] as num?)?.toInt() ?? 0,
    delivered: (map['delivered'] as num?)?.toInt() ?? 0,
    minimum: (map['minimum'] as num?)?.toInt() ?? 10,
    damaged: (map['damaged'] as num?)?.toInt() ?? 0,
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
    this.refundOf,
    this.notes = '',
  });

  final String id;
  final String orderId;
  final double amount;
  final String method;
  final DateTime date;
  final String reference;
  final String? refundOf;
  final String notes;

  Map<String, dynamic> toMap() => {
    'id': id,
    'order_id': orderId,
    'amount': amount,
    'method': method,
    'payment_date': date.toIso8601String(),
    'reference': reference,
    'refund_of': refundOf,
    'notes': notes,
  };

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
    id: map['id'].toString(),
    orderId: map['order_id'].toString(),
    amount: (map['amount'] as num).toDouble(),
    method: map['method'] as String,
    date: DateTime.parse(map['payment_date'].toString()),
    refundOf: map['refund_of']?.toString(),
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
    this.damagedChange = 0,
    required this.createdAt,
    this.note = '',
  });
  final String id;
  final String productId;
  final String kind;
  final int filledChange;
  final int emptyChange;
  final int bookedChange;
  final int damagedChange;
  final DateTime createdAt;
  final String note;
}

class AgencySettings {
  const AgencySettings({
    this.name = 'Kathiravan Gas Agency',
    this.details = '',
    this.deliveryCharge = 0,
    this.paymentMethods = supportedPaymentMethods,
  });

  static const supportedPaymentMethods = [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Other',
  ];

  final String name;
  final String details;
  final double deliveryCharge;
  final List<String> paymentMethods;
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
    this.settings = const AgencySettings(),
  });
  final List<Customer> customers;
  final List<Product> products;
  final List<AgencyOrder> orders;
  final List<Delivery> deliveries;
  final List<Inventory> inventory;
  final List<Payment> payments;
  final List<StaffMember> staff;
  final List<InventoryMovement> movements;
  final AgencySettings settings;
}
