import '../domain/models.dart';

abstract interface class AgencyRepository {
  Future<AgencySnapshot> load();
  Future<void> saveSettings(AgencySettings settings);
  Future<void> saveCustomer(Customer customer);
  Future<void> saveProduct(Product product);
  Future<void> saveStaff(StaffMember member);
  Future<void> createOrder(AgencyOrder order);
  Future<void> updateOrder(AgencyOrder order);
  Future<void> advanceBooking(String id, String status);
  Future<void> deleteOrder(String orderId);
  Future<void> recordEmptyReturns(String orderId, int serviceable, int damaged);
  Future<void> updateDelivery(Delivery delivery);
  Future<void> recordPayment(Payment payment);
  Future<void> adjustInventory(
    String productId,
    int filledChange,
    int emptyChange,
    String note, {
    String kind = 'Adjustment',
    int damagedChange = 0,
  });
  Future<StaffMember?> restoreSession();
  Future<void> signIn(String email, String password);
  Future<void> signOut();
}
