import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/agency_repository.dart';
import 'domain/models.dart';

final agencyRepositoryProvider = Provider<AgencyRepository>((ref) {
  throw StateError('Agency repository has not been configured.');
});

final agencyControllerProvider =
    NotifierProvider<AgencyController, AgencyState>(AgencyController.new);

class AgencyState {
  const AgencyState({
    this.loading = true,
    this.error,
    this.customerList = const [],
    this.productList = const [],
    this.orderList = const [],
    this.deliveryList = const [],
    this.inventoryList = const [],
    this.paymentList = const [],
    this.staffList = const [],
    this.movementList = const [],
    this.currentEmail,
    this.currentName,
    this.currentRole,
  });

  final bool loading;
  final String? error;
  final List<Customer> customerList;
  final List<Product> productList;
  final List<AgencyOrder> orderList;
  final List<Delivery> deliveryList;
  final List<Inventory> inventoryList;
  final List<Payment> paymentList;
  final List<StaffMember> staffList;
  final List<InventoryMovement> movementList;
  final String? currentEmail;
  final String? currentName;
  final String? currentRole;
  bool get signedIn => currentEmail != null;

  AgencyState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    AgencySnapshot? snapshot,
    String? currentEmail,
    String? currentName,
    String? currentRole,
    bool clearUser = false,
  }) => AgencyState(
    loading: loading ?? this.loading,
    error: clearError ? null : error ?? this.error,
    customerList: snapshot?.customers ?? customerList,
    productList: snapshot?.products ?? productList,
    orderList: snapshot?.orders ?? orderList,
    deliveryList: snapshot?.deliveries ?? deliveryList,
    inventoryList: snapshot?.inventory ?? inventoryList,
    paymentList: snapshot?.payments ?? paymentList,
    staffList: snapshot?.staff ?? staffList,
    movementList: snapshot?.movements ?? movementList,
    currentEmail: clearUser ? null : currentEmail ?? this.currentEmail,
    currentName: clearUser ? null : currentName ?? this.currentName,
    currentRole: clearUser ? null : currentRole ?? this.currentRole,
  );
}

class AgencyController extends Notifier<AgencyState> {
  AgencyRepository get _repository => ref.read(agencyRepositoryProvider);

  @override
  AgencyState build() {
    Future.microtask(_initialize);
    return const AgencyState();
  }

  Future<void> _initialize() async {
    try {
      final snapshot = await _repository.load();
      final member = await _repository.restoreSession();
      state = state.copyWith(
        loading: false,
        snapshot: snapshot,
        currentEmail: member?.email,
        currentName: member?.name,
        currentRole: member?.role,
        clearUser: member == null,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      state = state.copyWith(
        loading: false,
        snapshot: await _repository.load(),
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> signIn(String email, String password) async {
    await _repository.signIn(email, password);
    final snapshot = await _repository.load();
    final member = snapshot.staff
        .where((staff) => staff.email.toLowerCase() == email.toLowerCase())
        .firstOrNull;
    state = state.copyWith(
      snapshot: snapshot,
      currentEmail: email,
      currentName: member?.name ?? email.split('@').first,
      currentRole: member?.role ?? 'Staff',
    );
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = state.copyWith(clearUser: true);
  }

  Future<void> saveCustomer(Customer value) =>
      _save(() => _repository.saveCustomer(value));
  Future<void> saveProduct(Product value) =>
      _save(() => _repository.saveProduct(value));
  Future<void> saveStaff(StaffMember value) =>
      _save(() => _repository.saveStaff(value));
  Future<void> createOrder(AgencyOrder value) =>
      _save(() => _repository.createOrder(value));
  Future<void> updateOrder(AgencyOrder value) =>
      _save(() => _repository.updateOrder(value));
  Future<void> deleteOrder(String id) =>
      _save(() => _repository.deleteOrder(id));
  Future<void> updateDelivery(Delivery value) =>
      _save(() => _repository.updateDelivery(value));
  Future<void> recordPayment(Payment value) =>
      _save(() => _repository.recordPayment(value));
  Future<void> adjustInventory(String id, int filled, int empty, String note) =>
      _save(() => _repository.adjustInventory(id, filled, empty, note));

  Future<void> _save(Future<void> Function() action) async {
    await action();
    state = state.copyWith(
      snapshot: await _repository.load(),
      clearError: true,
    );
  }
}
