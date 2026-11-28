import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/domain/models.dart';
import '../../../core/presentation/common_widgets.dart';
import '../../../core/providers.dart';
import '../../../core/utils/error_messages.dart';

class BookingFormScreen extends ConsumerStatefulWidget {
  const BookingFormScreen({this.orderId, super.key});

  final String? orderId;

  @override
  ConsumerState<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends ConsumerState<BookingFormScreen> {
  static const _uuid = Uuid();
  final _formKey = GlobalKey<FormState>();
  final _customerFormKey = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  final _deliveryCharge = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _notes = TextEditingController();
  final _newCustomerName = TextEditingController();
  final _newCustomerConsumer = TextEditingController();
  final _newCustomerPhone = TextEditingController();
  final _newCustomerAddress = TextEditingController();
  final _newCustomerArea = TextEditingController();
  final _newCustomerGst = TextEditingController();
  final _newCustomerIdentityNumber = TextEditingController();

  String? _customerId;
  String? _productId;
  String _customerType = 'Domestic';
  String _provider = 'HP Gas';
  String _identityType = '';
  bool _showCustomerForm = false;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _deliveryCharge.dispose();
    _discount.dispose();
    _notes.dispose();
    _newCustomerName.dispose();
    _newCustomerConsumer.dispose();
    _newCustomerPhone.dispose();
    _newCustomerAddress.dispose();
    _newCustomerArea.dispose();
    _newCustomerGst.dispose();
    _newCustomerIdentityNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agencyControllerProvider);
    final old = widget.orderId == null
        ? null
        : state.orderList
              .where((item) => item.id == widget.orderId)
              .firstOrNull;
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.orderId != null && old == null) {
      return _MessagePage(
        message: 'Booking not found.',
        onBack: () => context.go('/orders'),
      );
    }
    if (!_initialized) {
      _initialized = true;
      _deliveryCharge.text =
          (old?.deliveryCharge ?? state.settings.deliveryCharge)
              .toStringAsFixed(2);
      if (old != null) {
        _customerId = old.customerId;
        _productId = old.productId;
        _quantity.text = old.quantity.toString();
        _discount.text = old.discount.toStringAsFixed(2);
        _notes.text = old.notes;
      }
    }

    final customers = state.customerList
        .where((customer) => customer.active || customer.id == old?.customerId)
        .toList();
    final products = state.productList
        .where((product) => product.active || product.id == old?.productId)
        .toList();
    final selectedCustomerId = _customerId ?? customers.firstOrNull?.id;
    final selectedProductId = _productId ?? products.firstOrNull?.id;
    final selectedCustomer = customers
        .where((item) => item.id == selectedCustomerId)
        .firstOrNull;
    final selectedProduct = products
        .where((item) => item.id == selectedProductId)
        .firstOrNull;

    final stock = state.inventoryList
        .where((item) => item.productId == selectedProductId)
        .firstOrNull;
    final available =
        (stock?.available ?? 0) +
        (stock != null && old != null && old.productId == selectedProductId
            ? old.quantity
            : 0);

    if (products.isEmpty) {
      return _MessagePage(
        message: 'Add an active gas product before creating a booking.',
        onBack: () => context.go('/settings/products'),
        backLabel: 'Open products',
      );
    }

    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/orders'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to bookings'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    old == null ? 'New booking' : 'Edit ${old.number}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C2A3A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select the customer and gas product, then review the total before saving.',
                    style: TextStyle(color: Color(0xFF68778B)),
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    title: 'Customer',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (customers.isEmpty)
                          const Text('Create a customer to continue.')
                        else
                          DropdownButtonFormField<String>(
                            key: ValueKey(selectedCustomerId),
                            initialValue: selectedCustomerId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Select customer',
                            ),
                            items: customers
                                .map(
                                  (customer) => DropdownMenuItem(
                                    value: customer.id,
                                    child: Text(
                                      '${customer.name} · ${customer.phone} · ${customer.consumerNumber}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(() {
                              _customerId = value;
                              _error = null;
                            }),
                            validator: (value) =>
                                value == null ? 'Select a customer.' : null,
                          ),
                        if (selectedCustomer != null) ...[
                          const SizedBox(height: 12),
                          _CustomerSummary(customer: selectedCustomer),
                        ],
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => setState(
                            () => _showCustomerForm = !_showCustomerForm,
                          ),
                          icon: Icon(
                            _showCustomerForm
                                ? Icons.remove_circle_outline
                                : Icons.person_add_alt_1,
                          ),
                          label: Text(
                            _showCustomerForm
                                ? 'Close new customer'
                                : 'Add customer here',
                          ),
                        ),
                        if (_showCustomerForm) ...[
                          const SizedBox(height: 14),
                          _newCustomerFields(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Cylinder and charges',
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          key: ValueKey(selectedProductId),
                          initialValue: selectedProductId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Gas product',
                          ),
                          items: products
                              .map(
                                (product) => DropdownMenuItem(
                                  value: product.id,
                                  child: Text(
                                    '${product.name} · ${product.type} · ${product.sizeKg} kg · ${money(product.price)}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() {
                            _productId = value;
                            _formKey.currentState?.validate();
                          }),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _quantity,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            helperText:
                                '$available full cylinders available for this booking',
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final quantity = int.tryParse(value ?? '');
                            if (quantity == null || quantity <= 0) {
                              return 'Quantity must be at least one.';
                            }
                            if (quantity > available) {
                              return 'Only $available full cylinders are available.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final fields = [
                              _moneyField(_deliveryCharge, 'Delivery charge'),
                              _moneyField(_discount, 'Discount'),
                            ];
                            if (constraints.maxWidth < 520) {
                              return Column(
                                children: [
                                  fields[0],
                                  const SizedBox(height: 12),
                                  fields[1],
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: fields[0]),
                                const SizedBox(width: 12),
                                Expanded(child: fields[1]),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notes,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Booking notes (optional)',
                          ),
                        ),
                        if (selectedProduct != null) ...[
                          const SizedBox(height: 16),
                          _BookingTotal(
                            product: selectedProduct,
                            quantity: int.tryParse(_quantity.text) ?? 0,
                            charge: _parseAmount(_deliveryCharge.text),
                            discount: _parseAmount(_discount.text),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () => context.canPop()
                                  ? context.pop()
                                  : context.go('/orders'),
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                      FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _saveBooking(
                                state: state,
                                old: old,
                                customerId: selectedCustomerId,
                                product: selectedProduct,
                              ),
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          old == null ? 'Save booking' : 'Save changes',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _newCustomerFields() => Form(
    key: _customerFormKey,
    child: Column(
      children: [
        _requiredField(_newCustomerName, 'Customer name'),
        const SizedBox(height: 12),
        _requiredField(_newCustomerConsumer, 'Consumer number'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _newCustomerPhone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Mobile number'),
          validator: (value) => value == null || value.trim().length < 7
              ? 'Enter a valid phone number.'
              : null,
        ),
        const SizedBox(height: 12),
        _requiredField(_newCustomerAddress, 'Address'),
        const SizedBox(height: 12),
        _requiredField(_newCustomerArea, 'Area / location'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _customerType,
          decoration: const InputDecoration(labelText: 'Customer type'),
          items: const [
            DropdownMenuItem(value: 'Domestic', child: Text('Domestic')),
            DropdownMenuItem(value: 'Commercial', child: Text('Commercial')),
          ],
          onChanged: (value) =>
              setState(() => _customerType = value ?? 'Domestic'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _provider,
          decoration: const InputDecoration(labelText: 'Gas service'),
          items: const [
            DropdownMenuItem(value: 'HP Gas', child: Text('HP Gas')),
            DropdownMenuItem(value: 'Indane', child: Text('Indane')),
            DropdownMenuItem(value: 'Bharatgas', child: Text('Bharatgas')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (value) => setState(() => _provider = value ?? 'HP Gas'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _newCustomerGst,
          decoration: const InputDecoration(labelText: 'GST number (optional)'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _identityType,
          decoration: const InputDecoration(
            labelText: 'Identity document (optional)',
          ),
          items: const [
            DropdownMenuItem(value: '', child: Text('Not provided')),
            DropdownMenuItem(value: 'PAN', child: Text('PAN')),
            DropdownMenuItem(value: 'Aadhaar', child: Text('Aadhaar')),
          ],
          onChanged: (value) => setState(() => _identityType = value ?? ''),
        ),
        if (_identityType.isNotEmpty) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _newCustomerIdentityNumber,
            decoration: InputDecoration(labelText: '$_identityType number'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter the document number or choose Not provided.'
                : null,
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _saving ? null : _saveInlineCustomer,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Save and select customer'),
          ),
        ),
      ],
    ),
  );

  Widget _requiredField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'This field is required.'
            : null,
      );

  Widget _moneyField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: '$label (₹)'),
        onChanged: (_) => setState(() {}),
        validator: (value) {
          final amount = _parseAmount(value ?? '');
          if (value == null ||
              !RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(value.trim())) {
            return 'Enter a valid amount with up to 2 decimals.';
          }
          if (amount < 0) return 'Amount cannot be negative.';
          if (label == 'Discount' &&
              amount >
                  _currentSubtotal() + _parseAmount(_deliveryCharge.text)) {
            return 'Discount exceeds the booking total.';
          }
          return null;
        },
      );

  double _currentSubtotal() {
    final state = ref.read(agencyControllerProvider);
    final product = state.productList
        .where(
          (item) =>
              item.id ==
              (_productId ??
                  state.productList
                      .where((product) => product.active)
                      .firstOrNull
                      ?.id),
        )
        .firstOrNull;
    return (product?.price ?? 0) * (int.tryParse(_quantity.text) ?? 0);
  }

  Future<void> _saveInlineCustomer() async {
    if (!_customerFormKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final customer = Customer(
      id: _uuid.v4(),
      name: _newCustomerName.text.trim(),
      consumerNumber: _newCustomerConsumer.text.trim(),
      phone: _newCustomerPhone.text.trim(),
      address: _newCustomerAddress.text.trim(),
      area: _newCustomerArea.text.trim(),
      gstNumber: _newCustomerGst.text.trim(),
      identityDocumentType: _identityType,
      identityDocumentNumber: _newCustomerIdentityNumber.text.trim(),
      gasProvider: _provider,
      type: _customerType,
      createdAt: DateTime.now(),
    );
    try {
      await ref.read(agencyControllerProvider.notifier).saveCustomer(customer);
      if (!mounted) return;
      setState(() {
        _customerId = customer.id;
        _showCustomerForm = false;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFriendlyError(error);
        _saving = false;
      });
    }
  }

  Future<void> _saveBooking({
    required AgencyState state,
    required AgencyOrder? old,
    required String? customerId,
    required Product? product,
  }) async {
    if (!_formKey.currentState!.validate()) return;
    if (_showCustomerForm) {
      setState(
        () => _error = 'Save the new customer or close that section first.',
      );
      return;
    }
    if (customerId == null || product == null) {
      setState(() => _error = 'Select a customer and gas product.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final order = AgencyOrder(
      id: old?.id ?? _uuid.v4(),
      number: old?.number ?? '',
      customerId: customerId,
      productId: product.id,
      quantity: int.parse(_quantity.text),
      unitPrice: product.price,
      deliveryCharge: _parseAmount(_deliveryCharge.text),
      discount: _parseAmount(_discount.text),
      status: old?.status ?? 'Ready for Delivery',
      createdAt: old?.createdAt ?? DateTime.now(),
      notes: _notes.text.trim(),
    );
    try {
      final controller = ref.read(agencyControllerProvider.notifier);
      if (old == null) {
        await controller.createOrder(order);
      } else {
        await controller.updateOrder(order);
      }
      if (!mounted) return;
      if (old == null) {
        context.go('/orders');
      } else {
        context.go('/orders/${Uri.encodeComponent(old.id)}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(old == null ? 'Booking created.' : 'Booking updated.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFriendlyError(error);
        _saving = false;
      });
    }
  }

  double _parseAmount(String value) => double.tryParse(value.trim()) ?? 0;
}

class _CustomerSummary extends StatelessWidget {
  const _CustomerSummary({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F6F8),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE0E7EB)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          customer.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text('${customer.phone} · Consumer ${customer.consumerNumber}'),
        Text('${customer.gasProvider} · ${customer.address}, ${customer.area}'),
        if (customer.gstNumber.isNotEmpty) Text('GST ${customer.gstNumber}'),
        if (customer.identityDocumentNumber.isNotEmpty)
          Text(
            '${customer.identityDocumentType} ${customer.identityDocumentNumber}',
          ),
      ],
    ),
  );
}

class _BookingTotal extends StatelessWidget {
  const _BookingTotal({
    required this.product,
    required this.quantity,
    required this.charge,
    required this.discount,
  });

  final Product product;
  final int quantity;
  final double charge;
  final double discount;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F7F5),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFD8EAE4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Unit price  ${money(product.price)}'),
        const SizedBox(height: 4),
        Text(
          'Booking total  ${money(product.price * quantity + charge - discount)}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF176B58),
          ),
        ),
      ],
    ),
  );
}

class _MessagePage extends StatelessWidget {
  const _MessagePage({
    required this.message,
    required this.onBack,
    this.backLabel = 'Back to bookings',
  });

  final String message;
  final VoidCallback onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          label: Text(backLabel),
        ),
      ],
    ),
  );
}
