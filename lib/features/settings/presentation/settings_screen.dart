import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/domain/models.dart';
import '../../../core/utils/error_messages.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agencyControllerProvider);
    if (state.currentRole != 'Admin') {
      return const Center(
        child: Text('Settings are available to administrators.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.business_outlined),
                title: const Text('Agency details'),
                subtitle: Text(state.settings.name),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editDetails(context, ref, state.settings),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.propane_tank_outlined),
                title: const Text('Cylinder catalog'),
                subtitle: const Text('Manage cylinder types, sizes and prices'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/settings/products'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Staff accounts'),
                subtitle: const Text('Manage profiles and delivery staff'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/settings/staff'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editDetails(
    BuildContext context,
    WidgetRef ref,
    AgencySettings settings,
  ) async {
    final name = TextEditingController(text: settings.name);
    final details = TextEditingController(text: settings.details);
    final deliveryCharge = TextEditingController(
      text: settings.deliveryCharge.toStringAsFixed(2),
    );
    final methods = settings.paymentMethods.toSet();
    final controller = ref.read(agencyControllerProvider.notifier);
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: const Text('Agency details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Agency name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: details,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Address and contact details',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: deliveryCharge,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Default delivery charge',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Payment methods'),
                  ),
                  for (final method in AgencySettings.supportedPaymentMethods)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(method),
                      value: methods.contains(method),
                      onChanged: saving
                          ? null
                          : (enabled) => setState(() {
                              if (enabled == true) {
                                methods.add(method);
                              } else {
                                methods.remove(method);
                              }
                            }),
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (name.text.trim().isEmpty) {
                          setState(() => error = 'Enter the agency name.');
                          return;
                        }
                        final charge = deliveryCharge.text.trim();
                        if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$')
                                .hasMatch(charge) ||
                            methods.isEmpty) {
                          setState(
                            () => error = 'Enter a valid charge and enable at least one payment method.',
                          );
                          return;
                        }
                        setState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await controller.saveSettings(
                            AgencySettings(
                              name: name.text.trim(),
                              details: details.text.trim(),
                              deliveryCharge: double.parse(charge),
                              paymentMethods: AgencySettings
                                  .supportedPaymentMethods
                                  .where(methods.contains)
                                  .toList(),
                            ),
                          );
                          if (context.mounted) Navigator.pop(context);
                        } catch (exception) {
                          if (context.mounted) {
                            setState(() {
                              saving = false;
                              error = userFriendlyError(exception);
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
    name.dispose();
    details.dispose();
    deliveryCharge.dispose();
  }
}
