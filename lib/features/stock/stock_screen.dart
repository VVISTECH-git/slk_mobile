import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/product.dart';
import '../../models/stock.dart';
import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
import '../../widgets/async_view.dart';
import '../pos/barcode_scan_screen.dart';
import 'stock_action_sheet.dart';
import 'stock_providers.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  String _query = '';

  Future<void> _openAction(StockVariant v, List<NamedLocation> locs) async {
    final changed = await showStockActionSheet(context, variant: v, locations: locs);
    if (changed == true) ref.invalidate(stockProvider);
  }

  Future<void> _scan(StockData data) async {
    final code = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const BarcodeScanScreen()));
    if (code == null || !mounted) return;
    final match = data.variants.where((v) => v.sku.toLowerCase() == code.toLowerCase()).firstOrNull;
    if (match == null) {
      showError(context, 'No product matches "$code".');
      return;
    }
    _openAction(match, data.locations);
  }

  @override
  Widget build(BuildContext context) {
    final stock = ref.watch(stockProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          const ThemeButton(),
          IconButton(
            tooltip: 'Movement history',
            onPressed: () => context.push('/stock/movements'),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            onPressed: () => ref.invalidate(stockProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AsyncView<StockData>(
        value: stock,
        onRetry: () => ref.invalidate(stockProvider),
        isEmpty: (d) => d.variants.isEmpty,
        emptyMessage: 'No stock records yet.',
        data: (data) {
          final q = _query.trim().toLowerCase();
          final rows = q.isEmpty
              ? data.variants
              : data.variants
                  .where((v) =>
                      v.productName.toLowerCase().contains(q) || v.sku.toLowerCase().contains(q))
                  .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search stock',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 52,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _scan(data),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('No stock matches your search.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _StockRow(v: rows[i], locations: data.locations, onTap: () => _openAction(rows[i], data.locations)),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.v, required this.locations, required this.onTap});
  final StockVariant v;
  final List<NamedLocation> locations;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.productName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${v.sku} · ${v.variantLabel}',
                            style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                      ],
                    ),
                  ),
                  Text('${v.totalStock}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  Icon(Icons.chevron_right, color: context.p.textSecondary),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: locations
                    .map((l) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: context.p.surface1,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.p.border),
                          ),
                          child: Text('${l.name}: ${v.stockByLoc[l.id] ?? 0}',
                              style: TextStyle(fontSize: 11, color: context.p.textSecondary)),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
