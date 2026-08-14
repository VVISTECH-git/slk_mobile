import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product.dart';
import '../../models/pos.dart';
import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
import '../../widgets/async_view.dart';
import '../../widgets/picker_field.dart';
import '../pos/pos_providers.dart';
import '../transfers/transfer_providers.dart';
import 'piece_labels_pdf.dart';
import 'piece_providers.dart';

/// Goods-in / labelling: pick a product + location + count, mint that many
/// unique QR codes, then print the tags. This is where physical units enter the
/// serialized system.
// Standard colour list (from the Product Master) — colour lives on the variant.
const _colours = [
  'Red', 'Maroon', 'Rani Pink', 'Pink', 'Peach', 'Orange', 'Rust', 'Mustard',
  'Yellow', 'Gold', 'Cream', 'Off White', 'White', 'Beige', 'Brown', 'Coffee',
  'Green', 'Mehendi', 'Teal', 'Sea Green', 'Blue', 'Sky Blue', 'Navy', 'Indigo', 'Purple',
];

class GoodsInScreen extends ConsumerStatefulWidget {
  const GoodsInScreen({super.key});

  @override
  ConsumerState<GoodsInScreen> createState() => _GoodsInScreenState();
}

class _GoodsInScreenState extends ConsumerState<GoodsInScreen> {
  String? _locationId;
  String? _variantId;
  String? _colour;
  String _query = '';
  final _count = TextEditingController(text: '1');
  bool _busy = false;
  List<String> _codes = [];

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  Future<void> _generate(List<SellableVariant> variants) async {
    final v = variants.where((x) => x.id == _variantId).firstOrNull;
    final count = int.tryParse(_count.text.trim()) ?? 0;
    if (_locationId == null) return showError(context, 'Pick a location.');
    if (v == null) return showError(context, 'Pick a product.');
    if (count <= 0) return showError(context, 'Enter how many pieces.');
    setState(() => _busy = true);
    try {
      final codes = await ref.read(pieceRepositoryProvider).generate(
            variantId: v.id,
            locationId: _locationId!,
            count: count,
            colour: _colour,
          );
      setState(() => _codes = codes);
      if (!mounted) return;
      showOk(context, 'Created ${codes.length} tagged pieces.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(transferLocationsProvider);
    final variantsAsync = ref.watch(goodsInVariantsProvider);

    return Scaffold(
      appBar: AppBar(actions: const [ThemeButton()], title: const Text('Goods-in · label stock')),
      body: AsyncView<List<NamedLocation>>(
        value: locations,
        onRetry: () => ref.invalidate(transferLocationsProvider),
        data: (locs) => variantsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.p.danger))),
          data: (variants) {
            final q = _query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? variants
                : variants
                    .where((v) => v.productName.toLowerCase().contains(q) || v.sku.toLowerCase().contains(q))
                    .toList();
            final selected = variants.where((x) => x.id == _variantId).firstOrNull;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PickerField(
                  label: 'Into location',
                  value: _locationId,
                  options: [for (final l in locs) PickerOption(l.id, l.name)],
                  onChanged: (v) => setState(() => _locationId = v),
                ),
                const SizedBox(height: 16),
                Text('Product', style: TextStyle(fontWeight: FontWeight.w700, color: context.p.text)),
                const SizedBox(height: 6),
                if (selected != null)
                  Card(
                    color: context.p.primary.withValues(alpha: 0.06),
                    child: ListTile(
                      title: Text(selected.productName),
                      subtitle: Text('${selected.sku} · ${selected.variantLabel}'),
                      trailing: TextButton(onPressed: () => setState(() => _variantId = null), child: const Text('Change')),
                    ),
                  )
                else ...[
                  TextField(
                    decoration: const InputDecoration(hintText: 'Search product / SKU', prefixIcon: Icon(Icons.search)),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 8),
                  ...filtered.take(20).map((v) => Card(
                        child: ListTile(
                          dense: true,
                          title: Text(v.productName),
                          subtitle: Text('${v.sku} · ${v.variantLabel}'),
                          onTap: () => setState(() => _variantId = v.id),
                        ),
                      )),
                ],
                const SizedBox(height: 16),
                PickerField(
                  label: 'Colour (optional)',
                  hint: '— No colour —',
                  value: _colour,
                  options: colourOptions(_colours),
                  allowClear: true,
                  onChanged: (v) => setState(() => _colour = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _count,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'How many pieces?', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _generate(variants),
                  icon: const Icon(Icons.qr_code_2),
                  label: Text(_busy ? 'Creating…' : 'Create & tag'),
                ),
                if (_codes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: Text('${_codes.length} pieces tagged: ${_codes.first} … ${_codes.last}',
                          style: TextStyle(color: context.p.textSecondary, fontSize: 13)),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => printPieceLabels(
                        codes: _codes,
                        productName: selected?.productName ?? '',
                        variantLabel: selected?.variantLabel,
                      ),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Print QR tags'),
                    ),
                  ]),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
