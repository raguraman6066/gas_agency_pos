part of '../../operations/presentation/operations_screen.dart';

class CustomersScreen extends OperationsScreen {
  const CustomersScreen({super.key}) : super(module: 'Customers');
}

extension _CustomersWorkflow on _OperationsScreenState {
  void _buildCustomersRows(
    AgencyState state,
    bool Function(String) matches,
    List<_RecordRow> rows,
  ) {
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
            _Action('Edit', Icons.edit_outlined, () => _customerForm(customer)),
            _Action(
              customer.active ? 'Deactivate' : 'Activate',
              Icons.toggle_on_outlined,
              () => _saveCustomerActive(customer, !customer.active),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _saveCustomerActive(Customer customer, bool active) async {
    await _run(
      () => ref
          .read(agencyControllerProvider.notifier)
          .saveCustomer(customer.copyWith(active: active)),
    );
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
                if (customer.gasProvider.isNotEmpty)
                  _detailLine('Gas provider', customer.gasProvider),
                if (customer.gstNumber.isNotEmpty)
                  _detailLine('GST number', customer.gstNumber),
                if (customer.identityDocumentNumber.isNotEmpty)
                  _detailLine(
                    customer.identityDocumentType,
                    customer.identityDocumentNumber,
                  ),
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
                            fontSize: 13,
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

  Future<void> _customerForm([Customer? old]) async {
    final name = TextEditingController(text: old?.name ?? '');
    final consumer = TextEditingController(text: old?.consumerNumber ?? '');
    final phone = TextEditingController(text: old?.phone ?? '');
    final alternate = TextEditingController(text: old?.alternativePhone ?? '');
    final address = TextEditingController(text: old?.address ?? '');
    final area = TextEditingController(text: old?.area ?? '');
    final gstNumber = TextEditingController(text: old?.gstNumber ?? '');
    final identityNumber = TextEditingController(
      text: old?.identityDocumentNumber ?? '',
    );
    final knownProviders = ['HP Gas', 'Indane', 'Bharatgas'];
    final oldProvider = old?.gasProvider ?? '';
    var providerChoice = knownProviders.contains(oldProvider)
        ? oldProvider
        : oldProvider.isEmpty
        ? ''
        : 'Other';
    final otherProvider = TextEditingController(
      text: providerChoice == 'Other' ? oldProvider : '',
    );
    var identityType = old?.identityDocumentType ?? '';
    var customerType = old?.type ?? 'Domestic';
    final key = GlobalKey<FormState>();
    await _dialogForm(
      title: old == null ? 'Add customer' : 'Edit customer',
      fields: (setDialogState) => Form(
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
            DropdownButtonFormField<String>(
              initialValue: customerType,
              decoration: const InputDecoration(labelText: 'Customer type'),
              items: const [
                DropdownMenuItem(value: 'Domestic', child: Text('Domestic')),
                DropdownMenuItem(
                  value: 'Commercial',
                  child: Text('Commercial'),
                ),
              ],
              onChanged: (value) => setDialogState(() => customerType = value!),
            ),
            const SizedBox(height: 12),
            _field(gstNumber, 'GST number (optional)'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: identityType,
                decoration: const InputDecoration(
                  labelText: 'Identity document (optional)',
                ),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Not provided')),
                  DropdownMenuItem(value: 'PAN', child: Text('PAN')),
                  DropdownMenuItem(value: 'Aadhaar', child: Text('Aadhaar')),
                ],
                onChanged: (value) =>
                    setDialogState(() => identityType = value ?? ''),
              ),
            ),
            _field(identityNumber, 'PAN / Aadhaar number (optional)'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: providerChoice,
                decoration: const InputDecoration(
                  labelText: 'Existing gas service',
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Select service'),
                  ),
                  ...knownProviders.map(
                    (provider) => DropdownMenuItem(
                      value: provider,
                      child: Text(provider),
                    ),
                  ),
                  const DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                validator: (value) => value == null || value.isEmpty
                    ? 'Select the customer\'s existing gas service.'
                    : null,
                onChanged: (value) =>
                    setDialogState(() => providerChoice = value ?? ''),
              ),
            ),
            if (providerChoice == 'Other')
              _field(
                otherProvider,
                'Other gas service',
                validator: (value) =>
                    providerChoice == 'Other' ? _required(value) : null,
              ),
          ],
        ),
      ),
      validate: () {
        final formValid = key.currentState!.validate();
        final hasIdentityType = identityType.isNotEmpty;
        final hasIdentityNumber = identityNumber.text.trim().isNotEmpty;
        if (hasIdentityType != hasIdentityNumber) {
          _message(
            'Enter both the identity type and number, or leave both blank.',
            error: true,
          );
          return false;
        }
        return formValid;
      },
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
              gstNumber: gstNumber.text.trim(),
              identityDocumentType: identityType,
              identityDocumentNumber: identityNumber.text.trim(),
              type: customerType,
              gasProvider: providerChoice == 'Other'
                  ? otherProvider.text.trim()
                  : providerChoice,
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
      gstNumber,
      identityNumber,
      otherProvider,
    ]) {
      controller.dispose();
    }
  }
}
