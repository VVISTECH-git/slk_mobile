import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';

final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/dashboard');
  return (data as Map).cast<String, dynamic>();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(onPressed: () => ref.invalidate(dashboardProvider), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: AsyncView<Map<String, dynamic>>(
        value: dash,
        onRetry: () => ref.invalidate(dashboardProvider),
        data: (d) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _Kpi(label: 'Retail value', value: money0((d['retailValue'] as num?) ?? 0), icon: Icons.savings_outlined, color: context.p.primary),
                _Kpi(label: 'Units in stock', value: '${d['totalUnits'] ?? 0}', icon: Icons.inventory_2_outlined, color: context.p.success),
                _Kpi(label: 'Products', value: '${d['activeCount'] ?? 0}/${d['productCount'] ?? 0} active', icon: Icons.category_outlined, color: context.p.accent),
                _Kpi(label: 'Low stock', value: '${d['lowStockCount'] ?? 0}', icon: Icons.warning_amber_rounded, color: context.p.danger),
              ],
            ),
            const SizedBox(height: 20),
            _Section(title: 'Stock by location', child: _StockByLocation(rows: (d['stockByLocation'] as List?) ?? [])),
            const SizedBox(height: 20),
            if (((d['lowStock'] as List?) ?? []).isNotEmpty) ...[
              _Section(title: 'Low stock alerts', child: _LowStock(rows: (d['lowStock'] as List))),
              const SizedBox(height: 20),
            ],
            _Section(title: 'Recent activity', child: _Recent(rows: (d['recentMovements'] as List?) ?? [])),
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.p.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.p.text)),
              Text(label, style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: child)),
      ],
    );
  }
}

class _StockByLocation extends StatelessWidget {
  const _StockByLocation({required this.rows});
  final List rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return Text('No locations.', style: TextStyle(color: context.p.textSecondary));
    return Column(
      children: rows.map((r) {
        final m = (r as Map);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(m['type'] == 'warehouse' ? Icons.warehouse_outlined : Icons.storefront_outlined,
                    size: 18, color: context.p.textSecondary),
                const SizedBox(width: 8),
                Text('${m['name']}'),
              ]),
              Text('${m['units']} units', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _LowStock extends StatelessWidget {
  const _LowStock({required this.rows});
  final List rows;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows.take(12).map((r) {
        final m = (r as Map);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m['productName']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${m['sku']} · ${m['locationName']}',
                        style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                  ],
                ),
              ),
              Text('${m['onHand']} / ${m['reorder']}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: context.p.danger)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.rows});
  final List rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return Text('No recent activity.', style: TextStyle(color: context.p.textSecondary));
    return Column(
      children: rows.map((r) {
        final m = (r as Map);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m['productName']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${m['type']} · ${m['createdAt']}',
                        style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                  ],
                ),
              ),
              Text('${m['quantity']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
