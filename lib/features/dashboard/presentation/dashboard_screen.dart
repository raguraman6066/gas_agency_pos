import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models.dart';
import '../../../core/presentation/common_widgets.dart';
import '../../../core/providers.dart';
import '../../../core/utils/error_messages.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agencyControllerProvider);
    if (state.loading && state.customerList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.customerList.isEmpty) {
      return Center(
        child: Text(
          'Could not load agency data: ${userFriendlyError(state.error!)}',
        ),
      );
    }
    final now = DateTime.now();
    bool today(DateTime date) =>
        date.year == now.year && date.month == now.month && date.day == now.day;
    final todaysOrders = state.orderList
        .where((order) => today(order.createdAt))
        .toList();
    final orderById = {for (final order in state.orderList) order.id: order};
    final todaysDeliveries = state.deliveryList
        .where(
          (delivery) =>
              delivery.status == 'Delivered' &&
              delivery.deliveredAt != null &&
              today(delivery.deliveredAt!),
        )
        .toList();
    final deliveredToday = todaysDeliveries.length;
    final activeOrders = state.orderList
        .where((order) => order.status != 'Cancelled')
        .toList();
    final paidByOrder = <String, double>{};
    for (final payment in state.paymentList) {
      paidByOrder.update(
        payment.orderId,
        (value) => value + payment.amount,
        ifAbsent: () => payment.amount,
      );
    }
    final outstanding = activeOrders.fold<double>(
      0,
      (total, order) =>
          total +
          (order.total - (paidByOrder[order.id] ?? 0)).clamp(0, order.total),
    );
    final salesToday = todaysDeliveries.fold<double>(
      0,
      (total, delivery) => total + (orderById[delivery.orderId]?.total ?? 0),
    );
    final availableFilled = state.inventoryList.fold<int>(
      0,
      (total, item) => total + item.available,
    );
    final availableEmpty = state.inventoryList.fold<int>(
      0,
      (total, item) => total + item.empty,
    );
    final lowStock = state.inventoryList
        .where((item) => item.available <= item.minimum)
        .toList();
    final metrics = [
      _Metric(
        'Total customers',
        '${state.customerList.where((item) => item.active).length}',
        Icons.people_alt_outlined,
        const Color(0xFF1769D2),
        'Active accounts',
      ),
      _Metric(
        "Today's orders",
        '${todaysOrders.length}',
        Icons.receipt_long_outlined,
        const Color(0xFF8356D8),
        '$deliveredToday delivered',
      ),
      _Metric(
        'Pending orders',
        '${state.orderList.where((item) => item.status == 'Pending' || item.status == 'Confirmed').length}',
        Icons.pending_actions_outlined,
        const Color(0xFFE18A17),
        'Need attention',
      ),
      _Metric(
        "Today's sales",
        money(salesToday),
        Icons.trending_up_rounded,
        const Color(0xFF16845B),
        'Delivered today',
      ),
    ];
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width > 1250
        ? 4
        : width > 700
        ? 2
        : 2;
    return ListView(
      padding: EdgeInsets.all(width < 600 ? 14 : 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good day 👋',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C2A3A),
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Here is what is happening at your agency today.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF778397)),
                  ),
                ],
              ),
            ),
            if (width > 540)
              FilledButton.icon(
                onPressed: () => context.go('/orders'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New order'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 124,
          ),
          itemBuilder: (context, index) => _MetricCard(metric: metrics[index]),
        ),
        if (width <= 540) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.go('/orders'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create a new order'),
          ),
        ],
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _SalesChart(
                      orders: state.orderList,
                      deliveries: state.deliveryList,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 4,
                    child: _DeliverySummary(
                      orders: state.orderList,
                      pendingPayments: outstanding,
                      availableFilled: availableFilled,
                      availableEmpty: availableEmpty,
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _SalesChart(
                  orders: state.orderList,
                  deliveries: state.deliveryList,
                ),
                const SizedBox(height: 14),
                _DeliverySummary(
                  orders: state.orderList,
                  pendingPayments: outstanding,
                  availableFilled: availableFilled,
                  availableEmpty: availableEmpty,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final recent = state.orderList.take(6).toList();
            final card = SectionCard(
              title: 'Recent orders',
              trailing: TextButton(
                onPressed: () => context.go('/orders'),
                child: const Text('View all'),
              ),
              child: Column(
                children: [
                  for (final order in recent)
                    _RecentOrder(
                      order: order,
                      customer:
                          state.customerList
                              .where((c) => c.id == order.customerId)
                              .firstOrNull
                              ?.name ??
                          'Customer',
                    ),
                  if (recent.isEmpty)
                    const Text(
                      'No orders yet.',
                      style: TextStyle(color: Color(0xFF78869A), fontSize: 12),
                    ),
                ],
              ),
            );
            final payments = state.paymentList.take(5).toList();
            final payCard = SectionCard(
              title: 'Recent payments',
              trailing: TextButton(
                onPressed: () => context.go('/payments'),
                child: const Text('View all'),
              ),
              child: Column(
                children: [
                  for (final payment in payments)
                    _RecentPayment(
                      payment: payment,
                      order: state.orderList
                          .where((o) => o.id == payment.orderId)
                          .firstOrNull,
                    ),
                  if (payments.isEmpty)
                    const Text(
                      'No payments recorded.',
                      style: TextStyle(color: Color(0xFF78869A), fontSize: 12),
                    ),
                ],
              ),
            );
            if (constraints.maxWidth > 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: card),
                  const SizedBox(width: 14),
                  Expanded(flex: 4, child: payCard),
                ],
              );
            }
            return Column(
              children: [card, const SizedBox(height: 14), payCard],
            );
          },
        ),
        if (lowStock.isNotEmpty) ...[
          const SizedBox(height: 14),
          SectionCard(
            title: 'Low stock alerts',
            trailing: TextButton(
              onPressed: () => context.go('/inventory'),
              child: const Text('Manage stock'),
            ),
            child: Column(
              children: [
                for (final item in lowStock)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: Color(0xFFE18A17),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            state.productList
                                    .where((p) => p.id == item.productId)
                                    .firstOrNull
                                    ?.name ??
                                'Product',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${item.available} available',
                          style: const TextStyle(
                            color: Color(0xFFB36A00),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
      ],
    );
  }
}

class _Metric {
  const _Metric(this.title, this.value, this.icon, this.color, this.caption);
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String caption;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: metric.color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(metric.icon, size: 17, color: metric.color),
              ),
              Expanded(
                child: Text(
                  metric.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF8692A3)),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF203047),
                ),
              ),
              Text(
                metric.title,
                style: const TextStyle(fontSize: 10, color: Color(0xFF778397)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.orders, required this.deliveries});
  final List<AgencyOrder> orders;
  final List<Delivery> deliveries;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthly = List<double>.generate(6, (index) {
      final month = DateTime(now.year, now.month - 5 + index, 1);
      final deliveredIds = deliveries
          .where((delivery) {
            final date = delivery.deliveredAt;
            return delivery.status == 'Delivered' &&
                date != null &&
                date.year == month.year &&
                date.month == month.month;
          })
          .map((delivery) => delivery.orderId)
          .toSet();
      return orders
          .where((order) => deliveredIds.contains(order.id))
          .fold<double>(0, (sum, order) => sum + order.total);
    });
    final maxValue = monthly.fold<double>(1, (a, b) => a > b ? a : b);
    return SectionCard(
      title: 'Monthly sales',
      trailing: const Text(
        'Last 6 months',
        style: TextStyle(color: Color(0xFF7C899A), fontSize: 10),
      ),
      child: SizedBox(
        height: 190,
        child: Column(
          children: [
            Expanded(
              child: CustomPaint(
                painter: _BarChartPainter(values: monthly, maxValue: maxValue),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var index = 0; index < 6; index++)
                  Text(
                    _month(DateTime(now.year, now.month - 5 + index).month),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF8190A2),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({required this.values, required this.maxValue});
  final List<double> values;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFE9EEF4)
      ..strokeWidth = 1;
    for (var row = 0; row < 4; row++) {
      final y = size.height * row / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final paint = Paint()..color = const Color(0xFF2C7BE5);
    final width = size.width / (values.length * 2.2);
    for (var index = 0; index < values.length; index++) {
      final left = size.width * (index + .5) / values.length - width / 2;
      final height = (values[index] / maxValue) * (size.height - 8);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - height, width, height),
        const Radius.circular(5),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.maxValue != maxValue;
}

class _DeliverySummary extends StatelessWidget {
  const _DeliverySummary({
    required this.orders,
    required this.pendingPayments,
    required this.availableFilled,
    required this.availableEmpty,
  });
  final List<AgencyOrder> orders;
  final double pendingPayments;
  final int availableFilled;
  final int availableEmpty;

  @override
  Widget build(BuildContext context) {
    final delivered = orders
        .where((order) => order.status == 'Delivered')
        .length;
    final pending = orders
        .where(
          (order) => order.status == 'Pending' || order.status == 'Confirmed',
        )
        .length;
    final assigned = orders
        .where(
          (order) =>
              order.status == 'Assigned' || order.status == 'Out for Delivery',
        )
        .length;
    final active = orders.where((order) => order.status != 'Cancelled').length;
    return SectionCard(
      title: 'Operations snapshot',
      trailing: const Icon(Icons.more_horiz, color: Color(0xFF8995A6)),
      child: Column(
        children: [
          _SummaryLine(
            label: 'Delivered orders',
            value: '$delivered',
            color: const Color(0xFF16845B),
            percent: active == 0 ? 0 : delivered / active,
          ),
          const SizedBox(height: 14),
          _SummaryLine(
            label: 'Pending orders',
            value: '$pending',
            color: const Color(0xFFE18A17),
            percent: active == 0 ? 0 : pending / active,
          ),
          const SizedBox(height: 14),
          _SummaryLine(
            label: 'On the way',
            value: '$assigned',
            color: const Color(0xFF1769D2),
            percent: active == 0 ? 0 : assigned / active,
          ),
          const Divider(height: 25),
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  label: 'Outstanding',
                  value: money(pendingPayments),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryValue(
                  label: 'Filled / Empty',
                  value: '$availableFilled / $availableEmpty',
                  icon: Icons.propane_tank_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    required this.color,
    required this.percent,
  });
  final String label;
  final String value;
  final Color color;
  final double percent;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF68778B)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      const SizedBox(height: 7),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: percent,
          minHeight: 5,
          backgroundColor: const Color(0xFFF0F2F5),
          color: color,
        ),
      ),
    ],
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: const Color(0xFF738399)),
      const SizedBox(width: 7),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: Color(0xFF8290A2)),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ],
  );
}

class _RecentOrder extends StatelessWidget {
  const _RecentOrder({required this.order, required this.customer});
  final AgencyOrder order;
  final String customer;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: const Color(0xFFEFF4FC),
          child: const Icon(
            Icons.propane_tank_outlined,
            color: Color(0xFF3477CE),
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.number,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                customer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Color(0xFF8290A2)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(order.total),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            StatusBadge(order.status),
          ],
        ),
      ],
    ),
  );
}

class _RecentPayment extends StatelessWidget {
  const _RecentPayment({required this.payment, required this.order});
  final Payment payment;
  final AgencyOrder? order;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 17,
          backgroundColor: Color(0xFFE9F7F1),
          child: Icon(Icons.currency_rupee, size: 17, color: Color(0xFF16845B)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order?.number ?? 'Payment',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${payment.method} · ${shortDate(payment.date)}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF8290A2)),
              ),
            ],
          ),
        ),
        Text(
          money(payment.amount),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
