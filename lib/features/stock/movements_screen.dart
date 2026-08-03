import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/stock.dart';
import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
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
          const ThemeButton(),
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

  ({Color color, IconData icon, String label}) _meta(BuildContext context) {
    switch (m.type) {
      case 'receive':
        return (color: context.p.success, icon: Icons.call_received, label: 'Received');
      case 'sale':
        return (color: context.p.primary, icon: Icons.point_of_sale, label: 'Sale');
      case 'adjust':
        return (color: context.p.accent, icon: Icons.tune, label: 'Adjusted');
      case 'transfer':
      case 'transfer_out':
        return (color: context.p.textSecondary, icon: Icons.local_shipping, label: 'Transfer out');
      case 'transfer_in':
        return (color: context.p.success, icon: Icons.local_shipping_outlined, label: 'Transfer in');
      case 'opening':
        return (color: context.p.textSecondary, icon: Icons.flag_outlined, label: 'Opening');
      default:
        return (color: context.p.textSecondary, icon: Icons.swap_vert, label: m.type);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta(context);
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
                      style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    '${meta.label}${route.isNotEmpty ? ' · $route' : ''}'
                    '${m.reference != null ? ' · ${m.reference}' : ''}',
                    style: TextStyle(fontSize: 12, color: context.p.textSecondary),
                  ),
                  Text('${m.createdAt} · ${m.createdBy}',
                      style: TextStyle(fontSize: 11, color: context.p.textSecondary)),
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
