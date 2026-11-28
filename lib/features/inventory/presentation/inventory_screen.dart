part of '../../operations/presentation/operations_screen.dart';

class InventoryScreen extends OperationsScreen {
  const InventoryScreen({super.key}) : super(module: 'Inventory');
}

extension _InventoryWorkflow on _OperationsScreenState {
  void _buildInventoryRows(
    AgencyState state,
    bool Function(String) matches,
    List<_RecordRow> rows,
  ) {
    for (final item in state.inventoryList) {
      final product = _productName(state, item.productId);
      if (!matches(product)) continue;
      rows.add(
        _RecordRow(
          title: product,
          subtitle: '${item.available} available · ${item.booked} booked',
          detail:
              'Full ${item.filled} · Empty ${item.empty} · Damaged ${item.damaged}',
          status: item.available <= item.minimum ? 'Low stock' : 'In stock',
          action: () => _inventoryHistory(state, item),
          menu: const [],
        ),
      );
    }
  }

  Future<void> _inventoryForm(Inventory inventory) async {
    var kind = 'Adjustment';
    final filled = TextEditingController(text: '0');
    final empty = TextEditingController(text: '0');
    final note = TextEditingController();
    final key = GlobalKey<FormState>();
    await _dialogForm(
      title:
          'Adjust ${_productName(ref.read(agencyControllerProvider), inventory.productId)} stock',
      fields: (setDialogState) => Form(
        key: key,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Movement type'),
              items: [
                for (final option in [
                  'Adjustment',
                  'Distributor receipt',
                  'Exchange',
                  'Damage',
                ])
                  DropdownMenuItem(value: option, child: Text(option)),
              ],
              onChanged: (value) => setDialogState(() => kind = value!),
            ),
            const SizedBox(height: 12),
            if (kind == 'Damage')
              const Text(
                'Enter a negative full or empty count to move cylinders to damaged stock.',
              ),
            if (kind == 'Exchange')
              const Text(
                'Enter a negative full count and the same positive empty count.',
              ),
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
            kind: kind,
            damagedChange: kind == 'Damage'
                ? -int.parse(filled.text) - int.parse(empty.text)
                : 0,
          ),
    );
    filled.dispose();
    empty.dispose();
    note.dispose();
  }

  Future<void> _inventoryHistory(AgencyState state, Inventory inventory) async {
    final movements =
        state.movementList
            .where((item) => item.productId == inventory.productId)
            .toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (pageContext) => Scaffold(
          appBar: AppBar(
            title: Text('${_productName(state, inventory.productId)} history'),
          ),
          body: movements.isEmpty
              ? const Center(child: Text('No stock movements recorded yet.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: movements.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final movement = movements[index];
                    String signed(int value) =>
                        value > 0 ? '+$value' : '$value';
                    return Card(
                      child: ListTile(
                        title: Text(
                          movement.kind,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${shortDate(movement.createdAt)}${movement.note.isEmpty ? '' : ' · ${movement.note}'}',
                        ),
                        trailing: Text(
                          'Full ${signed(movement.filledChange)}\nEmpty ${signed(movement.emptyChange)}\nBooked ${signed(movement.bookedChange)}\nDamaged ${signed(movement.damagedChange)}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(pageContext);
                  _inventoryForm(inventory);
                },
                icon: const Icon(Icons.tune),
                label: const Text('Receive or adjust stock'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
