part of '../../operations/presentation/operations_screen.dart';

class PaymentsScreen extends OperationsScreen {
  const PaymentsScreen({super.key}) : super(module: 'Payments');
}

extension _PaymentsWorkflow on _OperationsScreenState {
  void _buildPaymentsRows(
    AgencyState state,
    bool Function(String) matches,
    List<_RecordRow> rows,
  ) {
    for (final payment in state.paymentList) {
      if (_filter != 'All' && payment.method != _filter) continue;
      if (!_withinDateFilter(payment.date)) continue;
      final order = state.orderList
          .where((item) => item.id == payment.orderId)
          .firstOrNull;
      final customer = order == null
          ? 'Customer'
          : _customerName(state, order.customerId);
      if (!matches(
        '${order?.number ?? ''} $customer ${payment.method} ${payment.reference}',
      )) {
        continue;
      }
      rows.add(
        _RecordRow(
          title: order?.number ?? 'Payment',
          subtitle:
              '$customer · ${payment.method}${payment.refundOf == null ? '' : ' · Refund'}',
          detail: '${shortDate(payment.date)} · ${money(payment.amount)}',
          action: () {
            if (order != null) {
              context.push('/orders/${Uri.encodeComponent(order.id)}');
            }
          },
          menu: const [],
        ),
      );
    }
  }

  Widget _paymentSummary(AgencyState state) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day + 1);
    final methods = <String, double>{};
    final paidByOrder = <String, double>{};
    for (final payment in state.paymentList) {
      paidByOrder.update(
        payment.orderId,
        (paid) => paid + payment.amount,
        ifAbsent: () => payment.amount,
      );
      if (!payment.date.isBefore(start) && payment.date.isBefore(end)) {
        methods.update(
          payment.method,
          (paid) => paid + payment.amount,
          ifAbsent: () => payment.amount,
        );
      }
    }
    final outstanding = state.orderList
        .where((order) => order.status != 'Cancelled')
        .fold<double>(
          0,
          (sum, order) =>
              sum +
              (order.total - (paidByOrder[order.id] ?? 0)).clamp(
                0,
                order.total,
              ),
        );
    final collected = methods.values.fold<double>(
      0,
      (sum, amount) => sum + amount,
    );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        Text('Net collected today ${money(collected)}'),
        Text('Outstanding ${money(outstanding)}'),
        for (final method in methods.entries)
          Text('${method.key} ${money(method.value)}'),
      ],
    );
  }

  Future<void> _paymentForm(AgencyState state) async {
    final outstandingOrders = state.orderList.where((order) {
      if (order.status == 'Cancelled') return false;
      final paid = state.paymentList
          .where((payment) => payment.orderId == order.id)
          .fold<double>(0, (sum, payment) => sum + payment.amount);
      return order.total - paid > .001;
    }).toList();
    if (outstandingOrders.isEmpty) {
      _message('There are no outstanding orders to collect payment for.');
      return;
    }
    var orderId = outstandingOrders.first.id;
    var method = state.settings.paymentMethods.first;
    final amount = TextEditingController();
    final reference = TextEditingController();
    final notes = TextEditingController();
    final key = GlobalKey<FormState>();
    void updateAmount() {
      final order = outstandingOrders.firstWhere((item) => item.id == orderId);
      final paid = state.paymentList
          .where((payment) => payment.orderId == orderId)
          .fold<double>(0, (sum, payment) => sum + payment.amount);
      amount.text = (order.total - paid).toStringAsFixed(2);
    }

    updateAmount();
    await _dialogForm(
      title: 'Record payment received',
      fields: (setDialogState) => Form(
        key: key,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: orderId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Order'),
                items: outstandingOrders
                    .map(
                      (order) => DropdownMenuItem(
                        value: order.id,
                        child: Text(
                          '${order.number} · ${_customerName(state, order.customerId)} · ${money(order.total)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setDialogState(() {
                    orderId = value ?? orderId;
                    updateAmount();
                  });
                },
              ),
            ),
            _field(
              amount,
              'Amount received (₹)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final entered = double.tryParse(value ?? '');
                final order = outstandingOrders.firstWhere(
                  (item) => item.id == orderId,
                );
                final paid = state.paymentList
                    .where((payment) => payment.orderId == orderId)
                    .fold<double>(0, (sum, payment) => sum + payment.amount);
                if (entered == null ||
                    entered <= 0 ||
                    !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value!.trim())) {
                  return 'Enter an amount greater than zero.';
                }
                if (entered > order.total - paid + .001) {
                  return 'Amount exceeds this order’s remaining balance.';
                }
                return null;
              },
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: state.settings.paymentMethods
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => method = value ?? method),
              ),
            ),
            _field(reference, 'Transaction reference (optional)'),
            _field(notes, 'Notes (optional)', maxLines: 2),
          ],
        ),
      ),
      validate: () => key.currentState!.validate(),
      save: () => ref
          .read(agencyControllerProvider.notifier)
          .recordPayment(
            Payment(
              id: _uuid.v4(),
              orderId: orderId,
              amount: double.parse(amount.text),
              method: method,
              date: DateTime.now(),
              reference: reference.text.trim(),
              notes: notes.text.trim(),
            ),
          ),
    );
    amount.dispose();
    reference.dispose();
    notes.dispose();
  }
}
