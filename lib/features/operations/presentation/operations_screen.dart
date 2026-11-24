import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/domain/models.dart';
import '../../../core/presentation/common_widgets.dart';
import '../../../core/providers.dart';

class OperationsScreen extends ConsumerStatefulWidget {
  const OperationsScreen({required this.module, super.key});
  final String module;

  @override
  ConsumerState<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends ConsumerState<OperationsScreen> {
  final _search = TextEditingController();
  String _filter = 'All';
  String _dateFilter = 'All dates';
  String _reportType = 'Daily sales';
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  static const _uuid = Uuid();

  @override
  void didUpdateWidget(covariant OperationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module != widget.module) {
      _search.clear();
      _filter = 'All';
      _dateFilter = 'All dates';
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agencyControllerProvider);
    final restricted = {'Products', 'Inventory', 'Reports', 'Staff'};
    if (state.currentRole != 'Admin' && restricted.contains(widget.module)) {
      return const Center(
        child: Text('This section is available to administrators only.'),
      );
    }
    if (widget.module == 'Reports') return _reports(state);
    final loading = state.loading && state.customerList.isEmpty;
    return Padding(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 14 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _moduleHeader(state),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search ${widget.module.toLowerCase()}...',
                    prefixIcon: const Icon(Icons.search, size: 19),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close, size: 18),
                          ),
                  ),
                ),
              ),
              if (_filters.isNotEmpty) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width < 500 ? 116 : 155,
                  child: DropdownButtonFormField<String>(
                    initialValue: _filters.contains(_filter) ? _filter : 'All',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                    items: _filters
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _filter = value ?? 'All'),
                  ),
                ),
              ],
              if (widget.module == 'Orders' || widget.module == 'Payments') ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width < 500 ? 112 : 140,
                  child: DropdownButtonFormField<String>(
                    initialValue: _dateFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                    items:
                        const [
                              'All dates',
                              'Today',
                              'Last 7 days',
                              'Last 30 days',
                            ]
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                  item,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (value) =>
                        setState(() => _dateFilter = value ?? 'All dates'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && _rows(state).isEmpty
                ? Center(child: Text('Could not load data: ${state.error}'))
                : _recordList(state),
          ),
        ],
      ),
    );
  }

  List<String> get _filters => switch (widget.module) {
    'Orders' => const [
      'All',
      'Pending',
      'Confirmed',
      'Assigned',
      'Out for Delivery',
      'Delivered',
      'Cancelled',
    ],
    'Deliveries' => const [
      'All',
      'Pending',
      'Assigned',
      'Out for Delivery',
      'Delivered',
      'Failed',
    ],
    'Customers' => const ['All', 'Active', 'Inactive'],
    'Payments' => const ['All', 'Cash', 'UPI', 'Bank Transfer', 'Other'],
    'Products' || 'Staff' => const ['All', 'Active', 'Inactive'],
    _ => const [],
  };

  Widget _moduleHeader(AgencyState state) {
    final subtitle = switch (widget.module) {
      'Customers' => 'Manage customer details, accounts and order history.',
      'Products' => 'Configure cylinder types, sizes and selling prices.',
      'Orders' => 'Create and track customer orders from booking to delivery.',
      'Deliveries' => 'Assign drivers and update delivery progress.',
      'Inventory' => 'Track filled and empty cylinders and stock movements.',
      'Payments' => 'Record customer payments and follow outstanding balances.',
      'Staff' => 'Manage agency team members and their access roles.',
      _ => '',
    };
    final canAdd = widget.module != 'Inventory';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.module,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C2A3A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF778397)),
              ),
            ],
          ),
        ),
        if (canAdd)
          FilledButton.icon(
            onPressed: () => _addRecord(state),
            icon: const Icon(Icons.add, size: 17),
            label: Text(_addLabel),
          ),
      ],
    );
  }

  String get _addLabel => switch (widget.module) {
    'Orders' => 'New order',
    'Payments' => 'Record payment',
    'Deliveries' => 'Assign delivery',
    'Staff' => 'Add staff',
    'Products' => 'Add product',
    _ => 'Add customer',
  };

  List<_RecordRow> _rows(AgencyState state) {
    final query = _search.text.trim().toLowerCase();
    bool matches(String value) => value.toLowerCase().contains(query);
    final rows = <_RecordRow>[];
    switch (widget.module) {
      case 'Customers':
        for (final customer in state.customerList) {
          if (_filter == 'Active' && !customer.active ||
              _filter == 'Inactive' && customer.active) {
            continue;
          }
          final haystack =
              '${customer.name} ${customer.consumerNumber} ${customer.phone} ${customer.area}';
          if (!matches(haystack)) continue;
          rows.add(
            _RecordRow(
              title: customer.name,
              subtitle: '${customer.consumerNumber} · ${customer.phone}',
              detail: customer.area,
              status: customer.active ? 'Active' : 'Inactive',
              action: () => _customerDetails(state, customer),
              menu: [
                _Action(
                  'View details',
                  Icons.visibility_outlined,
                  () => _customerDetails(state, customer),
                ),
                _Action(
                  'Edit',
                  Icons.edit_outlined,
                  () => _customerForm(customer),
                ),
                _Action(
                  customer.active ? 'Deactivate' : 'Activate',
                  Icons.toggle_on_outlined,
                  () => _saveCustomerActive(customer, !customer.active),
                ),
              ],
            ),
          );
        }
      case 'Products':
        for (final product in state.productList) {
          if (_filter == 'Active' && !product.active ||
              _filter == 'Inactive' && product.active) {
            continue;
          }
          if (!matches('${product.name} ${product.type} ${product.sizeKg}')) {
            continue;
          }
          rows.add(
            _RecordRow(
              title: product.name,
              subtitle: '${product.type} · ${product.sizeKg} kg',
              detail: money(product.price),
              status: product.active ? 'Active' : 'Inactive',
              action: () => _productForm(product),
              menu: [
                _Action(
                  'Edit price and details',
                  Icons.edit_outlined,
                  () => _productForm(product),
                ),
                _Action(
                  product.active ? 'Deactivate' : 'Activate',
                  Icons.toggle_on_outlined,
                  () => _productForm(product.copyWith(active: !product.active)),
                ),
              ],
            ),
          );
        }
      case 'Orders':
        for (final order in state.orderList) {
          if (_filter != 'All' && order.status != _filter) continue;
          if (!_withinDateFilter(order.createdAt)) continue;
          final customer = _customerName(state, order.customerId);
          final product = _productName(state, order.productId);
          if (!matches('${order.number} $customer $product ${order.status}')) {
            continue;
          }
          rows.add(
            _RecordRow(
              title: order.number,
              subtitle: '$customer · $product × ${order.quantity}',
              detail: '${shortDate(order.createdAt)} · ${money(order.total)}',
              status: order.status,
              action: () => _orderDetails(state, order),
              menu: [
                _Action(
                  'View details',
                  Icons.visibility_outlined,
                  () => _orderDetails(state, order),
                ),
                if (order.status != 'Cancelled' && order.status != 'Delivered')
                  _Action(
                    'Edit order',
                    Icons.edit_outlined,
                    () => _orderForm(state, order),
                  ),
                if (order.status != 'Cancelled' && order.status != 'Delivered')
                  _Action(
                    'Cancel order',
                    Icons.cancel_outlined,
                    () => _confirmCancel(order),
                  ),
              ],
            ),
          );
        }
      case 'Deliveries':
        for (final delivery in state.deliveryList) {
          if (_filter != 'All' && delivery.status != _filter) continue;
          final order = state.orderList
              .where((item) => item.id == delivery.orderId)
              .firstOrNull;
          if (order == null) continue;
          final customer = _customerName(state, order.customerId);
          final staff =
              state.staffList
                  .where((item) => item.id == delivery.staffId)
                  .firstOrNull
                  ?.name ??
              'Unassigned';
          if (!matches('${order.number} $customer $staff ${delivery.status}')) {
            continue;
          }
          rows.add(
            _RecordRow(
              title: order.number,
              subtitle: '$customer · $staff',
              detail: delivery.deliveredAt == null
                  ? 'Scheduled delivery'
                  : shortDate(delivery.deliveredAt!),
              status: delivery.status,
              action: () => _deliveryForm(state, delivery),
              menu: [
                _Action(
                  'Update delivery',
                  Icons.edit_outlined,
                  () => _deliveryForm(state, delivery),
                ),
              ],
            ),
          );
        }
      case 'Inventory':
        for (final item in state.inventoryList) {
          final product = _productName(state, item.productId);
          if (!matches(product)) continue;
          rows.add(
            _RecordRow(
              title: product,
              subtitle: '${item.available} available · ${item.booked} booked',
              detail: 'Filled ${item.filled}  ·  Empty ${item.empty}',
              status: item.available <= item.minimum ? 'Low stock' : 'In stock',
              action: () => _inventoryHistory(state, item),
              menu: [
                _Action(
                  'Adjust stock',
                  Icons.tune_rounded,
                  () => _inventoryForm(item),
                ),
                _Action(
                  'Movement history',
                  Icons.history,
                  () => _inventoryHistory(state, item),
                ),
              ],
            ),
          );
        }
      case 'Payments':
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
              subtitle: '$customer · ${payment.method}',
              detail: '${shortDate(payment.date)} · ${money(payment.amount)}',
              action: () => _paymentDetails(payment, order, customer),
              menu: [
                _Action(
                  'View details',
                  Icons.visibility_outlined,
                  () => _paymentDetails(payment, order, customer),
                ),
              ],
            ),
          );
        }
      case 'Staff':
        for (final member in state.staffList) {
          if (_filter == 'Active' && !member.active ||
              _filter == 'Inactive' && member.active) {
            continue;
          }
          if (!matches(
            '${member.name} ${member.email} ${member.phone} ${member.role}',
          )) {
            continue;
          }
          rows.add(
            _RecordRow(
              title: member.name,
              subtitle: member.email,
              detail: '${member.phone} · ${member.role}',
              status: member.active ? 'Active' : 'Inactive',
              action: () => _staffForm(member),
              menu: [
                _Action(
                  'Edit details',
                  Icons.edit_outlined,
                  () => _staffForm(member),
                ),
                _Action(
                  member.active ? 'Deactivate' : 'Activate',
                  Icons.toggle_on_outlined,
                  () => _staffForm(member.copyWith(active: !member.active)),
                ),
              ],
            ),
          );
        }
    }
    return rows;
  }

  Widget _recordList(AgencyState state) {
    final rows = _rows(state);
    if (rows.isEmpty) {
      return Center(
        child: Text(
          _search.text.isEmpty
              ? 'No ${widget.module.toLowerCase()} yet. Add your first record to get started.'
              : 'No records match your search.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF7C899A), fontSize: 12),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 740) {
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _MobileRecord(row: rows[index]),
          );
        }
        return Card(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            children: [
              SizedBox(
                height: 45,
                child: Row(
                  children: const [
                    Expanded(flex: 4, child: _TableHeader('RECORD')),
                    Expanded(flex: 3, child: _TableHeader('DETAILS')),
                    Expanded(flex: 2, child: _TableHeader('STATUS')),
                    SizedBox(width: 42),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (final row in rows) _DesktopRecord(row: row),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addRecord(AgencyState state) async {
    switch (widget.module) {
      case 'Customers':
        await _customerForm();
        break;
      case 'Products':
        await _productForm();
        break;
      case 'Orders':
        await _orderForm(state);
        break;
      case 'Deliveries':
        final pending = state.deliveryList
            .where((d) => d.status == 'Pending')
            .firstOrNull;
        if (pending == null) {
          _message('There are no pending deliveries to assign.');
        } else {
          await _deliveryForm(state, pending);
        }
        break;
      case 'Payments':
        await _paymentForm(state);
        break;
      case 'Staff':
        await _staffForm();
        break;
    }
  }

  String _customerName(AgencyState state, String id) =>
      state.customerList.where((item) => item.id == id).firstOrNull?.name ??
      'Unknown customer';

  String _productName(AgencyState state, String id) =>
      state.productList.where((item) => item.id == id).firstOrNull?.name ??
      'Unknown product';

  bool _withinDateFilter(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalized = DateTime(date.year, date.month, date.day);
    return switch (_dateFilter) {
      'Today' => normalized == today,
      'Last 7 days' => !normalized.isBefore(
        today.subtract(const Duration(days: 6)),
      ),
      'Last 30 days' => !normalized.isBefore(
        today.subtract(const Duration(days: 29)),
      ),
      _ => true,
    };
  }

  Future<void> _saveCustomerActive(Customer customer, bool active) async {
    await _run(
      () => ref
          .read(agencyControllerProvider.notifier)
          .saveCustomer(customer.copyWith(active: active)),
    );
  }

  Future<void> _confirmCancel(AgencyOrder order) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          '${order.number} will be cancelled and its booked stock released. Orders with a recorded payment cannot be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await _run(
        () => ref
            .read(agencyControllerProvider.notifier)
            .updateOrder(order.copyWith(status: 'Cancelled')),
      );
    }
  }

  Future<void> _customerDetails(AgencyState state, Customer customer) async {
    final orders = state.orderList
        .where((order) => order.customerId == customer.id)
        .toList();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(customer.name),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailLine('Consumer number', customer.consumerNumber),
                _detailLine('Phone', customer.phone),
                if (customer.alternativePhone.isNotEmpty)
                  _detailLine('Alternative phone', customer.alternativePhone),
                _detailLine('Address', '${customer.address}, ${customer.area}'),
                _detailLine('Customer since', shortDate(customer.createdAt)),
                const Divider(height: 25),
                const Text(
                  'Order history',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                if (orders.isEmpty)
                  const Text(
                    'No orders recorded.',
                    style: TextStyle(color: Color(0xFF7C899A), fontSize: 12),
                  ),
                for (final order in orders.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${order.number} · ${shortDate(order.createdAt)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        Text(
                          money(order.total),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(order.status),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _orderDetails(AgencyState state, AgencyOrder order) async {
    final product = state.productList
        .where((item) => item.id == order.productId)
        .firstOrNull;
    final customer = state.customerList
        .where((item) => item.id == order.customerId)
        .firstOrNull;
    final delivery = state.deliveryList
        .where((item) => item.orderId == order.id)
        .firstOrNull;
    final paid = state.paymentList
        .where((payment) => payment.orderId == order.id)
        .fold<double>(0, (total, payment) => total + payment.amount);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(order.number)),
            StatusBadge(order.status),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailLine('Customer', customer?.name ?? 'Unknown'),
              _detailLine(
                'Product',
                '${product?.name ?? 'Product'} × ${order.quantity}',
              ),
              _detailLine('Unit price at order', money(order.unitPrice)),
              _detailLine('Order total', money(order.total)),
              _detailLine(
                'Paid / remaining',
                '${money(paid)} / ${money((order.total - paid).clamp(0, order.total))}',
              ),
              _detailLine('Order date', shortDate(order.createdAt)),
              _detailLine('Delivery', delivery?.status ?? 'Not scheduled'),
              if (order.notes.isNotEmpty) _detailLine('Notes', order.notes),
            ],
          ),
        ),
        actions: [
          if (order.status != 'Cancelled' && order.status != 'Delivered')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _orderForm(state, order);
              },
              child: const Text('Edit'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _paymentDetails(
    Payment payment,
    AgencyOrder? order,
    String customer,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment details'),
        content: SizedBox(
          width: 390,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailLine('Order', order?.number ?? 'Order'),
              _detailLine('Customer', customer),
              _detailLine('Amount received', money(payment.amount)),
              _detailLine('Method', payment.method),
              _detailLine('Date', shortDate(payment.date)),
              if (payment.reference.isNotEmpty)
                _detailLine('Reference', payment.reference),
              if (payment.notes.isNotEmpty) _detailLine('Notes', payment.notes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 135,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF7B8798)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
      if (mounted) _message('Changes saved.');
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''), error: true);
      }
    }
  }

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error
            ? const Color(0xFFB42318)
            : const Color(0xFF26364A),
      ),
    );
  }

  Future<void> _dialogForm({
    required String title,
    required Widget Function(StateSetter setDialogState) fields,
    required bool Function() validate,
    required Future<void> Function() save,
  }) async {
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  fields(setDialogState),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: Color(0xFFB42318),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!validate()) return;
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await save();
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) _message('Changes saved.');
                      } catch (exception) {
                        setDialogState(() {
                          saving = false;
                          error = exception.toString().replaceFirst(
                            'Bad state: ',
                            '',
                          );
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  Future<void> _customerForm([Customer? old]) async {
    final name = TextEditingController(text: old?.name ?? '');
    final consumer = TextEditingController(text: old?.consumerNumber ?? '');
    final phone = TextEditingController(text: old?.phone ?? '');
    final alternate = TextEditingController(text: old?.alternativePhone ?? '');
    final address = TextEditingController(text: old?.address ?? '');
    final area = TextEditingController(text: old?.area ?? '');
    final key = GlobalKey<FormState>();
    await _dialogForm(
      title: old == null ? 'Add customer' : 'Edit customer',
      fields: (_) => Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(name, 'Customer name', validator: _required),
            _field(consumer, 'Consumer number', validator: _required),
            _field(
              phone,
              'Phone number',
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.trim().length < 7
                  ? 'Enter a valid phone number.'
                  : null,
            ),
            _field(
              alternate,
              'Alternative phone (optional)',
              keyboardType: TextInputType.phone,
            ),
            _field(address, 'Address', validator: _required),
            _field(area, 'Area', validator: _required),
          ],
        ),
      ),
      validate: () => key.currentState!.validate(),
      save: () => ref
          .read(agencyControllerProvider.notifier)
          .saveCustomer(
            Customer(
              id: old?.id ?? _uuid.v4(),
              name: name.text.trim(),
              consumerNumber: consumer.text.trim(),
              phone: phone.text.trim(),
              alternativePhone: alternate.text.trim(),
              address: address.text.trim(),
              area: area.text.trim(),
              createdAt: old?.createdAt ?? DateTime.now(),
              active: old?.active ?? true,
            ),
          ),
    );
    for (final controller in [
      name,
      consumer,
      phone,
      alternate,
      address,
      area,
    ]) {
      controller.dispose();
    }
  }

  Future<void> _productForm([Product? old]) async {
    final name = TextEditingController(text: old?.name ?? '');
    final size = TextEditingController(text: (old?.sizeKg ?? 14).toString());
    final price = TextEditingController(
      text: old?.price.toStringAsFixed(0) ?? '',
    );
    final key = GlobalKey<FormState>();
    var type = old?.type ?? 'Domestic';
    await _dialogForm(
      title: old == null ? 'Add product' : 'Edit product',
      fields: (setDialogState) => Form(
        key: key,
        child: Column(
          children: [
            _field(name, 'Product name', validator: _required),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Product type'),
                items: const ['Domestic', 'Commercial']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => type = value ?? type),
              ),
            ),
            _field(
              size,
              'Cylinder size (kg)',
              keyboardType: TextInputType.number,
              validator: (value) =>
                  int.tryParse(value ?? '') == null || int.parse(value!) <= 0
                  ? 'Enter a valid size.'
                  : null,
            ),
            _field(
              price,
              'Selling price (₹)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) =>
                  double.tryParse(value ?? '') == null ||
                      double.parse(value!) <= 0
                  ? 'Enter a valid price.'
                  : null,
            ),
          ],
        ),
      ),
      validate: () => key.currentState!.validate(),
      save: () => ref
          .read(agencyControllerProvider.notifier)
          .saveProduct(
            Product(
              id: old?.id ?? _uuid.v4(),
              name: name.text.trim(),
              type: type,
              sizeKg: int.parse(size.text),
              price: double.parse(price.text),
              active: old?.active ?? true,
            ),
          ),
    );
    name.dispose();
    size.dispose();
    price.dispose();
  }

  Future<void> _orderForm(AgencyState state, [AgencyOrder? old]) async {
    final customers = state.customerList.where((c) => c.active).toList();
    final products = state.productList.where((p) => p.active).toList();
    if (customers.isEmpty || products.isEmpty) {
      _message(
        'Add an active customer and product before creating an order.',
        error: true,
      );
      return;
    }
    var customerId = old?.customerId ?? customers.first.id;
    var productId = old?.productId ?? products.first.id;
    final quantity = TextEditingController(
      text: old?.quantity.toString() ?? '1',
    );
    final notes = TextEditingController(text: old?.notes ?? '');
    final key = GlobalKey<FormState>();
    await _dialogForm(
      title: old == null ? 'Create new order' : 'Edit order ${old.number}',
      fields: (setDialogState) => Form(
        key: key,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: customerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Customer'),
                items: customers
                    .map(
                      (customer) => DropdownMenuItem(
                        value: customer.id,
                        child: Text(
                          '${customer.name} · ${customer.consumerNumber}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => customerId = value ?? customerId),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: productId,
                decoration: const InputDecoration(labelText: 'Product'),
                items: products
                    .map(
                      (product) => DropdownMenuItem(
                        value: product.id,
                        child: Text(
                          '${product.name} (${product.sizeKg} kg) · ${money(product.price)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => productId = value ?? productId),
              ),
            ),
            _field(
              quantity,
              'Quantity',
              keyboardType: TextInputType.number,
              validator: (value) =>
                  int.tryParse(value ?? '') == null || int.parse(value!) <= 0
                  ? 'Quantity must be at least one.'
                  : null,
            ),
            _field(notes, 'Order notes (optional)', maxLines: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Total: ${money((products.where((p) => p.id == productId).firstOrNull?.price ?? 0) * (int.tryParse(quantity.text) ?? 0))}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1769D2),
                ),
              ),
            ),
          ],
        ),
      ),
      validate: () => key.currentState!.validate(),
      save: () {
        final selected = products.firstWhere(
          (product) => product.id == productId,
        );
        final order = AgencyOrder(
          id: old?.id ?? _uuid.v4(),
          number: old?.number ?? '',
          customerId: customerId,
          productId: productId,
          quantity: int.parse(quantity.text),
          unitPrice: selected.price,
          status: old?.status ?? 'Pending',
          createdAt: old?.createdAt ?? DateTime.now(),
          notes: notes.text.trim(),
        );
        return old == null
            ? ref.read(agencyControllerProvider.notifier).createOrder(order)
            : ref.read(agencyControllerProvider.notifier).updateOrder(order);
      },
    );
    quantity.dispose();
    notes.dispose();
  }

  Future<void> _deliveryForm(AgencyState state, Delivery delivery) async {
    var status = delivery.status;
    var staffId = delivery.staffId;
    final notes = TextEditingController(text: delivery.notes);
    final key = GlobalKey<FormState>();
    final staff = state.staffList
        .where((item) => item.active && item.role == 'Staff')
        .toList();
    if (staff.isNotEmpty &&
        (staffId == null || !staff.any((member) => member.id == staffId))) {
      staffId = staff.first.id;
    }
    await _dialogForm(
      title: 'Update delivery',
      fields: (setDialogState) => Form(
        key: key,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Delivery status'),
                items:
                    const [
                          'Pending',
                          'Assigned',
                          'Out for Delivery',
                          'Delivered',
                          'Failed',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) =>
                    setDialogState(() => status = value ?? status),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
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
                onChanged: (value) => setDialogState(() => staffId = value),
              ),
            ),
            _field(notes, 'Delivery notes (optional)', maxLines: 2),
            if (status == 'Delivered')
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Completing delivery deducts filled stock and adds an empty cylinder.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF52657B)),
                ),
              ),
          ],
        ),
      ),
      validate: () => true,
      save: () => ref
          .read(agencyControllerProvider.notifier)
          .updateDelivery(
            Delivery(
              id: delivery.id,
              orderId: delivery.orderId,
              status: status,
              staffId: staffId,
              notes: notes.text.trim(),
            ),
          ),
    );
    notes.dispose();
  }

  Future<void> _inventoryForm(Inventory inventory) async {
    final filled = TextEditingController(text: '0');
    final empty = TextEditingController(text: '0');
    final note = TextEditingController();
    final key = GlobalKey<FormState>();
    await _dialogForm(
      title:
          'Adjust ${_productName(ref.read(agencyControllerProvider), inventory.productId)} stock',
      fields: (_) => Form(
        key: key,
        child: Column(
          children: [
            _field(
              filled,
              'Filled cylinder change (+ or -)',
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              validator: (value) => int.tryParse(value ?? '') == null
                  ? 'Enter a whole number, such as 5 or -2.'
                  : null,
            ),
            _field(
              empty,
              'Empty cylinder change (+ or -)',
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              validator: (value) => int.tryParse(value ?? '') == null
                  ? 'Enter a whole number, such as 5 or -2.'
                  : null,
            ),
            _field(note, 'Reason / note', validator: _required, maxLines: 2),
          ],
        ),
      ),
      validate: () => key.currentState!.validate(),
      save: () => ref
          .read(agencyControllerProvider.notifier)
          .adjustInventory(
            inventory.productId,
            int.parse(filled.text),
            int.parse(empty.text),
            note.text.trim(),
          ),
    );
    filled.dispose();
    empty.dispose();
    note.dispose();
  }

  Future<void> _inventoryHistory(AgencyState state, Inventory inventory) async {
    final movements = state.movementList
        .where((item) => item.productId == inventory.productId)
        .toList();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_productName(state, inventory.productId)} movements'),
        content: SizedBox(
          width: 460,
          height: 300,
          child: movements.isEmpty
              ? const Center(child: Text('No stock movement history.'))
              : ListView.separated(
                  itemCount: movements.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final movement = movements[index];
                    String signed(int value) =>
                        value > 0 ? '+$value' : '$value';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        movement.kind,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${shortDate(movement.createdAt)}${movement.note.isEmpty ? '' : ' · ${movement.note}'}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      trailing: Text(
                        'F ${signed(movement.filledChange)} / E ${signed(movement.emptyChange)} / B ${signed(movement.bookedChange)}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _inventoryForm(inventory);
            },
            icon: const Icon(Icons.tune, size: 16),
            label: const Text('Adjust stock'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
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
    var method = 'Cash';
    final amount = TextEditingController();
    final reference = TextEditingController();
    final notes = TextEditingController();
    final key = GlobalKey<FormState>();
    void updateAmount() {
      final order = outstandingOrders.firstWhere((item) => item.id == orderId);
      final paid = state.paymentList
          .where((payment) => payment.orderId == orderId)
          .fold<double>(0, (sum, payment) => sum + payment.amount);
      amount.text = (order.total - paid).toStringAsFixed(0);
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
                if (entered == null || entered <= 0) {
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
                items: const ['Cash', 'UPI', 'Bank Transfer', 'Other']
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

  Future<void> _staffForm([StaffMember? old]) async {
    final name = TextEditingController(text: old?.name ?? '');
    final email = TextEditingController(text: old?.email ?? '');
    final phone = TextEditingController(text: old?.phone ?? '');
    final key = GlobalKey<FormState>();
    var role = old?.role ?? 'Staff';
    await _dialogForm(
      title: old == null ? 'Add staff member' : 'Edit staff member',
      fields: (setDialogState) => Form(
        key: key,
        child: Column(
          children: [
            _field(name, 'Full name', validator: _required),
            _field(
              email,
              'Email address',
              keyboardType: TextInputType.emailAddress,
              validator: (value) => value == null || !value.contains('@')
                  ? 'Enter a valid email address.'
                  : null,
            ),
            _field(
              phone,
              'Phone number',
              keyboardType: TextInputType.phone,
              validator: _required,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const ['Admin', 'Staff']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => role = value ?? role),
              ),
            ),
          ],
        ),
      ),
      validate: () => key.currentState!.validate(),
      save: () => ref
          .read(agencyControllerProvider.notifier)
          .saveStaff(
            StaffMember(
              id: old?.id ?? _uuid.v4(),
              name: name.text.trim(),
              email: email.text.trim(),
              phone: phone.text.trim(),
              role: role,
              active: old?.active ?? true,
            ),
          ),
    );
    name.dispose();
    email.dispose();
    phone.dispose();
  }

  Widget _reports(AgencyState state) {
    final fromDay = DateTime(_from.year, _from.month, _from.day);
    final toDay = DateTime(_to.year, _to.month, _to.day, 23, 59, 59);
    var lines = _reportLines(state)
        .where(
          (line) => !line.date.isBefore(fromDay) && !line.date.isAfter(toDay),
        )
        .where(
          (line) => '${line.primary} ${line.secondary}'.toLowerCase().contains(
            _search.text.toLowerCase(),
          ),
        )
        .toList();
    if (_reportType == 'Daily sales') {
      lines = _groupSales(lines, monthly: false);
    } else if (_reportType == 'Monthly sales') {
      lines = _groupSales(lines, monthly: true);
    } else if (_reportType == 'Customer outstanding') {
      lines = _groupOutstanding(lines);
    }
    final total = lines.fold<double>(0, (sum, line) => sum + line.amount);
    final count = lines.length;
    return Padding(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 14 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reports',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C2A3A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Useful summaries calculated from your agency records.',
            style: TextStyle(fontSize: 11, color: Color(0xFF778397)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: MediaQuery.sizeOf(context).width < 500 ? 180 : 205,
                child: DropdownButtonFormField<String>(
                  initialValue: _reportType,
                  decoration: const InputDecoration(
                    labelText: 'Report type',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items:
                      const [
                            'Daily sales',
                            'Monthly sales',
                            'Daily orders',
                            'Payment collection',
                            'Pending payments',
                            'Customer outstanding',
                            'Delivery report',
                            'Inventory report',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) =>
                      setState(() => _reportType = value ?? _reportType),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(true),
                icon: const Icon(Icons.calendar_today, size: 15),
                label: Text(shortDate(_from)),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(false),
                icon: const Icon(Icons.event, size: 15),
                label: Text(shortDate(_to)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search report...',
                    prefixIcon: Icon(Icons.search, size: 19),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ReportMetric(
                  title: 'Matching records',
                  value: '$count',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReportMetric(
                  title:
                      _reportType.contains('payment') ||
                          _reportType.contains('sales') ||
                          _reportType.contains('outstanding')
                      ? 'Total amount'
                      : 'Quantity / amount',
                  value: money(total),
                  icon: Icons.currency_rupee,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: lines.isEmpty
                ? const Center(
                    child: Text(
                      'No report records for this date range.',
                      style: TextStyle(color: Color(0xFF7C899A), fontSize: 12),
                    ),
                  )
                : Card(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: lines.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final line = lines[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            line.primary,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${line.secondary} · ${shortDate(line.date)}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          trailing: Text(
                            line.amount == 0 ? '—' : money(line.amount),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        if (isFrom) {
          _from = date;
        } else {
          _to = date;
        }
      });
    }
  }

  List<_ReportLine> _reportLines(AgencyState state) {
    final result = <_ReportLine>[];
    switch (_reportType) {
      case 'Daily sales':
      case 'Monthly sales':
        for (final order in state.orderList.where(
          (item) => item.status == 'Delivered',
        )) {
          final deliveredAt = state.deliveryList
              .where((delivery) => delivery.orderId == order.id)
              .firstOrNull
              ?.deliveredAt;
          result.add(
            _ReportLine(
              order.number,
              _customerName(state, order.customerId),
              order.total,
              deliveredAt ?? order.createdAt,
            ),
          );
        }
      case 'Daily orders':
        for (final order in state.orderList) {
          result.add(
            _ReportLine(
              order.number,
              '${_customerName(state, order.customerId)} · ${order.status}',
              order.total,
              order.createdAt,
            ),
          );
        }
      case 'Payment collection':
        for (final payment in state.paymentList) {
          result.add(
            _ReportLine(
              _orderNumber(state, payment.orderId),
              '${payment.method} · ${_customerForOrder(state, payment.orderId)}',
              payment.amount,
              payment.date,
            ),
          );
        }
      case 'Pending payments':
      case 'Customer outstanding':
        final paidByOrder = <String, double>{};
        for (final payment in state.paymentList) {
          paidByOrder.update(
            payment.orderId,
            (value) => value + payment.amount,
            ifAbsent: () => payment.amount,
          );
        }
        for (final order in state.orderList.where(
          (item) => item.status != 'Cancelled',
        )) {
          final due = (order.total - (paidByOrder[order.id] ?? 0))
              .clamp(0, order.total)
              .toDouble();
          if (due > .001) {
            result.add(
              _ReportLine(
                _reportType == 'Customer outstanding'
                    ? _customerName(state, order.customerId)
                    : order.number,
                _reportType == 'Customer outstanding'
                    ? order.number
                    : _customerName(state, order.customerId),
                due,
                order.createdAt,
              ),
            );
          }
        }
      case 'Delivery report':
        for (final delivery in state.deliveryList) {
          final order = state.orderList
              .where((item) => item.id == delivery.orderId)
              .firstOrNull;
          if (order != null) {
            result.add(
              _ReportLine(
                order.number,
                '${_customerName(state, order.customerId)} · ${delivery.status}',
                order.total,
                delivery.deliveredAt ?? order.createdAt,
              ),
            );
          }
        }
      case 'Inventory report':
        for (final item in state.inventoryList) {
          result.add(
            _ReportLine(
              _productName(state, item.productId),
              'Filled ${item.filled} · Empty ${item.empty} · Booked ${item.booked}',
              item.available.toDouble(),
              DateTime.now(),
            ),
          );
        }
    }
    return result;
  }

  List<_ReportLine> _groupSales(
    List<_ReportLine> lines, {
    required bool monthly,
  }) {
    final grouped = <String, List<_ReportLine>>{};
    for (final line in lines) {
      final key = monthly
          ? '${line.date.year}-${line.date.month.toString().padLeft(2, '0')}'
          : '${line.date.year}-${line.date.month.toString().padLeft(2, '0')}-${line.date.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(line);
    }
    return grouped.entries.map((entry) {
      final values = entry.value;
      final date = values.first.date;
      final label = monthly
          ? '${_monthName(date.month)} ${date.year}'
          : shortDate(date);
      return _ReportLine(
        label,
        '${values.length} delivered order${values.length == 1 ? '' : 's'}',
        values.fold<double>(0, (sum, item) => sum + item.amount),
        date,
      );
    }).toList()..sort((left, right) => left.date.compareTo(right.date));
  }

  List<_ReportLine> _groupOutstanding(List<_ReportLine> lines) {
    final grouped = <String, List<_ReportLine>>{};
    for (final line in lines) {
      grouped.putIfAbsent(line.primary, () => []).add(line);
    }
    return grouped.entries.map((entry) {
      final values = entry.value;
      return _ReportLine(
        entry.key,
        '${values.length} outstanding order${values.length == 1 ? '' : 's'}',
        values.fold<double>(0, (sum, item) => sum + item.amount),
        values
            .map((item) => item.date)
            .reduce((left, right) => left.isAfter(right) ? left : right),
      );
    }).toList()..sort((left, right) => right.amount.compareTo(left.amount));
  }

  String _monthName(int month) => const [
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

  String _orderNumber(AgencyState state, String id) =>
      state.orderList.where((item) => item.id == id).firstOrNull?.number ??
      'Order';

  String _customerForOrder(AgencyState state, String id) {
    final order = state.orderList.where((item) => item.id == id).firstOrNull;
    return order == null ? 'Customer' : _customerName(state, order.customerId);
  }
}

class _RecordRow {
  const _RecordRow({
    required this.title,
    required this.subtitle,
    required this.detail,
    this.status,
    required this.action,
    required this.menu,
  });
  final String title;
  final String subtitle;
  final String detail;
  final String? status;
  final VoidCallback action;
  final List<_Action> menu;
}

class _Action {
  const _Action(this.label, this.icon, this.run);
  final String label;
  final IconData icon;
  final VoidCallback run;
}

class _MobileRecord extends StatelessWidget {
  const _MobileRecord({required this.row});
  final _RecordRow row;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: row.action,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 11, 5, 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    row.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF748195),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    row.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF56677D),
                    ),
                  ),
                ],
              ),
            ),
            if (row.status != null) ...[
              const SizedBox(width: 8),
              StatusBadge(row.status!),
            ],
            PopupMenuButton<int>(
              itemBuilder: (context) => row.menu
                  .asMap()
                  .entries
                  .map(
                    (entry) => PopupMenuItem(
                      value: entry.key,
                      child: Row(
                        children: [
                          Icon(entry.value.icon, size: 17),
                          const SizedBox(width: 9),
                          Text(entry.value.label),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onSelected: (index) => row.menu[index].run(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DesktopRecord extends StatelessWidget {
  const _DesktopRecord({required this.row});
  final _RecordRow row;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: row.action,
    child: Container(
      height: 59,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F2F5))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF26364A),
                  ),
                ),
                Text(
                  row.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8591A1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              row.detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFF56677D)),
            ),
          ),
          Expanded(
            flex: 2,
            child: row.status == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(row.status!),
                  ),
          ),
          PopupMenuButton<int>(
            itemBuilder: (context) => row.menu
                .asMap()
                .entries
                .map(
                  (entry) => PopupMenuItem(
                    value: entry.key,
                    child: Row(
                      children: [
                        Icon(entry.value.icon, size: 17),
                        const SizedBox(width: 9),
                        Text(entry.value.label),
                      ],
                    ),
                  ),
                )
                .toList(),
            onSelected: (index) => row.menu[index].run(),
          ),
        ],
      ),
    ),
  );
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 9,
      color: Color(0xFF8793A3),
      fontWeight: FontWeight.w700,
      letterSpacing: .6,
    ),
  );
}

class _ReportLine {
  const _ReportLine(this.primary, this.secondary, this.amount, this.date);
  final String primary;
  final String secondary;
  final double amount;
  final DateTime date;
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.title,
    required this.value,
    required this.icon,
  });
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFF1769D2)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF778397)),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
