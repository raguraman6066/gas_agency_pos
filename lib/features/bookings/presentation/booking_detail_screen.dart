import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models.dart';
import '../../../core/presentation/common_widgets.dart';
import '../../../core/providers.dart';
import '../../../core/utils/error_messages.dart';

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agencyControllerProvider);
    final order = state.orderList
        .where((item) => item.id == orderId)
        .firstOrNull;
    if (order == null) {
      if (state.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Booking not found.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.go('/orders'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to bookings'),
            ),
          ],
        ),
      );
    }

    final customer = state.customerList
        .where((item) => item.id == order.customerId)
        .firstOrNull;
    final product = state.productList
        .where((item) => item.id == order.productId)
        .firstOrNull;
    final delivery = state.deliveryList
        .where((item) => item.orderId == order.id)
        .firstOrNull;
    final payments =
        state.paymentList.where((item) => item.orderId == order.id).toList()
          ..sort((left, right) => right.date.compareTo(left.date));
    final paid = payments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final balance = (order.total - paid).clamp(0, order.total).toDouble();
    final paymentStatus = paid <= 0
        ? 'Unpaid'
        : balance <= 0.001
        ? 'Paid'
        : 'Part-paid';
    final deliveryStaff = state.staffList
        .where((item) => item.id == delivery?.staffId)
        .firstOrNull;
    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/orders'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to bookings'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      order.number,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C2A3A),
                      ),
                    ),
                    StatusBadge(order.status),
                    _PaymentStatusBadge(paymentStatus),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Booked ${shortDate(order.createdAt)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF68778B),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (order.status != 'Cancelled' &&
                        order.status != 'Delivered')
                      OutlinedButton.icon(
                        onPressed: () => context.go(
                          '/orders/${Uri.encodeComponent(order.id)}/edit',
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit booking'),
                      ),
                    if (order.status != 'Cancelled' &&
                        order.status != 'Delivered')
                      OutlinedButton.icon(
                        onPressed: () => context.push(
                          '/orders/${Uri.encodeComponent(order.id)}/cancel',
                        ),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel booking'),
                      ),
                    if (balance > 0.001 && order.status != 'Cancelled')
                      OutlinedButton.icon(
                        onPressed: () => context.go(
                          '/orders/${Uri.encodeComponent(order.id)}/payment',
                        ),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Collect payment'),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                SectionCard(
                  title: 'Customer',
                  child: Column(
                    children: [
                      _DetailRow('Name', customer?.name ?? 'Unknown customer'),
                      _DetailRow('Phone', customer?.phone ?? 'Not available'),
                      if (customer?.consumerNumber case final number?)
                        _DetailRow('Consumer number', number),
                      if (customer?.gasProvider case final provider?
                          when provider.isNotEmpty)
                        _DetailRow('Gas service', provider),
                      if (customer != null)
                        _DetailRow(
                          'Address',
                          '${customer.address}, ${customer.area}',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Booking amount',
                  child: Column(
                    children: [
                      _DetailRow(
                        'Product',
                        '${product?.name ?? 'Unknown product'} · ${product?.sizeKg ?? 0} kg',
                      ),
                      _DetailRow('Quantity', '${order.quantity}'),
                      _DetailRow(
                        'Unit price at booking',
                        money(order.unitPrice),
                      ),
                      _DetailRow(
                        'Delivery charge',
                        money(order.deliveryCharge),
                      ),
                      _DetailRow('Discount', '-${money(order.discount)}'),
                      const Divider(height: 22),
                      _DetailRow(
                        'Booking total',
                        money(order.total),
                        strong: true,
                      ),
                      _DetailRow(
                        'Payments received',
                        money(paid),
                        strong: true,
                      ),
                      _DetailRow('Balance due', money(balance), strong: true),
                      if (order.notes.isNotEmpty)
                        _DetailRow('Notes', order.notes),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Payment history',
                  child: payments.isEmpty
                      ? const Text('No payments recorded for this booking.')
                      : Column(
                          children: [
                            for (final payment in payments)
                              _PaymentRow(payment: payment),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Delivery',
                  child: delivery == null
                      ? const Text(
                          'No delivery record is linked to this booking.',
                        )
                      : Column(
                          children: [
                            _DetailRow(
                              'Status',
                              order.status == 'Cancelled'
                                  ? 'Cancelled'
                                  : deliveryStatusLabel(
                                      delivery.status,
                                      assigned: delivery.staffId != null,
                                    ),
                            ),
                            _DetailRow(
                              'Delivery person',
                              deliveryStaff?.name ?? 'Unassigned',
                            ),
                            if (delivery.deliveredAt != null)
                              _DetailRow(
                                'Delivered on',
                                shortDate(delivery.deliveredAt!),
                              ),
                            if (delivery.deliveredQuantity != null)
                              _DetailRow(
                                'Delivered quantity',
                                '${delivery.deliveredQuantity}',
                              ),
                            if (delivery.returnedEmpty != null)
                              _DetailRow(
                                'Serviceable empties received',
                                '${delivery.returnedEmpty}',
                              ),
                            if (delivery.pendingEmpty != null) ...[
                              _DetailRow(
                                'Damaged empties received',
                                '${delivery.damagedEmpty}',
                              ),
                              _DetailRow(
                                'Empties remaining',
                                '${delivery.pendingEmpty}',
                              ),
                            ],
                            if (delivery.status == 'Delivered' &&
                                delivery.pendingEmpty == null)
                              const _DetailRow(
                                'Empty returns',
                                'Counts unavailable',
                              ),
                            if (delivery.notes.isNotEmpty)
                              _DetailRow(
                                'Delivery notes / reason',
                                delivery.notes,
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class BookingCancelScreen extends ConsumerStatefulWidget {
  const BookingCancelScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<BookingCancelScreen> createState() =>
      _BookingCancelScreenState();
}

class _BookingCancelScreenState extends ConsumerState<BookingCancelScreen> {
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agencyControllerProvider);
    final order = state.orderList
        .where((item) => item.id == widget.orderId)
        .firstOrNull;
    if (state.loading) return const Center(child: CircularProgressIndicator());
    if (order == null) {
      return const Center(child: Text('Booking not found.'));
    }
    final netPaid = state.paymentList
        .where((payment) => payment.orderId == order.id)
        .fold<double>(0, (total, payment) => total + payment.amount);
    final cannotCancel =
        order.status == 'Delivered' ||
        order.status == 'Cancelled' ||
        netPaid > 0.001;

    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/orders/${Uri.encodeComponent(order.id)}'),
                  icon: const Icon(Icons.arrow_back),
                  label: Text('Back to ${order.number}'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cancel booking',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C2A3A),
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: order.number,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cancelling returns ${order.quantity} reserved full cylinders to available stock. This action cannot be undone.',
                      ),
                      const SizedBox(height: 12),
                      Text('Booking total: ${money(order.total)}'),
                      Text('Payments received: ${money(netPaid)}'),
                      if (netPaid > 0.001) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'This booking has a remaining payment. Refund or resolve the payment before cancelling.',
                          style: TextStyle(color: Color(0xFFB42318)),
                        ),
                      ],
                      if (order.status == 'Delivered') ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Delivered bookings cannot be cancelled.',
                          style: TextStyle(color: Color(0xFFB42318)),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFB42318)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Keep booking'),
                    ),
                    FilledButton.icon(
                      onPressed: _saving || cannotCancel
                          ? null
                          : _cancelBooking,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB42318),
                      ),
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cancel_outlined),
                      label: const Text('Confirm cancellation'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _cancelBooking() async {
    final order = ref
        .read(agencyControllerProvider)
        .orderList
        .where((item) => item.id == widget.orderId)
        .firstOrNull;
    if (order == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(agencyControllerProvider.notifier)
          .updateOrder(order.copyWith(status: 'Cancelled'));
      if (mounted) context.go('/orders');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFriendlyError(error);
        _saving = false;
      });
    }
  }
}

class _PaymentStatusBadge extends StatelessWidget {
  const _PaymentStatusBadge(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Paid' => const Color(0xFF16845B),
      'Part-paid' => const Color(0xFF1769D2),
      _ => const Color(0xFFB36A00),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 175,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF68778B),
              fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF26364A),
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final isRefund = payment.refundOf != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isRefund ? Icons.undo_rounded : Icons.payments_outlined,
            color: isRefund ? const Color(0xFFB42318) : const Color(0xFF1769D2),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isRefund ? 'Refund' : payment.method} · ${shortDate(payment.date)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (payment.reference.isNotEmpty || payment.notes.isNotEmpty)
                  Text(
                    [
                      payment.reference,
                      payment.notes,
                    ].where((value) => value.isNotEmpty).join(' · '),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF68778B),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${isRefund ? '-' : ''}${money(payment.amount.abs())}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isRefund
                  ? const Color(0xFFB42318)
                  : const Color(0xFF26364A),
            ),
          ),
        ],
      ),
    );
  }
}
