import 'package:flutter/material.dart';

String money(num value) =>
    '₹${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';

String shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String bookingStatusLabel(String status) => switch (status) {
  'Ready for Delivery' || 'Confirmed' => 'Pending',
  'Out for Delivery' => 'Assigned',
  _ => status,
};

String deliveryStatusLabel(String status, {required bool assigned}) {
  if (status == 'Delivered') return 'Delivered';
  return assigned && (status == 'Assigned' || status == 'Out for Delivery')
      ? 'Assigned'
      : 'Pending';
}

Color statusColor(String status) => switch (status) {
  'Delivered' || 'Paid' => const Color(0xFF16845B),
  'Out for Delivery' || 'Assigned' || 'Confirmed' => const Color(0xFF1769D2),
  'Pending' || 'Unassigned' || 'Failed' => const Color(0xFFB36A00),
  'Cancelled' => const Color(0xFFB42318),
  _ => const Color(0xFF64748B),
};

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final label = bookingStatusLabel(status);
    final color = statusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF26364A),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    ),
  );
}
