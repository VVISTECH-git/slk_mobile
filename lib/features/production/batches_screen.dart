import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/theme_button.dart';
import 'production_providers.dart';

class BatchesScreen extends ConsumerWidget {
  const BatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(batchesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batches'),
        actions: [
          const ThemeButton(),
          IconButton(onPressed: () => ref.invalidate(batchesProvider), icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newBatch(context, ref),
        backgroundColor: context.p.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New batch'),
      ),
      body: AsyncView<List<dynamic>>(
        value: batches,
        onRetry: () => ref.invalidate(batchesProvider),
        isEmpty: (d) => d.isEmpty,
        emptyMessage: 'No batches yet. Add a raw kora batch to begin.',
        data: (rows) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final b = (rows[i] as Map).cast<String, dynamic>();
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  await context.push('/production/batches/${b['id']}');
                  ref.invalidate(batchesProvider);
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('${b['code']}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          ),
                          Text('${b['total']} pcs', style: TextStyle(color: context.p.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${b['material']}${b['lengthMeters'] != null ? ' · ${b['lengthMeters']} m' : ''}'
                        '${b['supplier'] != null ? ' · ${b['supplier']}' : ''}',
                        style: TextStyle(fontSize: 13, color: context.p.textSecondary),
                      ),
                      if ((b['total'] as num) > 0) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          _chip(context, 'In warehouse', b['inWarehouse'], context.p.success),
                          _chip(context, 'At vendor', b['atVendor'], context.p.accent),
                          if ((b['finished'] as num) > 0) _chip(context, 'Finished', b['finished'], context.p.primary),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, dynamic n, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text('$label: $n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Future<void> _newBatch(BuildContext context, WidgetRef ref) async {
    final material = TextEditingController(text: 'Kora cloth');
    final length = TextEditingController();
    final supplier = TextEditingController();
    final cost = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New batch'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: material, decoration: const InputDecoration(labelText: 'Material')),
              const SizedBox(height: 10),
              TextField(
                controller: length,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Length (metres)'),
              ),
              const SizedBox(height: 10),
              TextField(controller: supplier, decoration: const InputDecoration(labelText: 'Supplier (optional)')),
              const SizedBox(height: 10),
              TextField(
                controller: cost,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cost ₹ (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (created != true) return;
    try {
      await ref.read(productionRepositoryProvider).createBatch(
            material: material.text.trim().isEmpty ? 'Kora cloth' : material.text.trim(),
            lengthMeters: double.tryParse(length.text.trim()),
            supplier: supplier.text.trim(),
            cost: double.tryParse(cost.text.trim()),
          );
      ref.invalidate(batchesProvider);
      if (context.mounted) showOk(context, 'Batch created.');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}
