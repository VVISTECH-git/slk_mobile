import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/stock.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import 'stock_providers.dart';

class MovementsScreen extends ConsumerWidget {
  const MovementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref.watch(movementsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movement history'),
        actions: [
          IconButton(onPressed: () => ref.invalidate(movementsProvider), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: AsyncView<List<MovementRow>>(
        value: movements,
        onRetry: () => ref.invalidate(movementsProvider),
        isEmpty: (d) => d.isEmpty,
        emptyMessage: 'No stock movements recorded yet.',
        data: (rows) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _MovementCard(m: rows[i]),
        ),
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.m});
  final MovementRow m;

  ({Color color, IconData icon, String label}) get _meta {
    switch (m.type) {
      case 'receive':
        return (color: AppColors.success, icon: Icons.call_received, label: 'Received');
      case 'sale':
        return (color: AppColors.terracotta, icon: Icons.point_of_sale, label: 'Sale');
      case 'adjust':
        return (color: AppColors.gold, icon: Icons.tune, label: 'Adjusted');
      case 'transfer':
      case 'transfer_out':
        return (color: AppColors.inkSoft, icon: Icons.local_shipping, label: 'Transfer out');
      case 'transfer_in':
        return (color: AppColors.success, icon: Icons.local_shipping_outlined, label: 'Transfer in');
      case 'opening':
        return (color: AppColors.inkSoft, icon: Icons.flag_outlined, label: 'Opening');
      default:
        return (color: AppColors.inkSoft, icon: Icons.swap_vert, label: m.type);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    final route = [m.fromName, m.toName].where((s) => s != null).join(' → ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(color: meta.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
              child: Icon(meta.icon, size: 20, color: meta.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.productName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${m.sku} · ${m.variantLabel}',
                      style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                  const SizedBox(height: 2),
                  Text(
                    '${meta.label}${route.isNotEmpty ? ' · $route' : ''}'
                    '${m.reference != null ? ' · ${m.reference}' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                  ),
                  Text('${m.createdAt} · ${m.createdBy}',
                      style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                ],
              ),
            ),
            Text('${meta.label == 'Sale' || meta.label == 'Transfer out' ? '−' : '+'}${m.quantity}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: meta.color)),
          ],
        ),
      ),
    );
  }
}
