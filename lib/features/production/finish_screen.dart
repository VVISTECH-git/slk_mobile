import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/picker_field.dart';
import '../../widgets/theme_button.dart';
import 'continuous_scanner.dart';
import 'production_providers.dart';

/// Turn finished in-warehouse pieces into sellable stock: scan the pieces, pick
/// the target product variant, optionally set a cost, and the quantity lands in
/// the warehouse inventory (feeding POS / catalogue).
class FinishScreen extends ConsumerStatefulWidget {
  const FinishScreen({super.key});

  @override
  ConsumerState<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends ConsumerState<FinishScreen> {
  String? _variantId;
  final _tags = <String>{};
  final _cost = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _cost.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => ContinuousScanScreen(title: 'Scan finished pieces', already: _tags)),
    );
    if (result != null) setState(() => _tags..clear()..addAll(result));
  }

  Future<void> _finish() async {
    if (_variantId == null) {
      showError(context, 'Pick the product variant.');
      return;
    }
    if (_tags.isEmpty) {
      showError(context, 'Scan the finished pieces.');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await ref.read(productionRepositoryProvider).finishPieces(
            tagCodes: _tags.toList(),
            variantId: _variantId!,
            unitCost: double.tryParse(_cost.text.trim()),
          );
      final skipped = (res['skipped'] as List? ?? []);
      if (!mounted) return;
      showOk(context, 'Finished ${res['finished']} → ${res['variantSku']} stock at ${res['locationName']}');
      if (skipped.isNotEmpty) {
        setState(() => _tags.clear());
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final variants = ref.watch(finishVariantsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Finish → stock'), actions: const [ThemeButton()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          variants.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e', style: TextStyle(color: context.p.danger)),
            data: (list) => PickerField(
              label: 'Finished as (product / variant)',
              value: _variantId,
              options: [
                for (final v in list)
                  PickerOption((v as Map)['id'] as String, '${v['productName']} · ${v['label']}'),
              ],
              onChanged: (v) => setState(() => _variantId = v),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _cost,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cost per piece ₹ (optional)'),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(_tags.isEmpty ? 'Scan finished pieces' : 'Scan more (${_tags.length})'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          if (_tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('${_tags.length} pieces ready to finish',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _finish,
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Finish ${_tags.length} into stock'),
          ),
        ],
      ),
    );
  }
}
