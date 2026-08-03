import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import 'product_providers.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(productsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/products/new');
          ref.invalidate(productsProvider);
        },
        backgroundColor: context.p.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New product'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search products',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: AsyncView<ProductsList>(
              value: products,
              onRetry: () => ref.invalidate(productsProvider),
              isEmpty: (d) => d.rows.isEmpty,
              emptyMessage: 'No products yet.',
              data: (list) {
                final q = _query.trim().toLowerCase();
                final rows = q.isEmpty
                    ? list.rows
                    : list.rows
                        .where((r) =>
                            r.name.toLowerCase().contains(q) ||
                            r.productCode.toLowerCase().contains(q) ||
                            r.categoryPath.toLowerCase().contains(q))
                        .toList();
                if (rows.isEmpty) {
                  return const Center(child: Text('No products match your search.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ProductCard(row: rows[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.row});
  final ProductListRow row;

  String get _price {
    if (row.minPrice == null) return 'No price';
    if (row.maxPrice == null || row.minPrice == row.maxPrice) return money0(row.minPrice!);
    return '${money0(row.minPrice!)} – ${money0(row.maxPrice!)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/products/${row.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(row.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  _StatusChip(status: row.status),
                ],
              ),
              const SizedBox(height: 2),
              Text('${row.productCode}${row.categoryPath.isNotEmpty ? ' · ${row.categoryPath}' : ''}',
                  style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Pill(icon: Icons.sell_outlined, text: _price),
                  const SizedBox(width: 8),
                  _Pill(icon: Icons.style_outlined, text: '${row.variantCount} variant${row.variantCount == 1 ? '' : 's'}'),
                  const Spacer(),
                  if (row.lowStock)
                    Icon(Icons.warning_amber_rounded, color: context.p.danger, size: 18),
                  const SizedBox(width: 4),
                  Text('${row.totalStock} in stock',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: row.lowStock ? context.p.danger : context.p.text)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = status == 'active'
        ? context.p.success
        : status == 'draft'
            ? context.p.accent
            : context.p.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Text(status[0].toUpperCase() + status.substring(1),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: context.p.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
      ],
    );
  }
}
