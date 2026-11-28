import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/domain/models.dart';
import '../../../core/presentation/common_widgets.dart';
import '../../../core/providers.dart';
import '../../../core/utils/error_messages.dart';

class PaymentEntryScreen extends ConsumerStatefulWidget {
  const PaymentEntryScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<PaymentEntryScreen> createState() => _PaymentEntryScreenState();
}

class _PaymentEntryScreenState extends ConsumerState<PaymentEntryScreen> {
  static const _uuid = Uuid();
  final _key = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  String? _method;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agencyControllerProvider);
    final order = state.orderList
        .where((item) => item.id == widget.orderId)
        .firstOrNull;
    if (state.loading) return const Center(child: CircularProgressIndicator());
    if (order == null || order.status == 'Cancelled') {
      return const Center(
        child: Text('This booking cannot receive a payment.'),
      );
    }
    final paid = state.paymentList
        .where((payment) => payment.orderId == order.id)
        .fold<double>(0, (total, payment) => total + payment.amount);
    final balance = (order.total - paid).clamp(0, order.total).toDouble();
    final methods = state.settings.paymentMethods;
    _method ??= methods.firstOrNull;
    _amount.text = _amount.text.isEmpty
        ? balance.toStringAsFixed(2)
        : _amount.text;

    if (balance <= 0.001) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This booking is fully paid.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  context.go('/orders/${Uri.encodeComponent(order.id)}'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to booking'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Form(
              key: _key,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        context.go('/orders/${Uri.encodeComponent(order.id)}'),
                    icon: const Icon(Icons.arrow_back),
                    label: Text('Back to ${order.number}'),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Collect payment · ${order.number}',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C2A3A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Booking balance',
                    child: Column(
                      children: [
                        _BalanceRow('Booking total', money(order.total)),
                        _BalanceRow('Already received', money(paid)),
                        _BalanceRow(
                          'Remaining balance',
                          money(balance),
                          strong: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Payment details',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount received (₹)',
                          ),
                          validator: (value) {
                            final entered = double.tryParse(value ?? '');
                            if (entered == null ||
                                entered <= 0 ||
                                entered > balance + .001) {
                              return 'Enter an amount up to ${money(balance)}.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _method,
                          decoration: const InputDecoration(
                            labelText: 'Payment method',
                          ),
                          items: methods
                              .map(
                                (method) => DropdownMenuItem(
                                  value: method,
                                  child: Text(method),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() => _method = value),
                          validator: (value) =>
                              value == null ? 'Select a payment method.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _reference,
                          decoration: const InputDecoration(
                            labelText: 'Reference (optional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notes,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _save(order),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Save payment'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save(AgencyOrder order) async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(agencyControllerProvider.notifier)
          .recordPayment(
            Payment(
              id: _uuid.v4(),
              orderId: order.id,
              amount: double.parse(_amount.text),
              method: _method!,
              date: DateTime.now(),
              reference: _reference.text.trim(),
              notes: _notes.text.trim(),
            ),
          );
      if (mounted) context.go('/orders/${Uri.encodeComponent(order.id)}');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFriendlyError(error);
        _saving = false;
      });
    }
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
