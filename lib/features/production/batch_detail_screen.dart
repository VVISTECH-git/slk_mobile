import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/theme_button.dart';
import 'production_providers.dart';

class BatchDetailScreen extends ConsumerWidget {
  const BatchDetailScreen({super.key, required this.batchId});
  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(batchDetailProvider(batchId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch'),
        actions: [
          const ThemeButton(),
          IconButton(onPressed: () => ref.invalidate(batchDetailProvider(batchId)), icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _cut(context, ref),
        backgroundColor: context.p.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.content_cut),
        label: const Text('Cut & tag'),
      ),
      body: AsyncView<Map<String, dynamic>>(
        value: detail,
        onRetry: () => ref.invalidate(batchDetailProvider(batchId)),
        data: (b) {
          final sizes = (b['sizes'] as List? ?? []);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${b['code']}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        '${b['material']}${b['lengthMeters'] != null ? ' · ${b['lengthMeters']} m' : ''}',
                        style: TextStyle(color: context.p.textSecondary),
                      ),
                      if (b['supplier'] != null) Text('Supplier: ${b['supplier']}',
                          style: TextStyle(fontSize: 13, color: context.p.textSecondary)),
                      if (b['cost'] != null) Text('Cost: ₹${b['cost']}',
                          style: TextStyle(fontSize: 13, color: context.p.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Pieces by size', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              if (sizes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No pieces cut yet. Use "Cut & tag".',
                        style: TextStyle(color: context.p.textSecondary)),
                  ),
                )
              else
                for (final s in sizes)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(s['size'] == '—' ? '(no size)' : '${s['size']}',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Text('${s['total']} pcs', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 10),
                          Text('WH ${s['inWarehouse']} · Out ${s['atVendor']}',
                              style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _cut(BuildContext context, WidgetRef ref) async {
    final size = TextEditingController();
    final qty = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cut & tag pieces'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: size,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Size', hintText: 'e.g. 2.5m'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity of pieces'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Generate tags')),
        ],
      ),
    );
    if (res != true) return;
    final n = int.tryParse(qty.text.trim()) ?? 0;
    if (n <= 0) {
      if (context.mounted) showError(context, 'Enter a quantity.');
      return;
    }
    try {
      final tags = await ref
          .read(productionRepositoryProvider)
          .cutAndTag(batchId, [(size: size.text.trim(), quantity: n)]);
      ref.invalidate(batchDetailProvider(batchId));
      if (context.mounted) {
        showOk(context, '${tags.length} pieces tagged.');
        _showTags(context, tags);
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  void _showTags(BuildContext context, List<String> tags) {
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
              Text('${tags.length} tag codes generated',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Text('Attach these to the pieces. (PDF label printing comes next.)',
                  style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in tags)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(t, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
