import '../domain/models.dart';

abstract interface class AgencyRepository {
  Future<AgencySnapshot> load();
  Future<void> saveCustomer(Customer customer);
  Future<void> saveProduct(Product product);
  Future<void> saveStaff(StaffMember member);
  Future<void> createOrder(AgencyOrder order);
  Future<void> updateOrder(AgencyOrder order);
  Future<void> deleteOrder(String orderId);
  Future<void> updateDelivery(Delivery delivery);
  Future<void> recordPayment(Payment payment);
  Future<void> adjustInventory(
    String productId,
    int filledChange,
    int emptyChange,
    String note,
  );
  Future<StaffMember?> restoreSession();
  Future<void> signIn(String email, String password);
  Future<void> signOut();
}
