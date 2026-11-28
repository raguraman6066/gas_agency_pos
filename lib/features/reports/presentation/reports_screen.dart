part of '../../operations/presentation/operations_screen.dart';

class ReportsScreen extends OperationsScreen {
  const ReportsScreen({super.key}) : super(module: 'Reports');
}

extension _ReportsWorkflow on _OperationsScreenState {
  Widget _reports(AgencyState state) {
    final fromDay = DateTime(_from.year, _from.month, _from.day);
    final toDay = DateTime(_to.year, _to.month, _to.day + 1);
    var lines = _reportLines(state)
        .where(
          (line) => !line.date.isBefore(fromDay) && line.date.isBefore(toDay),
        )
        .where(
          (line) => '${line.primary} ${line.secondary}'.toLowerCase().contains(
            _search.text.toLowerCase(),
          ),
        )
        .toList();
    if (const [
      'Daily sales',
      'Weekly sales',
      'Monthly sales',
    ].contains(_reportType)) {
      lines = _groupSales(lines);
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
            style: TextStyle(fontSize: 13, color: Color(0xFF778397)),
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
                            'Weekly sales',
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
                      _updateView(() => _reportType = value ?? _reportType),
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
              OutlinedButton.icon(
                onPressed: lines.isEmpty ? null : () => _downloadReport(lines),
                icon: const Icon(Icons.download_outlined, size: 17),
                label: const Text('Download CSV'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => _updateView(() {}),
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
                              fontSize: 14,
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
                              fontSize: 13,
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
      _updateView(() {
        if (isFrom) {
          _from = date;
        } else {
          _to = date;
        }
      });
    }
  }

  void _downloadReport(List<_ReportLine> lines) {
    String cell(Object value) => '"${value.toString().replaceAll('"', '""')}"';
    final csv = StringBuffer('Date,Record,Details,Amount\r\n');
    for (final line in lines) {
      csv.writeln(
        [
          shortDate(line.date),
          line.primary,
          line.secondary,
          line.amount.toStringAsFixed(2),
        ].map(cell).join(','),
      );
    }
    final reportName = _reportType
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final date = DateTime.now().toIso8601String().substring(0, 10);
    downloadText(
      csv.toString(),
      'agency_${reportName}_$date.csv',
      'text/csv;charset=utf-8',
    );
  }

  List<_ReportLine> _reportLines(AgencyState state) {
    final result = <_ReportLine>[];
    switch (_reportType) {
      case 'Daily sales':
      case 'Weekly sales':
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

  List<_ReportLine> _groupSales(List<_ReportLine> lines) {
    final grouped = <DateTime, List<_ReportLine>>{};
    for (final line in lines) {
      final date = line.date.toLocal();
      final period = switch (_reportType) {
        'Monthly sales' => DateTime(date.year, date.month),
        'Weekly sales' => DateTime(
          date.year,
          date.month,
          date.day - date.weekday + 1,
        ),
        _ => DateTime(date.year, date.month, date.day),
      };
      grouped.putIfAbsent(period, () => []).add(line);
    }
    return grouped.entries.map((entry) {
      final values = entry.value;
      final date = entry.key;
      final label = switch (_reportType) {
        'Monthly sales' => '${_monthName(date.month)} ${date.year}',
        'Weekly sales' => 'Week of ${shortDate(date)}',
        _ => shortDate(date),
      };
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF778397),
                  ),
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
