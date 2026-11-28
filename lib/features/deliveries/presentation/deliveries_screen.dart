part of '../../operations/presentation/operations_screen.dart';

class DeliveriesScreen extends OperationsScreen {
  const DeliveriesScreen({super.key}) : super(module: 'Deliveries');
}

extension _DeliveriesWorkflow on _OperationsScreenState {
  Widget _deliveryFilters(AgencyState state) {
    final range = _deliveryDateRange;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 158,
          child: DropdownButtonFormField<String>(
            key: ValueKey(range != null),
            isExpanded: true,
            initialValue: range == null ? _dateFilter : 'Custom range',
            decoration: const InputDecoration(labelText: 'Delivery date'),
            items: [
              if (range != null)
                const DropdownMenuItem(
                  value: 'Custom range',
                  child: Text('Custom range'),
                ),
              for (final date in [
                'All dates',
                'Today',
                'This week',
                'This month',
              ])
                DropdownMenuItem(
                  value: date,
                  child: Text(date, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => _updateView(() {
              if (value == 'Custom range') return;
              _dateFilter = value ?? 'Today';
              _deliveryDateRange = null;
            }),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: 'all',
            decoration: const InputDecoration(labelText: 'Delivery person'),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All people')),
              const DropdownMenuItem(
                value: 'unassigned',
                child: Text('Unassigned'),
              ),
              for (final person in state.staffList.where(
                (person) =>
                    person.role == 'Staff' ||
                    state.deliveryList.any(
                      (delivery) => delivery.staffId == person.id,
                    ),
              ))
                DropdownMenuItem(
                  value: person.id,
                  child: Text(person.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) =>
                _updateView(() => _deliveryStaffFilter = value),
          ),
        ),
        SizedBox(
          width: 162,
          child: DropdownButtonFormField<String>(
            initialValue: _emptyReturnFilter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Empty returns'),
            items: [
              for (final option in [
                'All returns',
                'Returns remaining',
                'Returns complete',
              ])
                DropdownMenuItem(
                  value: option,
                  child: Text(option, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) =>
                _updateView(() => _emptyReturnFilter = value ?? 'All returns'),
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text(
            range == null
                ? 'Custom dates'
                : '${shortDate(range.start)} – ${shortDate(range.end)}',
          ),
          onPressed: () async {
            final picked = await showDialog<DateTimeRange>(
              context: context,
              builder: (context) => _DeliveryDatesDialog(initialRange: range),
            );
            if (picked != null && mounted) {
              _updateView(() => _deliveryDateRange = picked);
            }
          },
        ),
      ],
    );
  }

  bool _matchesDeliveryDate(DateTime timestamp) {
    final date = DateUtils.dateOnly(timestamp.toLocal());
    final range = _deliveryDateRange;
    if (range != null) {
      return !date.isBefore(range.start) && !date.isAfter(range.end);
    }
    return _withinDateFilter(date);
  }

  void _buildDeliveriesRows(
    AgencyState state,
    bool Function(String) matches,
    List<_RecordRow> rows,
  ) {
    for (final delivery in state.deliveryList) {
      final order = state.orderList
          .where((item) => item.id == delivery.orderId)
          .firstOrNull;
      if (order == null ||
          order.status == 'Pending' ||
          order.status == 'Confirmed' ||
          order.status == 'Cancelled') {
        continue;
      }
      final status = deliveryStatusLabel(
        delivery.status,
        assigned: delivery.staffId != null,
      );
      final remaining = delivery.pendingEmpty;
      if (_emptyReturnFilter == 'Returns remaining' && (remaining ?? 0) == 0) {
        continue;
      }
      if (_emptyReturnFilter == 'Returns complete' && remaining != 0) continue;
      if (_filter != 'All' && status != _filter) continue;
      final person = _deliveryStaffFilter;
      if (person != null &&
          person != 'all' &&
          (person == 'unassigned'
              ? delivery.staffId != null
              : delivery.staffId != person)) {
        continue;
      }
      if (!_matchesDeliveryDate(delivery.deliveredAt ?? order.createdAt)) {
        continue;
      }
      final completed = delivery.status == 'Delivered';
      final customer = _customerName(state, order.customerId);
      final staff =
          state.staffList
              .where((item) => item.id == delivery.staffId)
              .firstOrNull
              ?.name ??
          'Unassigned';
      if (!matches('${order.number} $customer $staff $status')) {
        continue;
      }
      rows.add(
        _RecordRow(
          title: order.number,
          subtitle: '$customer · $staff',
          detail: delivery.deliveredAt == null
              ? 'Booked ${shortDate(order.createdAt.toLocal())}'
              : 'Delivered ${shortDate(delivery.deliveredAt!.toLocal())}',
          extraDetails: completed ? _deliveryReturnSummary(delivery) : null,
          status: status,
          action: completed
              ? () => context.push('/orders/${Uri.encodeComponent(order.id)}')
              : () => _deliveryForm(state, delivery),
          menu: [
            if (!completed)
              _Action(
                status == 'Pending' ? 'Assign delivery' : 'Mark delivered',
                Icons.edit_outlined,
                () => _deliveryForm(state, delivery),
              ),
          ],
        ),
      );
    }
  }

  Widget _deliveryReturnSummary(Delivery delivery) {
    final remaining = delivery.pendingEmpty;
    const style = TextStyle(fontSize: 12, color: Color(0xFF56677D));
    if (remaining == null) {
      return const Text('Empty returns unavailable', style: style);
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text('Good received ${delivery.returnedEmpty}', style: style),
        Text('Damaged ${delivery.damagedEmpty}', style: style),
        Text(
          'Remaining $remaining',
          style: style.copyWith(
            color: remaining == 0
                ? const Color(0xFF16845B)
                : const Color(0xFFB36A00),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (remaining > 0)
          TextButton(
            onPressed: () => _emptyReturnsForm(delivery),
            child: const Text('Record returns'),
          ),
      ],
    );
  }

  Future<void> _deliveryForm(AgencyState state, Delivery delivery) async {
    final currentStatus = deliveryStatusLabel(
      delivery.status,
      assigned: delivery.staffId != null,
    );
    var status = currentStatus == 'Pending' ? 'Assigned' : 'Delivered';
    var staffId = delivery.staffId;
    final order = state.orderList.firstWhere(
      (item) => item.id == delivery.orderId,
    );
    final empties = TextEditingController(text: '0');
    final damaged = TextEditingController(text: '0');
    final notes = TextEditingController(text: delivery.notes);
    final key = GlobalKey<FormState>();
    final staff = state.staffList
        .where((item) => item.active && item.role == 'Staff')
        .toList();
    if (status == 'Pending' || !staff.any((member) => member.id == staffId)) {
      staffId = null;
    }
    await _dialogForm(
      title: currentStatus == 'Pending' ? 'Assign delivery' : 'Update delivery',
      fields: (setDialogState) => Form(
        key: key,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Delivery status'),
                items: [
                  for (final option in [
                    'Pending',
                    'Assigned',
                    if (currentStatus == 'Assigned') 'Delivered',
                  ])
                    DropdownMenuItem(value: option, child: Text(option)),
                ],
                onChanged: (value) => setDialogState(() {
                  status = value ?? status;
                  if (status == 'Pending') staffId = null;
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                key: ValueKey(status == 'Pending'),
                initialValue: staffId,
                decoration: const InputDecoration(labelText: 'Delivery staff'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Unassigned'),
                  ),
                  ...staff.map(
                    (member) => DropdownMenuItem(
                      value: member.id,
                      child: Text(member.name),
                    ),
                  ),
                ],
                validator: (value) => status != 'Pending' && value == null
                    ? 'Select a delivery person.'
                    : null,
                onChanged: status == 'Pending'
                    ? null
                    : (value) => setDialogState(() => staffId = value),
              ),
            ),
            _field(notes, 'Delivery notes (optional)', maxLines: 2),
            if (status == 'Delivered') ...[
              Text('Delivered quantity: ${order.quantity}'),
              _emptyCountFields(
                empties,
                damaged,
                order.quantity,
                setDialogState,
              ),
            ],
          ],
        ),
      ),
      validate: () => key.currentState!.validate(),
      save: () => ref
          .read(agencyControllerProvider.notifier)
          .updateDelivery(
            Delivery(
              id: delivery.id,
              orderId: delivery.orderId,
              status: status,
              staffId: staffId,
              notes: notes.text.trim(),
              deliveredQuantity: status == 'Delivered' ? order.quantity : null,
              damagedEmpty: status == 'Delivered' ? int.parse(damaged.text) : 0,
              returnedEmpty: status == 'Delivered'
                  ? int.parse(empties.text)
                  : null,
            ),
          ),
    );
    notes.dispose();
    empties.dispose();
    damaged.dispose();
  }

  Widget _emptyCountFields(
    TextEditingController serviceable,
    TextEditingController damaged,
    int quantity,
    StateSetter setDialogState, {
    int minimumGood = 0,
    int minimumDamaged = 0,
  }) {
    final goodCount = int.tryParse(serviceable.text);
    final damagedCount = int.tryParse(damaged.text);
    final pending =
        goodCount != null &&
            damagedCount != null &&
            goodCount >= minimumGood &&
            goodCount <= quantity &&
            damagedCount >= minimumDamaged &&
            damagedCount <= quantity - goodCount
        ? quantity - goodCount - damagedCount
        : null;
    String? validate(String? value, int minimum) {
      final count = int.tryParse(value ?? '');
      if (count == null || count < minimum || count > quantity) {
        return 'Enter a count from $minimum to $quantity.';
      }
      if ((goodCount ?? 0) > quantity - (damagedCount ?? 0)) {
        return 'Combined returns cannot exceed $quantity.';
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          serviceable,
          'Serviceable empties received',
          keyboardType: TextInputType.number,
          onChanged: (_) => setDialogState(() {}),
          validator: (value) => validate(value, minimumGood),
        ),
        _field(
          damaged,
          'Damaged empties received',
          keyboardType: TextInputType.number,
          onChanged: (_) => setDialogState(() {}),
          validator: (value) => validate(value, minimumDamaged),
        ),
        if (pending != null) Text('Empties pending: $pending'),
      ],
    );
  }

  Future<void> _emptyReturnsForm(Delivery delivery) async {
    final serviceable = TextEditingController(
      text: '${delivery.returnedEmpty}',
    );
    final damaged = TextEditingController(text: '${delivery.damagedEmpty}');
    final key = GlobalKey<FormState>();
    await _dialogForm(
      title: 'Record empty returns',
      fields: (setDialogState) => Form(
        key: key,
        child: Column(
          children: [
            const Text('Enter the total received so far for this booking.'),
            const SizedBox(height: 12),
            _emptyCountFields(
              serviceable,
              damaged,
              delivery.deliveredQuantity!,
              setDialogState,
              minimumGood: delivery.returnedEmpty!,
              minimumDamaged: delivery.damagedEmpty,
            ),
          ],
        ),
      ),
      validate: () => key.currentState!.validate(),
      save: () => ref
          .read(agencyControllerProvider.notifier)
          .recordEmptyReturns(
            delivery.orderId,
            int.parse(serviceable.text),
            int.parse(damaged.text),
          ),
    );
    serviceable.dispose();
    damaged.dispose();
  }
}

class _DeliveryDatesDialog extends StatefulWidget {
  const _DeliveryDatesDialog({this.initialRange});

  final DateTimeRange? initialRange;

  @override
  State<_DeliveryDatesDialog> createState() => _DeliveryDatesDialogState();
}

class _DeliveryDatesDialogState extends State<_DeliveryDatesDialog> {
  final _today = DateUtils.dateOnly(DateTime.now());
  late DateTime _from = widget.initialRange?.start ?? _today;
  late DateTime _to = widget.initialRange?.end ?? _today;
  bool _selectingEnd = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Delivery date range'),
    scrollable: true,
    content: SizedBox(
      width: 330,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text('From ${shortDate(_from)}'),
                selected: !_selectingEnd,
                onSelected: (_) => setState(() => _selectingEnd = false),
              ),
              ChoiceChip(
                label: Text('To ${shortDate(_to)}'),
                selected: _selectingEnd,
                onSelected: (_) => setState(() => _selectingEnd = true),
              ),
            ],
          ),
          SizedBox(
            height: 310,
            child: CalendarDatePicker(
              key: ValueKey(_selectingEnd),
              initialDate: _selectingEnd ? _to : _from,
              firstDate: _selectingEnd ? _from : DateTime(2000),
              lastDate: _today,
              onDateChanged: (date) => setState(() {
                if (_selectingEnd) {
                  _to = date;
                } else {
                  _from = date;
                  if (_to.isBefore(date)) _to = date;
                  _selectingEnd = true;
                }
              }),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.pop(context, DateTimeRange(start: _from, end: _to)),
        child: const Text('Apply dates'),
      ),
    ],
  );
}
