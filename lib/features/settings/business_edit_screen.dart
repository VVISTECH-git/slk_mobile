import 'package:flutter/material.dart';
import '../../widgets/theme_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/async_view.dart';
import 'settings_providers.dart';

/// Edit the business profile printed on GST tax invoices.
class BusinessEditScreen extends ConsumerStatefulWidget {
  const BusinessEditScreen({super.key, required this.business});
  final Map<String, dynamic> business;

  @override
  ConsumerState<BusinessEditScreen> createState() => _BusinessEditScreenState();
}

class _BusinessEditScreenState extends ConsumerState<BusinessEditScreen> {
  late final Map<String, TextEditingController> _c;
  bool _busy = false;

  static const _fields = [
    ('legalName', 'Legal name'),
    ('brand', 'Brand'),
    ('gstin', 'GSTIN'),
    ('address', 'Address'),
    ('phone', 'Phone'),
    ('email', 'Email'),
    ('state', 'State'),
    ('stateCode', 'State code'),
    ('invoicePrefix', 'Invoice prefix'),
  ];

  @override
  void initState() {
    super.initState();
    _c = {for (final f in _fields) f.$1: TextEditingController(text: '${widget.business[f.$1] ?? ''}')};
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(settingsRepositoryProvider).saveBusiness(
            {for (final e in _c.entries) e.key: e.value.text.trim()},
          );
      ref.invalidate(settingsProvider);
      if (!mounted) return;
      showOk(context, 'Business profile saved.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: const [ThemeButton()],title: const Text('Business profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final f in _fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _c[f.$1],
                decoration: InputDecoration(labelText: f.$2),
                maxLines: f.$1 == 'address' ? 2 : 1,
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
        ),
      ),
    );
  }
}
