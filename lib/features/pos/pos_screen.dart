import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../models/pos.dart';
import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
import '../../widgets/async_view.dart';
import 'barcode_scan_screen.dart';
import 'pos_providers.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String _query = '';

  List<SellableVariant> _filter(List<SellableVariant> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((v) =>
            v.productName.toLowerCase().contains(q) ||
            v.sku.toLowerCase().contains(q) ||
            v.variantLabel.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _scan(List<SellableVariant> all) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (code == null || !mounted) return;
    // Match a scanned barcode/SKU to a sellable variant.
    final match = all.where((v) => v.sku.toLowerCase() == code.toLowerCase()).firstOrNull;
    if (match == null) {
      showError(context, 'No sellable product matches "$code".');
      return;
    }
    ref.read(cartProvider.notifier).add(match);
    showOk(context, 'Added ${match.productName}');
  }

  @override
  Widget build(BuildContext context) {
    final sellable = ref.watch(sellableProvider);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Point of Sale'),
        actions: [
          const ThemeButton(),
          IconButton(
            tooltip: 'Scan sale',
            onPressed: () => context.push('/pieces/sell'),
            icon: const Icon(Icons.qr_code_scanner),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(sellableProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search product or SKU',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 52,
                  child: FilledButton.tonalIcon(
                    onPressed: () => sellable.whenData((all) => _scan(all)).value,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<SellableVariant>>(
              value: sellable,
              onRetry: () => ref.invalidate(sellableProvider),
              isEmpty: (d) => d.isEmpty,
              emptyMessage: 'No priced, in-stock products at this store yet.',
              data: (all) {
                final rows = _filter(all);
                if (rows.isEmpty) {
                  return const Center(child: Text('No products match your search.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ProductRow(variant: rows[i]),
                );
              },
            ),
          ),
        ],
      ),
      bottomSheet: cart.isEmpty ? null : _CartBar(),
    );
  }
}

class _ProductRow extends ConsumerWidget {
  const _ProductRow({required this.variant});
  final SellableVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(cartProvider.select((c) =>
        c.where((l) => l.variant.id == variant.id).firstOrNull?.quantity ?? 0));
    final controller = ref.read(cartProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(variant.productName,
                      style: TextStyle(fontWeight: FontWeight.w600, color: context.p.text)),
                  const SizedBox(height: 2),
                  Text('${variant.sku} · ${variant.variantLabel}',
                      style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(money(variant.price),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700, color: context.p.primaryDark)),
                      ),
                      const SizedBox(width: 8),
                      Text('${variant.stock} in stock',
                          style: TextStyle(
                              fontSize: 12,
                              color: variant.stock <= 3 ? context.p.danger : context.p.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            if (qty == 0)
              FilledButton(
                onPressed: () => controller.add(variant),
                child: const Text('Add'),
              )
            else
              _QtyStepper(
                qty: qty,
                max: variant.stock,
                onDec: () => controller.setQty(variant, qty - 1),
                onInc: () => controller.setQty(variant, qty + 1),
              ),
          ],
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qty, required this.max, required this.onDec, required this.onInc});
  final int qty;
  final int max;
  final VoidCallback onDec;
  final VoidCallback onInc;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.p.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onDec,
            icon: const Icon(Icons.remove, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            onPressed: qty >= max ? null : onInc,
            icon: const Icon(Icons.add, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _CartBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(cartProvider.notifier);
    final units = ref.watch(cartProvider.select((c) => c.fold<int>(0, (s, l) => s + l.quantity)));
    final subtotal = ref.watch(cartProvider.select((c) => c.fold<double>(0, (s, l) => s + l.gross)));

    return Material(
      elevation: 12,
      color: context.p.surface2,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$units item${units == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                    Text(money(subtotal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.p.text)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: controller.clear, child: const Text('Clear')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => context.push('/pos/checkout'),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Checkout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
