import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/picker_field.dart';
import '../../widgets/theme_button.dart';
import '../category/category_providers.dart';
import '../products/product_providers.dart';
import 'piece_labels_pdf.dart';
import 'piece_providers.dart';

/// Two-module "create products": pick a Category (design) + colour + quantity →
/// mint that many pieces (each a unique QR item). Price and all details come
/// from the category; a per-colour price override is offered.
const _colours = <String>[
  'Red', 'Maroon', 'Rani Pink', 'Pink', 'Peach', 'Orange', 'Rust', 'Mustard',
  'Yellow', 'Gold', 'Cream', 'Off White', 'White', 'Beige', 'Brown', 'Coffee',
  'Green', 'Mehendi', 'Teal', 'Sea Green', 'Blue', 'Sky Blue', 'Navy', 'Indigo', 'Purple',
];

class TagPiecesScreen extends ConsumerStatefulWidget {
  const TagPiecesScreen({super.key});

  @override
  ConsumerState<TagPiecesScreen> createState() => _TagPiecesScreenState();
}

class _TagPiecesScreenState extends ConsumerState<TagPiecesScreen> {
  String? _categoryId;
  String? _colour;
  String? _locationId;
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController();
  bool _priceTouched = false;
  bool _saving = false;
  Map<String, String> _designColourPrice = {}; // colour(lower) -> price defined on the design
  List<String> _lastCodes = [];
  String _lastDesign = '';
  String _lastColour = '';

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lookups = ref.watch(lookupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tag pieces'), actions: const [ThemeButton()]),
      body: AsyncView<Map<String, dynamic>>(
        value: lookups,
        onRetry: () => ref.invalidate(lookupsProvider),
        data: (l) {
          final cats = (l['categories'] as List?) ?? [];
          final locations = ((l['locations'] as List?) ?? []).cast<Map<String, dynamic>>();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              PickerField(
                label: 'Design *',
                hint: 'Pick a design',
                value: _categoryId,
                options: _categoryOptions(cats),
                onChanged: (v) {
                  setState(() {
                    _categoryId = v;
                    _designColourPrice = {};
                    if (!_priceTouched) _price.text = _defaultRetail(cats) ?? '';
                  });
                  _loadDesignColours(v);
                },
              ),
              const SizedBox(height: 12),
              if (_categoryId != null) _fromCategory(context, cats),
              if (_categoryId != null) const SizedBox(height: 12),
              PickerField(
                label: 'Colour *',
                hint: 'Choose a colour',
                value: _colour,
                options: colourOptions(_colours),
                onChanged: (v) => setState(() {
                  _colour = v;
                  // If this colour has a price defined on the design, use it.
                  if (!_priceTouched && v != null) {
                    final p = _designColourPrice[v.toLowerCase()];
                    if (p != null && p.isNotEmpty) _price.text = p;
                  }
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qty,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Quantity *', hintText: 'How many pieces'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      onChanged: (_) => _priceTouched = true,
                      decoration: const InputDecoration(
                          labelText: 'Price (this colour)', prefixText: '₹ ', helperText: 'Overrides design price'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PickerField(
                label: 'Location *',
                hint: 'Where are these stored',
                value: _locationId,
                options: [
                  for (final loc in locations) PickerOption(loc['id'] as String, '${loc['name']}'),
                ],
                onChanged: (v) => setState(() => _locationId = v),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : () => _tag(cats),
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.qr_code_2),
                label: Text(_saving ? 'Tagging…' : 'Tag pieces'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: context.p.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              if (_lastCodes.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.p.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.p.success.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.check_circle, color: context.p.success, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Tagged ${_lastCodes.length} piece(s)',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text('${_lastCodes.first}${_lastCodes.length > 1 ? '  …  ${_lastCodes.last}' : ''}',
                          style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => printPieceLabels(
                                codes: _lastCodes,
                                productName: _lastDesign,
                                variantLabel: _lastColour,
                              ),
                              icon: const Icon(Icons.print_outlined),
                              label: const Text('Print QR tags'),
                              style: FilledButton.styleFrom(
                                backgroundColor: context.p.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadDesignColours(String? id) async {
    if (id == null) return;
    try {
      final rows = await ref.read(categoryRepositoryProvider).getColours(id);
      if (!mounted) return;
      setState(() {
        _designColourPrice = {
          for (final r in rows)
            '${r['colour']}'.toLowerCase(): (r['b2cPrice']?.toString() ?? ''),
        };
        // If a colour is already chosen, apply its design price.
        if (!_priceTouched && _colour != null) {
          final p = _designColourPrice[_colour!.toLowerCase()];
          if (p != null && p.isNotEmpty) _price.text = p;
        }
      });
    } catch (_) {/* non-fatal — price just falls back to the design default */}
  }

  Map _catById(List cats, String? id) {
    for (final c in cats) {
      if ((c as Map)['id'] == id) return c;
    }
    return const {};
  }

  String? _defaultRetail(List cats) {
    // Walk up parents for the nearest b2cPrice.
    final byId = <String, Map>{for (final c in cats) (c as Map)['id'] as String: c};
    var cur = _categoryId;
    final seen = <String>{};
    while (cur != null && byId.containsKey(cur) && !seen.contains(cur)) {
      seen.add(cur);
      final c = byId[cur]!;
      final v = c['b2cPrice'];
      if (v != null && '$v'.trim().isNotEmpty) return '$v';
      cur = c['parentId'] as String?;
    }
    return null;
  }

  Widget _fromCategory(BuildContext context, List cats) {
    final c = _catById(cats, _categoryId);
    final bits = <String>[
      if ((c['hsnCode'] ?? '') != '') 'HSN ${c['hsnCode']}',
      if ((c['gstRate'] ?? '') != '') 'GST ${c['gstRate']}%',
    ];
    final price = _defaultRetail(cats);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.p.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.p.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: context.p.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [
                if (price != null) 'Design price ₹$price',
                ...bits,
              ].join('  ·  ').isEmpty
                  ? 'Details come from this design.'
                  : [if (price != null) 'Design price ₹$price', ...bits].join('  ·  '),
              style: TextStyle(fontSize: 12, color: context.p.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // Category options as "Parent › Child" paths.
  List<PickerOption> _categoryOptions(List cats) {
    final byId = <String, Map>{for (final c in cats) (c as Map)['id'] as String: c};
    String path(Map c) {
      final parts = <String>[c['name'] as String];
      var pid = c['parentId'] as String?;
      final seen = <String>{};
      while (pid != null && byId.containsKey(pid) && !seen.contains(pid)) {
        seen.add(pid);
        final p = byId[pid]!;
        parts.insert(0, p['name'] as String);
        pid = p['parentId'] as String?;
      }
      return parts.join(' › ');
    }

    final opts = [
      for (final c in cats)
        PickerOption(
          (c as Map)['id'] as String,
          c['name'] as String, // field shows the design name only
          subtitle: path(c), // full path shown inside the dropdown
        )
    ];
    opts.sort((a, b) => (a.subtitle ?? a.label).compareTo(b.subtitle ?? b.label));
    return opts;
  }

  Future<void> _tag(List cats) async {
    final qty = int.tryParse(_qty.text.trim()) ?? 0;
    if (_categoryId == null) return _err('Pick a design.');
    if (_colour == null) return _err('Choose a colour.');
    if (qty <= 0) return _err('Enter a quantity.');
    if (_locationId == null) return _err('Pick a location.');

    setState(() => _saving = true);
    try {
      final codes = await ref.read(pieceRepositoryProvider).tagForCategory(
            categoryId: _categoryId!,
            colour: _colour!,
            count: qty,
            locationId: _locationId!,
            priceOverride: _price.text,
          );
      if (!mounted) return;
      final design = _catById(cats, _categoryId)['name']?.toString() ?? 'Design';
      setState(() {
        _lastCodes = codes;
        _lastDesign = design;
        _lastColour = _colour ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tagged ${codes.length} piece(s). Print the QR tags below.')),
      );
    } catch (e) {
      if (mounted) _err('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: context.p.danger));
  }
}
