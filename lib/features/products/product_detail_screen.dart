import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import 'product_providers.dart';

/// Read view of a product: identity, tax, and each variant with its prices and
/// per-location stock. (Editing happens on the web portal / a later form.)
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(productDetailProvider(productId));
    final lookups = ref.watch(lookupsProvider);

    // Map location id → name for the per-variant stock breakdown.
    final locNames = <String, String>{};
    lookups.whenData((l) {
      for (final loc in (l['locations'] as List? ?? [])) {
        final m = (loc as Map).cast<String, dynamic>();
        locNames[m['id'] as String] = m['name'] as String;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await context.push('/products/$productId/edit');
              ref.invalidate(productDetailProvider(productId));
            },
          ),
        ],
      ),
      body: AsyncView<Map<String, dynamic>>(
        value: detail,
        onRetry: () => ref.invalidate(productDetailProvider(productId)),
        data: (p) {
          final variants = (p['variants'] as List? ?? []).cast<dynamic>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((p['name'] ?? '') as String,
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text((p['productCode'] ?? '') as String,
                          style: TextStyle(color: context.p.textSecondary)),
                      if (((p['description'] ?? '') as String).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(p['description'] as String),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _tag(context, 'Status', (p['status'] ?? '') as String),
                          if (((p['hsnCode'] ?? '') as String).isNotEmpty)
                            _tag(context, 'HSN', p['hsnCode'] as String),
                          if (((p['gstRate'] ?? '') as String).isNotEmpty)
                            _tag(context, 'GST', '${p['gstRate']}%'),
                          if (((p['unitType'] ?? '') as String).isNotEmpty)
                            _tag(context, 'Unit', p['unitType'] as String),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Variants (${variants.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              for (final v in variants)
                _VariantCard(v: (v as Map).cast<String, dynamic>(), locNames: locNames),
            ],
          );
        },
      ),
    );
  }

  Widget _tag(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.p.surface1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.p.border),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({required this.v, required this.locNames});
  final Map<String, dynamic> v;
  final Map<String, String> locNames;

  @override
  Widget build(BuildContext context) {
    final label = [v['color'], v['size']].where((s) => (s as String).isNotEmpty).join(' / ');
    final inv = (v['inv'] as Map?)?.cast<String, dynamic>() ?? {};
    int total = 0;
    for (final e in inv.values) {
      total += int.tryParse(((e as Map)['onHand'] ?? '0').toString()) ?? 0;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label.isEmpty ? (v['sku'] as String) : label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text('$total in stock',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: total <= 3 ? context.p.danger : context.p.text)),
              ],
            ),
            Text(v['sku'] as String, style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
            if ((v['images'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final img in (v['images'] as List))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(base64Decode(img as String),
                              height: 72, width: 72, fit: BoxFit.cover, cacheWidth: 200, cacheHeight: 200),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              children: [
                if (((v['b2c'] ?? '') as String).isNotEmpty)
                  _price(context, 'Retail', double.tryParse(v['b2c'] as String)),
                if (((v['cost'] ?? '') as String).isNotEmpty)
                  _price(context, 'Cost', double.tryParse(v['cost'] as String)),
                if (((v['b2b'] ?? '') as String).isNotEmpty)
                  _price(context, 'B2B', double.tryParse(v['b2b'] as String)),
              ],
            ),
            if (inv.isNotEmpty) ...[
              const Divider(height: 18),
              for (final e in inv.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(locNames[e.key] ?? 'Location',
                          style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                      Text('${(e.value as Map)['onHand']}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _price(BuildContext context, String label, double? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: context.p.textSecondary)),
        Text(value == null ? '—' : money0(value),
            style: TextStyle(fontWeight: FontWeight.w700, color: context.p.primaryDark)),
      ],
    );
  }
}
