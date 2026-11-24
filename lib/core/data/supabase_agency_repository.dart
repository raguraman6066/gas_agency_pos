import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';
import 'agency_repository.dart';

class SupabaseAgencyRepository implements AgencyRepository {
  SupabaseAgencyRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AgencySnapshot> load() async {
    final results = await Future.wait([
      _client.from('customers').select().order('created_at', ascending: false),
      _client.from('products').select().order('name'),
      _client
          .from('orders')
          .select('*, order_items(product_id, quantity, unit_price)')
          .order('created_at', ascending: false),
      _client.from('deliveries').select(),
      _client.from('inventory').select(),
      _client.from('payments').select().order('payment_date', ascending: false),
      _client.from('profiles').select().order('full_name'),
      _client
          .from('inventory_movements')
          .select()
          .order('created_at', ascending: false),
    ]);
    final orders = (results[2] as List).map((row) {
      final order = Map<String, dynamic>.from(row as Map);
      final item = _firstOrderItem(order.remove('order_items'));
      if (item != null) {
        order['product_id'] = item['product_id'];
        order['quantity'] = item['quantity'];
        order['unit_price'] = item['unit_price'];
      }
      return AgencyOrder.fromMap(order);
    }).toList();
    return AgencySnapshot(
      customers: (results[0] as List)
          .map((row) => Customer.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList(),
      products: (results[1] as List)
          .map((row) => Product.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList(),
      orders: orders,
      deliveries: (results[3] as List)
          .map((row) => Delivery.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList(),
      inventory: (results[4] as List)
          .map(
            (row) => Inventory.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
      payments: (results[5] as List)
          .map((row) => Payment.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList(),
      staff: (results[6] as List)
          .map(
            (row) => StaffMember.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
      movements: (results[7] as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        return InventoryMovement(
          id: map['id'].toString(),
          productId: map['product_id'].toString(),
          kind: map['kind'] as String,
          filledChange: (map['filled_change'] as num).toInt(),
          emptyChange: (map['empty_change'] as num).toInt(),
          bookedChange: (map['booked_change'] as num?)?.toInt() ?? 0,
          createdAt: DateTime.parse(map['created_at'].toString()),
          note: map['note'] as String? ?? '',
        );
      }).toList(),
    );
  }

  @override
  Future<void> saveCustomer(Customer customer) async {
    await _client.from('customers').upsert(customer.toMap());
  }

  @override
  Future<void> saveProduct(Product product) async {
    await _client.from('products').upsert(product.toMap());
  }

  @override
  Future<void> saveStaff(StaffMember member) async {
    await _client.from('profiles').upsert(member.toMap());
  }

  @override
  Future<void> createOrder(AgencyOrder order) async {
    await _client.rpc(
      'create_order',
      params: {
        'p_customer_id': order.customerId,
        'p_product_id': order.productId,
        'p_quantity': order.quantity,
        'p_notes': order.notes,
      },
    );
  }

  @override
  Future<void> updateOrder(AgencyOrder order) async {
    if (order.status == 'Cancelled') {
      await _client.rpc('cancel_order', params: {'p_order_id': order.id});
      return;
    }
    await _client.rpc(
      'edit_order',
      params: {
        'p_order_id': order.id,
        'p_customer_id': order.customerId,
        'p_product_id': order.productId,
        'p_quantity': order.quantity,
        'p_notes': order.notes,
      },
    );
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    await _client.rpc('cancel_order', params: {'p_order_id': orderId});
  }

  @override
  Future<void> updateDelivery(Delivery delivery) async {
    if (delivery.status == 'Delivered') {
      await _client.rpc(
        'complete_delivery',
        params: {
          'p_order_id': delivery.orderId,
          'p_staff_id': delivery.staffId,
          'p_notes': delivery.notes,
        },
      );
      return;
    }
    await _client.rpc(
      'update_delivery_status',
      params: {
        'p_order_id': delivery.orderId,
        'p_status': delivery.status,
        'p_staff_id': delivery.staffId,
        'p_notes': delivery.notes,
      },
    );
  }

  @override
  Future<void> recordPayment(Payment payment) async {
    await _client.rpc(
      'record_payment',
      params: {
        'p_order_id': payment.orderId,
        'p_amount': payment.amount,
        'p_method': payment.method,
        'p_payment_date': payment.date.toIso8601String(),
        'p_reference': payment.reference,
        'p_notes': payment.notes,
      },
    );
  }

  @override
  Future<void> adjustInventory(
    String productId,
    int filledChange,
    int emptyChange,
    String note,
  ) async {
    await _client.rpc(
      'adjust_inventory',
      params: {
        'p_product_id': productId,
        'p_filled_change': filledChange,
        'p_empty_change': emptyChange,
        'p_note': note,
      },
    );
  }

  @override
  Future<void> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw StateError('Supabase did not return a signed-in user.');
    }
    final profile = await _profileForUser(user.id, user.email ?? email);
    if (profile == null || profile['active'] != true) {
      await _client.auth.signOut();
      throw StateError(
        'Your password was accepted, but this account is not linked to an '
        'active agency staff profile. Ask an administrator to run the demo '
        'setup SQL for this exact Auth email, then sign in again.',
      );
    }
  }

  @override
  Future<StaffMember?> restoreSession() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final profile = await _profileForUser(user.id, user.email ?? '');
    if (profile == null || profile['active'] != true) {
      await _client.auth.signOut();
      return null;
    }
    return StaffMember.fromMap(Map<String, dynamic>.from(profile));
  }

  Future<Map<String, dynamic>?> _profileForUser(
    String authUserId,
    String email,
  ) async {
    final byAuthId = await _client
        .from('profiles')
        .select()
        .eq('auth_user_id', authUserId)
        .maybeSingle();
    if (byAuthId != null) return Map<String, dynamic>.from(byAuthId);
    if (email.isEmpty) return null;
    final byEmail = await _client
        .from('profiles')
        .select()
        .ilike('email', email)
        .maybeSingle();
    return byEmail == null ? null : Map<String, dynamic>.from(byEmail);
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

Map<String, dynamic>? _firstOrderItem(Object? relation) {
  if (relation is Map) return Map<String, dynamic>.from(relation);
  if (relation is List && relation.isNotEmpty) {
    final item = relation.first;
    if (item is Map) return Map<String, dynamic>.from(item);
    throw const FormatException('Order item response was not an object.');
  }
  if (relation == null || relation is List) return null;
  throw const FormatException('Order item response had an unexpected format.');
}
