part of '../../operations/presentation/operations_screen.dart';

class ProductsScreen extends OperationsScreen {
  const ProductsScreen({super.key}) : super(module: 'Products');
}

extension _ProductsWorkflow on _OperationsScreenState {
  void _buildProductsRows(
    AgencyState state,
    bool Function(String) matches,
    List<_RecordRow> rows,
  ) {
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
}
