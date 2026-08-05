import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/theme_button.dart';
import 'continuous_scanner.dart';
import 'production_providers.dart';

class DispatchScreen extends ConsumerStatefulWidget {
  const DispatchScreen({super.key});

  @override
  ConsumerState<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends ConsumerState<DispatchScreen> {
  String? _vendorId;
  String? _stageId;
  final _tags = <String>{};
  bool _busy = false;

  Future<void> _scan() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => ContinuousScanScreen(title: 'Scan to dispatch', already: _tags),
      ),
    );
    if (result != null) setState(() => _tags..clear()..addAll(result));
  }

  Future<void> _dispatch() async {
    if (_vendorId == null || _stageId == null) {
      showError(context, 'Pick a vendor and a stage.');
      return;
    }
    if (_tags.isEmpty) {
      showError(context, 'Scan at least one piece.');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await ref.read(productionRepositoryProvider).dispatch(
            vendorId: _vendorId!,
            stageId: _stageId!,
            tagCodes: _tags.toList(),
          );
      final skipped = (res['skipped'] as List? ?? []);
      if (!mounted) return;
      showOk(context, 'Dispatched ${res['count']} pieces · ${res['challanNo']}');
      if (skipped.isNotEmpty) {
        _showSkipped(skipped);
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

  void _showSkipped(List skipped) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${skipped.length} not dispatched',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.p.danger)),
              const SizedBox(height: 8),
              for (final s in skipped)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('${(s as Map)['tag']} — ${s['reason']}', style: const TextStyle(fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(prodVendorsProvider);
    final stages = ref.watch(prodStagesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Send to vendor'), actions: const [ThemeButton()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          vendors.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e', style: TextStyle(color: context.p.danger)),
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _vendorId,
              decoration: const InputDecoration(labelText: 'Vendor', hintText: 'Pick a vendor'),
              items: [
                for (final v in list)
                  DropdownMenuItem(value: (v as Map)['id'] as String, child: Text('${v['name']}')),
              ],
              onChanged: (v) => setState(() => _vendorId = v),
            ),
          ),
          const SizedBox(height: 14),
          stages.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e', style: TextStyle(color: context.p.danger)),
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _stageId,
              decoration: const InputDecoration(labelText: 'Stage', hintText: 'Pick a stage'),
              items: [
                for (final s in list)
                  DropdownMenuItem(value: (s as Map)['id'] as String, child: Text('${s['name']}')),
              ],
              onChanged: (v) => setState(() => _stageId = v),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(_tags.isEmpty ? 'Scan pieces' : 'Scan more (${_tags.length})'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          const SizedBox(height: 12),
          if (_tags.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.p.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.p.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('${_tags.length} pieces scanned',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton(onPressed: () => setState(_tags.clear), child: const Text('Clear')),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in _tags.take(40))
                        Chip(
                          label: Text(t, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      if (_tags.length > 40) Text('+${_tags.length - 40} more'),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _dispatch,
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Dispatch ${_tags.length} pieces'),
          ),
        ],
      ),
    );
  }
}
