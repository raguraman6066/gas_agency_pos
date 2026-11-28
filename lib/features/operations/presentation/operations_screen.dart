import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/domain/models.dart';
import '../../../core/presentation/common_widgets.dart';
import '../../../core/providers.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/download_text.dart';

part '../../customers/presentation/customers_screen.dart';
part '../../bookings/presentation/bookings_screen.dart';
part '../../deliveries/presentation/deliveries_screen.dart';
part '../../inventory/presentation/inventory_screen.dart';
part '../../payments/presentation/payments_screen.dart';
part '../../reports/presentation/reports_screen.dart';
part '../../settings/presentation/products_screen.dart';
part '../../settings/presentation/staff_screen.dart';

const double _desktopActionsWidth = kMinInteractiveDimension;

class OperationsScreen extends ConsumerStatefulWidget {
  const OperationsScreen({required this.module, super.key});
  final String module;

  @override
  ConsumerState<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends ConsumerState<OperationsScreen> {
  final _search = TextEditingController();
  String _filter = 'All';
  String _dateFilter = 'Today';
  String _emptyReturnFilter = 'All returns';
  DateTimeRange? _deliveryDateRange;
  String? _deliveryStaffFilter;
  String _reportType = 'Daily sales';
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  final _uuid = const Uuid();

  void _updateView(VoidCallback update) => setState(update);

  @override
  void didUpdateWidget(covariant OperationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module != widget.module) {
      _search.clear();
      _filter = 'All';
      _dateFilter = 'Today';
      _emptyReturnFilter = 'All returns';
      _deliveryStaffFilter = null;
      _deliveryDateRange = null;
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
          if (widget.module == 'Payments') ...[
            const SizedBox(height: 12),
            _paymentSummary(state),
          ],
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
                            child: Text(
                              bookingStatusLabel(item),
                              overflow: TextOverflow.ellipsis,
                            ),
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
                              'Today',
                              'This week',
                              'This month',
                              'All history',
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
                        setState(() => _dateFilter = value ?? 'Today'),
                  ),
                ),
              ],
            ],
          ),
          if (widget.module == 'Deliveries') ...[
            const SizedBox(height: 10),
            _deliveryFilters(state),
          ],
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
    'Orders' => const ['All', 'Pending', 'Assigned', 'Delivered', 'Cancelled'],
    'Deliveries' => const ['All', 'Pending', 'Assigned', 'Delivered'],
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
      'Deliveries' => 'Assign a person to each pending delivery, then mark it delivered and record empty returns.',
      'Inventory' => 'Track filled and empty cylinders and stock movements.',
      'Payments' => 'Record customer payments and follow outstanding balances.',
      'Staff' => 'Manage agency team members and their access roles.',
      _ => '',
    };
    final canAdd = !const [
      'Inventory',
      'Deliveries',
      'Payments',
    ].contains(widget.module);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.module == 'Orders' ? 'Bookings' : widget.module,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C2A3A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Color(0xFF778397)),
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
    'Orders' => 'New booking',
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
        _buildCustomersRows(state, matches, rows);
      case 'Products':
        _buildProductsRows(state, matches, rows);
      case 'Orders':
        _buildOrdersRows(state, matches, rows);
      case 'Deliveries':
        _buildDeliveriesRows(state, matches, rows);
      case 'Inventory':
        _buildInventoryRows(state, matches, rows);
      case 'Payments':
        _buildPaymentsRows(state, matches, rows);
      case 'Staff':
        _buildStaffRows(state, matches, rows);
    }
    return rows;
  }

  Widget _recordList(AgencyState state) {
    final rows = _rows(state);
    if (rows.isEmpty) {
      return Center(
        child: Text(
          widget.module == 'Deliveries'
              ? 'No deliveries match these filters.'
              : _search.text.isEmpty
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
                    SizedBox(width: _desktopActionsWidth),
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
        context.push('/orders/new');
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
    final today = DateUtils.dateOnly(now);
    final normalized = DateUtils.dateOnly(date.toLocal());
    final monday = now.day - today.weekday + 1;
    final weekStart = DateTime(now.year, now.month, monday);
    final nextWeek = DateTime(now.year, now.month, monday + 7);
    final monthStart = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    return switch (_dateFilter) {
      'Today' => normalized == today,
      'This week' =>
        !normalized.isBefore(weekStart) && normalized.isBefore(nextWeek),
      'This month' =>
        !normalized.isBefore(monthStart) && normalized.isBefore(nextMonth),
      _ => true,
    };
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
            style: const TextStyle(fontSize: 13, color: Color(0xFF7B8798)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
        _message(userFriendlyError(error), error: true);
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
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (pageContext) => StatefulBuilder(
          builder: (pageContext, setPageState) => Scaffold(
            appBar: AppBar(
              title: Text(title),
              leading: IconButton(
                tooltip: 'Back',
                onPressed: saving ? null : () => Navigator.pop(pageContext),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          fields(setPageState),
                          if (error != null) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                error!,
                                style: const TextStyle(
                                  color: Color(0xFFB42318),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: saving
                          ? null
                          : () => Navigator.pop(pageContext),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (!validate()) return;
                              setPageState(() {
                                saving = true;
                                error = null;
                              });
                              try {
                                await save();
                                if (pageContext.mounted) {
                                  Navigator.pop(pageContext);
                                }
                                if (mounted) _message('Changes saved.');
                              } catch (exception) {
                                setPageState(() {
                                  saving = false;
                                  error = userFriendlyError(exception);
                                });
                              }
                            },
                      child: saving
                          ? const SizedBox.square(
                              dimension: 18,
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
            ),
          ),
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
    void Function(String)? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

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
    this.extraDetails,
    this.status,
    required this.action,
    required this.menu,
  });
  final String title;
  final String subtitle;
  final String detail;
  final Widget? extraDetails;
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    row.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF748195),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    row.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF56677D),
                    ),
                  ),
                  if (row.extraDetails != null) row.extraDetails!,
                ],
              ),
            ),
            if (row.status != null) ...[
              const SizedBox(width: 8),
              StatusBadge(row.status!),
            ],
            if (row.menu.isNotEmpty)
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
      constraints: const BoxConstraints(minHeight: 59),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F2F5))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF26364A),
                  ),
                ),
                Text(
                  row.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8591A1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF56677D),
                  ),
                ),
                if (row.extraDetails != null) row.extraDetails!,
              ],
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
          SizedBox(
            width: _desktopActionsWidth,
            child: row.menu.isEmpty
                ? null
                : PopupMenuButton<int>(
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
      fontSize: 11,
      color: Color(0xFF8793A3),
      fontWeight: FontWeight.w700,
      letterSpacing: .6,
    ),
  );
}
