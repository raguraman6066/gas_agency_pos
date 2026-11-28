part of '../../operations/presentation/operations_screen.dart';

class StaffScreen extends OperationsScreen {
  const StaffScreen({super.key}) : super(module: 'Staff');
}

extension _StaffWorkflow on _OperationsScreenState {
  void _buildStaffRows(
    AgencyState state,
    bool Function(String) matches,
    List<_RecordRow> rows,
  ) {
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
}
