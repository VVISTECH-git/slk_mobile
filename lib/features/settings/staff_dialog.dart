import 'package:flutter/material.dart';

import '../../widgets/picker_field.dart';

/// Result of the staff add/edit dialog.
class StaffFormResult {
  const StaffFormResult({required this.name, required this.role, this.storeId, this.pin});
  final String name;
  final String role; // owner | cashier
  final String? storeId;
  final String? pin; // required on create; optional (change) on edit
}

/// Add or edit a staff member. Pass [existing] to edit.
Future<StaffFormResult?> showStaffDialog(
  BuildContext context, {
  required List<dynamic> stores,
  Map<String, dynamic>? existing,
}) {
  final isEdit = existing != null;
  final nameC = TextEditingController(text: existing?['name']?.toString() ?? '');
  final pinC = TextEditingController();
  String role = (existing?['role'] as String?) ?? 'cashier';
  String? storeId = existing?['storeId'] as String?;

  return showDialog<StaffFormResult>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(isEdit ? 'Edit staff' : 'New staff'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              PickerField(
                label: 'Role',
                value: role,
                options: const [
                  PickerOption('cashier', 'Cashier'),
                  PickerOption('owner', 'Owner'),
                ],
                onChanged: (v) => setState(() => role = v ?? 'cashier'),
              ),
              const SizedBox(height: 12),
              PickerField(
                label: 'Store (cashiers)',
                hint: 'No fixed store',
                value: storeId,
                allowClear: true,
                options: [
                  for (final s in stores) PickerOption((s as Map)['id'] as String, '${s['name']}'),
                ],
                onChanged: (v) => setState(() => storeId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinC,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: isEdit ? 'New PIN (leave blank to keep)' : '4-digit PIN',
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameC.text.trim();
              if (name.isEmpty) return;
              final pin = pinC.text.trim();
              if (!isEdit && pin.length != 4) return; // create requires a PIN
              Navigator.pop(
                context,
                StaffFormResult(name: name, role: role, storeId: storeId, pin: pin.isEmpty ? null : pin),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
