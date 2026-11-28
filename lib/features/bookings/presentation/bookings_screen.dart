part of '../../operations/presentation/operations_screen.dart';

class BookingsScreen extends OperationsScreen {
  const BookingsScreen({super.key}) : super(module: 'Orders');
}

extension _OrdersWorkflow on _OperationsScreenState {
  void _buildOrdersRows(
    AgencyState state,
    bool Function(String) matches,
    List<_RecordRow> rows,
  ) {
    for (final order in state.orderList) {
      if (_filter != 'All' && bookingStatusLabel(order.status) != _filter) {
        continue;
      }
      if (!_withinDateFilter(order.createdAt)) continue;
      final customerRecord = state.customerList
          .where((item) => item.id == order.customerId)
          .firstOrNull;
      final customer = customerRecord?.name ?? 'Unknown customer';
      final product = _productName(state, order.productId);
      final paid = state.paymentList
          .where((payment) => payment.orderId == order.id)
          .fold<double>(0, (total, payment) => total + payment.amount);
      final balance = (order.total - paid).clamp(0, order.total);
      final paymentStatus = paid <= 0
          ? 'Unpaid'
          : balance <= 0.001
          ? 'Paid'
          : 'Part-paid';
      if (!matches(
        '${order.number} $customer ${customerRecord?.phone ?? ''} ${customerRecord?.consumerNumber ?? ''} $product ${bookingStatusLabel(order.status)} $paymentStatus',
      )) {
        continue;
      }
      rows.add(
        _RecordRow(
          title: order.number,
          subtitle: '$customer · $product × ${order.quantity} · $paymentStatus',
          detail: '${shortDate(order.createdAt)} · ${money(order.total)}',
          status: order.status,
          action: () =>
              context.push('/orders/${Uri.encodeComponent(order.id)}'),
          menu: const [],
        ),
      );
    }
  }
}
