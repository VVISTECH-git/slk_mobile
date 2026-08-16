import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
import '../../widgets/async_view.dart';
import '../../widgets/photo_viewer.dart';
import '../../widgets/picker_field.dart';
import '../settings/settings_providers.dart';
import 'product_providers.dart';

// One captured photo: its base64 data and, optionally, the category shot slot
// it fills (null = an extra/freeform photo).
class _Shot {
  _Shot({this.slotId, required this.data});
  String? slotId;
  String data;
}

// Holds the controllers for one variant row (disposed with the screen).
// Standard pick-lists (colour lives on the variant/colour-group; size optional).
const _variantColours = [
  'Red', 'Maroon', 'Rani Pink', 'Pink', 'Peach', 'Orange', 'Rust', 'Mustard',
  'Yellow', 'Gold', 'Cream', 'Off White', 'White', 'Beige', 'Brown', 'Coffee',
  'Green', 'Mehendi', 'Teal', 'Sea Green', 'Blue', 'Sky Blue', 'Navy', 'Indigo', 'Purple',
];
const _variantSizes = ['Free', 'XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL'];

class _VariantForm {
  String? id; // existing variant id (edit mode) — keeps SKUs stable
  String? sku;
  final color = TextEditingController();
  final size = TextEditingController();
  final barcode = TextEditingController();
  final cost = TextEditingController();
  final b2c = TextEditingController();
  final b2b = TextEditingController();
  final Map<String, TextEditingController> stock = {}; // locationId -> opening qty

  TextEditingController stockFor(String locationId) =>
      stock.putIfAbsent(locationId, () => TextEditingController());

  Map<String, dynamic> toJson(List<Map<String, dynamic>> locations) => {
        if (id != null) 'id': id,
        if (sku != null) 'sku': sku,
        'color': color.text.trim(),
        'size': size.text.trim(),
        'barcode': barcode.text.trim(),
        'cost': cost.text.trim(),
        'b2c': b2c.text.trim(),
        'b2b': b2b.text.trim(),
        'inventory': [
          for (final l in locations)
            {
              'locationId': l['id'],
              'onHand': (stock[l['id']]?.text.trim().isNotEmpty ?? false) ? stock[l['id']]!.text.trim() : '0',
              'reorder': '0',
            }
        ],
      };

  bool get hasContent =>
      color.text.trim().isNotEmpty ||
      size.text.trim().isNotEmpty ||
      b2c.text.trim().isNotEmpty ||
      barcode.text.trim().isNotEmpty;

  void dispose() {
    color.dispose();
    size.dispose();
    barcode.dispose();
    cost.dispose();
    b2c.dispose();
    b2b.dispose();
    for (final c in stock.values) {
      c.dispose();
    }
  }
}

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});
  final String? productId; // null = create, non-null = edit

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _hsn = TextEditingController();
  final _gst = TextEditingController();

  String _status = 'draft';
  String _unitType = 'piece';
  String? _categoryId;
  String? _fabricId, _techniqueId, _dyeId, _borderId;
  bool _showDetails = false;
  bool _busy = false;

  bool get _isEdit => widget.productId != null;
  bool _loadingInitial = false;

  final List<_VariantForm> _variants = [_VariantForm()];

  // Photos grouped per colour key (normalised). Shared across every size of a
  // colour. Each shot may fill a category photo slot.
  final Map<String, List<_Shot>> _photosByColor = {};

  String _ck(String c) => c.trim().toLowerCase();

  // The distinct colours currently entered, in order. `raw` is the colour label
  // to store ("" for none); `label` is what we show.
  List<({String key, String raw, String label})> _colorGroups() {
    final seen = <String>{};
    final out = <({String key, String raw, String label})>[];
    for (final v in _variants) {
      if (!v.hasContent) continue;
      final key = _ck(v.color.text);
      if (seen.add(key)) {
        final raw = v.color.text.trim();
        out.add((key: key, raw: raw, label: raw.isEmpty ? 'No colour' : raw));
      }
    }
    if (out.isEmpty) out.add((key: '', raw: '', label: 'Photos'));
    return out;
  }

  Future<void> _pickForColor(String colorKey, {String? slotId, required ImageSource source}) async {
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 72);
      if (x == null) return;
      final data = base64Encode(await x.readAsBytes());
      setState(() {
        final list = _photosByColor.putIfAbsent(colorKey, () => []);
        if (slotId != null) {
          final idx = list.indexWhere((s) => s.slotId == slotId);
          if (idx >= 0) {
            list[idx].data = data;
          } else {
            list.add(_Shot(slotId: slotId, data: data));
          }
        } else {
          list.add(_Shot(data: data));
        }
      });
    } catch (e) {
      if (mounted) showError(context, 'Could not add photo: $e');
    }
  }

  void _removeShot(String colorKey, _Shot shot) {
    setState(() => _photosByColor[colorKey]?.remove(shot));
  }

  void _addPhotoSheet(String colorKey, {String? slotId}) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () {
              Navigator.pop(context);
              _pickForColor(colorKey, slotId: slotId, source: ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickForColor(colorKey, slotId: slotId, source: ImageSource.gallery);
            },
          ),
        ]),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadingInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadForEdit());
    }
  }

  Future<void> _loadForEdit() async {
    try {
      final p = await ref.read(productDetailProvider(widget.productId!).future);
      _name.text = (p['name'] ?? '') as String;
      _description.text = (p['description'] ?? '') as String;
      _hsn.text = (p['hsnCode'] ?? '') as String;
      _gst.text = (p['gstRate'] ?? '') as String;
      _status = (p['status'] ?? 'draft') as String;
      _unitType = (p['unitType'] ?? 'piece') as String;
      _categoryId = ((p['categoryId'] ?? '') as String).isEmpty ? null : p['categoryId'] as String;
      _fabricId = ((p['fabricId'] ?? '') as String).isEmpty ? null : p['fabricId'] as String;
      _techniqueId = ((p['techniqueId'] ?? '') as String).isEmpty ? null : p['techniqueId'] as String;
      _dyeId = ((p['dyeTypeId'] ?? '') as String).isEmpty ? null : p['dyeTypeId'] as String;
      _borderId = ((p['borderStyleId'] ?? '') as String).isEmpty ? null : p['borderStyleId'] as String;

      for (final v in _variants) {
        v.dispose();
      }
      _variants.clear();
      for (final raw in (p['variants'] as List? ?? [])) {
        final v = (raw as Map).cast<String, dynamic>();
        final vf = _VariantForm()
          ..id = v['id'] as String?
          ..sku = v['sku'] as String?;
        vf.color.text = (v['color'] ?? '') as String;
        vf.size.text = (v['size'] ?? '') as String;
        vf.barcode.text = (v['barcode'] ?? '') as String;
        vf.cost.text = (v['cost'] ?? '') as String;
        vf.b2c.text = (v['b2c'] ?? '') as String;
        vf.b2b.text = (v['b2b'] ?? '') as String;
        final inv = (v['inv'] as Map?)?.cast<String, dynamic>() ?? {};
        inv.forEach((locId, m) {
          vf.stockFor(locId).text = ((m as Map)['onHand'] ?? '0').toString();
        });
        _variants.add(vf);
      }
      if (_variants.isEmpty) _variants.add(_VariantForm());

      // Photos grouped per colour.
      _photosByColor.clear();
      for (final raw in (p['photoGroups'] as List? ?? [])) {
        final g = (raw as Map).cast<String, dynamic>();
        final key = (g['colorKey'] ?? '') as String;
        final shots = <_Shot>[];
        for (final im in (g['images'] as List? ?? [])) {
          final m = (im as Map).cast<String, dynamic>();
          final data = (m['data'] ?? '') as String;
          if (data.isEmpty) continue;
          shots.add(_Shot(slotId: m['slotId'] as String?, data: data));
        }
        _photosByColor[key] = shots;
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _hsn.dispose();
    _gst.dispose();
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  // Build "Parent › Child" paths for the category dropdown.
  List<PickerOption> _categoryOptions(List cats) {
    final byId = {for (final c in cats) c['id'] as String: c as Map};
    String path(Map c) {
      final parts = <String>[];
      Map? cur = c;
      var guard = 0;
      while (cur != null && guard < 6) {
        parts.insert(0, cur['name'] as String);
        final pid = cur['parentId'] as String?;
        cur = pid != null ? byId[pid] : null;
        guard++;
      }
      return parts.join(' › ');
    }

    final items = cats
        .map((c) => (id: c['id'] as String, name: (c as Map)['name'] as String, path: path(c)))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    // Field shows the design name; the full path is a sub-line in the dropdown.
    return [for (final e in items) PickerOption(e.id, e.name, subtitle: e.path)];
  }

  Future<void> _save(List<Map<String, dynamic>> locations) async {
    if (_name.text.trim().isEmpty) {
      showError(context, 'Enter a product name.');
      return;
    }
    if (_categoryId == null) {
      showError(context, 'Pick a design.');
      return;
    }
    final filled = _variants.where((v) => v.hasContent).toList();
    if (filled.isEmpty) {
      showError(context, 'Add at least one colour (with its opening stock or price).');
      return;
    }

    // Photos are per colour. Every colour needs its required shots (or, if the
    // category defines no shot template, at least one photo).
    final slots = _categoryId == null
        ? const <Map<String, dynamic>>[]
        : ((ref.read(categoryPhotoSlotsProvider(_categoryId!)).valueOrNull ?? const [])
            .cast<Map<String, dynamic>>());
    final requiredSlots = slots.where((s) => s['required'] == true).toList();
    final groups = _colorGroups();
    for (final g in groups) {
      final shots = _photosByColor[g.key] ?? const [];
      if (requiredSlots.isNotEmpty) {
        for (final s in requiredSlots) {
          if (!shots.any((sh) => sh.slotId == s['id'])) {
            showError(context, 'Add the “${s['label']}” photo for ${g.label}.');
            return;
          }
        }
      } else if (shots.isEmpty) {
        showError(context, 'Add at least one photo for ${g.label}.');
        return;
      }
    }

    final input = {
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'status': _status,
      'categoryId': _categoryId,
      'fabricId': _fabricId ?? '',
      'techniqueId': _techniqueId ?? '',
      'dyeTypeId': _dyeId ?? '',
      'borderStyleId': _borderId ?? '',
      'unitType': _unitType,
      'lengthMeters': '',
      'blousePieceIncluded': false,
      'hsnCode': _hsn.text.trim(),
      'gstRate': _gst.text.trim(),
      'pushToShopify': false,
      'variants': [for (final v in filled) v.toJson(locations)],
      'colorPhotos': [
        for (final g in groups)
          {
            'color': g.raw,
            'images': [
              for (final sh in (_photosByColor[g.key] ?? const []))
                {'slotId': sh.slotId, 'data': sh.data}
            ],
          }
      ],
    };

    setState(() => _busy = true);
    try {
      final repo = ref.read(productRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.productId!, input);
        ref.invalidate(productsProvider);
        ref.invalidate(productDetailProvider(widget.productId!));
        if (!mounted) return;
        showOk(context, 'Product updated.');
        context.pop();
      } else {
        final id = await repo.create(input);
        ref.invalidate(productsProvider);
        if (!mounted) return;
        showOk(context, 'Product created.');
        if (id.isNotEmpty) {
          context.pushReplacement('/products/$id');
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookups = ref.watch(lookupsProvider);
    if (_loadingInitial) {
      return Scaffold(
        appBar: AppBar(
        actions: const [ThemeButton()],title: const Text('Edit product')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit product' : 'New product')),
      body: AsyncView<Map<String, dynamic>>(
        value: lookups,
        onRetry: () => ref.invalidate(lookupsProvider),
        data: (l) {
          final cats = (l['categories'] as List?) ?? [];
          final locations = ((l['locations'] as List?) ?? []).cast<Map<String, dynamic>>();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _section('Basics'),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Product name *', hintText: 'e.g. Kalamkari Cotton Saree'),
              ),
              const SizedBox(height: 12),
              PickerField(
                label: 'Design *',
                hint: 'Pick a design',
                value: _categoryId,
                options: _categoryOptions(cats),
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PickerField(
                      label: 'Status',
                      value: _status,
                      options: const [
                        PickerOption('draft', 'Draft'),
                        PickerOption('active', 'Active'),
                        PickerOption('inactive', 'Inactive'),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PickerField(
                      label: 'Unit',
                      value: _unitType,
                      options: const [
                        PickerOption('piece', 'Piece'),
                        PickerOption('set', 'Set'),
                        PickerOption('meter', 'Meter'),
                      ],
                      onChanged: (v) => setState(() => _unitType = v ?? 'piece'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _section('Details'),
              _inheritedCard(context, cats, l),
              const SizedBox(height: 12),

              // Optional, product-specific
              _DetailsSection(
                expanded: _showDetails,
                onToggle: () => setState(() => _showDetails = !_showDetails),
                child: TextField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ),
              const SizedBox(height: 20),

              // Colours (each colour = a variant; its opening stock = the quantity)
              Row(
                children: [
                  _section('Colours'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _variants.add(_VariantForm())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add colour'),
                  ),
                ],
              ),
              for (int i = 0; i < _variants.length; i++)
                _VariantCard(
                  index: i,
                  variant: _variants[i],
                  locations: locations,
                  canRemove: _variants.length > 1,
                  onRemove: () => setState(() {
                    _variants.removeAt(i).dispose();
                  }),
                  onChanged: () => setState(() {}),
                ),
              const SizedBox(height: 20),

              // Photos — grouped per colour, guided by the category's shot template.
              _section('Photos by colour'),
              _photosSection(),
            ],
          );
        },
      ),
      bottomNavigationBar: lookups.maybeWhen(
        data: (l) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _busy ? null : () => _save(((l['locations'] as List?) ?? []).cast<Map<String, dynamic>>()),
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEdit ? 'Save changes' : 'Create product'),
            ),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _section(String t) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)));

  Widget _photosSection() {
    if (_categoryId == null) {
      return Text('Pick a design first to add photos.',
          style: TextStyle(fontSize: 13, color: context.p.textSecondary));
    }
    final slotsAsync = ref.watch(categoryPhotoSlotsProvider(_categoryId!));
    final slots = (slotsAsync.valueOrNull ?? const []).cast<Map<String, dynamic>>();
    final groups = _colorGroups();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            slots.isEmpty
                ? 'Photos are shared across all sizes of a colour. Tip: set a photo guide for this design in Settings to prompt specific shots.'
                : 'Photos are shared across all sizes of a colour. Tap each labelled shot to capture it.',
            style: TextStyle(fontSize: 12, color: context.p.textSecondary, height: 1.35),
          ),
        ),
        for (final g in groups)
          _ColorPhotoBlock(
            key: ValueKey('photos_${g.key}'),
            label: g.label,
            shots: _photosByColor[g.key] ?? const [],
            slots: slots,
            onAdd: ({String? slotId}) => _addPhotoSheet(g.key, slotId: slotId),
            onRemove: (shot) => _removeShot(g.key, shot),
          ),
      ],
    );
  }

  // Effective template attrs for the selected category, resolved by walking up
  // the parent chain (nearest ancestor that sets a value wins). Mirrors the
  // server's inheritance so the form previews exactly what will be saved.
  Map<String, String?> _effectiveCatAttrs(List cats) {
    final byId = <String, Map>{for (final c in cats) (c as Map)['id'] as String: c};
    String? pick(String key) {
      var cur = _categoryId;
      final seen = <String>{};
      while (cur != null && byId.containsKey(cur) && !seen.contains(cur)) {
        seen.add(cur);
        final c = byId[cur]!;
        final v = c[key];
        if (v != null && '$v'.trim().isNotEmpty) return '$v';
        cur = c['parentId'] as String?;
      }
      return null;
    }

    return {
      'fabricId': pick('fabricId'),
      'techniqueId': pick('techniqueId'),
      'dyeTypeId': pick('dyeTypeId'),
      'borderStyleId': pick('borderStyleId'),
      'hsnCode': pick('hsnCode'),
      'gstRate': pick('gstRate'),
    };
  }

  String _nameFor(dynamic rows, String? id) {
    if (id == null) return '—';
    for (final r in (rows as List? ?? [])) {
      if ((r as Map)['id'] == id) return '${r['name']}';
    }
    return '—';
  }

  Widget _inheritedCard(BuildContext context, List cats, Map l) {
    final box = BoxDecoration(
      color: context.p.surface2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.p.border),
    );
    if (_categoryId == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: box,
        child: Text('Pick a design — fabric, technique, HSN and GST come from it.',
            style: TextStyle(color: context.p.textMuted)),
      );
    }
    final a = _effectiveCatAttrs(cats);
    final rows = <List<String>>[
      ['Fabric', _nameFor(l['fabrics'], a['fabricId'])],
      ['Technique', _nameFor(l['techniques'], a['techniqueId'])],
      ['Dye type', _nameFor(l['dyeTypes'], a['dyeTypeId'])],
      ['Border style', _nameFor(l['borderStyles'], a['borderStyleId'])],
      ['HSN code', a['hsnCode'] ?? '—'],
      ['GST %', a['gstRate'] != null ? '${a['gstRate']}%' : '—'],
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: box,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.category_outlined, size: 16, color: context.p.textSecondary),
            const SizedBox(width: 6),
            Text('From design',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.p.textSecondary)),
          ]),
          const SizedBox(height: 10),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r[0], style: TextStyle(color: context.p.textSecondary)),
                  Flexible(
                      child: Text(r[1],
                          textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.expanded, required this.onToggle, required this.child});
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(expanded ? Icons.expand_less : Icons.expand_more, color: context.p.textSecondary),
              const SizedBox(width: 6),
              Text('More details (optional)', style: TextStyle(color: context.p.textSecondary, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        if (expanded) child,
      ],
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.index,
    required this.variant,
    required this.locations,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });
  final int index;
  final _VariantForm variant;
  final List<Map<String, dynamic>> locations;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged; // called when the colour changes (refreshes the photo section)

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Colour ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (canRemove)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onRemove,
                    icon: Icon(Icons.delete_outline, color: context.p.danger),
                  ),
              ],
            ),
            Row(children: [
              Expanded(
                child: PickerField(
                  label: 'Colour',
                  value: _variantColours.contains(variant.color.text.trim()) ? variant.color.text.trim() : null,
                  options: colourOptions(_variantColours),
                  allowClear: true,
                  onChanged: (v) {
                    variant.color.text = v ?? '';
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PickerField(
                  label: 'Size',
                  value: _variantSizes.contains(variant.size.text.trim()) ? variant.size.text.trim() : null,
                  options: plainOptions(_variantSizes),
                  allowClear: true,
                  onChanged: (v) {
                    variant.size.text = v ?? '';
                    onChanged();
                  },
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(controller: variant.barcode, decoration: const InputDecoration(labelText: 'Barcode')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _price(variant.cost, 'Cost')),
              const SizedBox(width: 8),
              Expanded(child: _price(variant.b2c, 'Retail (MRP)')),
              const SizedBox(width: 8),
              Expanded(child: _price(variant.b2b, 'B2B')),
            ]),
            const Divider(height: 22),
            Text('Opening stock', style: TextStyle(fontSize: 12, color: context.p.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (final loc in locations)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text('${loc['name']}', style: const TextStyle(fontSize: 13))),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: variant.stockFor(loc['id'] as String),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(hintText: '0', isDense: true),
                    ),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _price(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixText: '₹'),
      );
}

// Photos for one colour: labelled shot slots (with reference guides) when the
// category defines a template, otherwise a simple photo grid. Photos are shared
// across every size of this colour.
class _ColorPhotoBlock extends StatelessWidget {
  const _ColorPhotoBlock({
    super.key,
    required this.label,
    required this.shots,
    required this.slots,
    required this.onAdd,
    required this.onRemove,
  });
  final String label;
  final List<_Shot> shots;
  final List<Map<String, dynamic>> slots;
  final void Function({String? slotId}) onAdd;
  final void Function(_Shot shot) onRemove;

  @override
  Widget build(BuildContext context) {
    final slotIds = slots.map((s) => s['id'] as String).toSet();
    final extras = shots.where((s) => s.slotId == null || !slotIds.contains(s.slotId)).toList();
    _Shot? shotFor(String slotId) {
      for (final s in shots) {
        if (s.slotId == slotId) return s;
      }
      return null;
    }

    // All captured photos for this colour, in display order (slots first, then
    // extras) — used by the full-screen viewer so any tapped photo can swipe.
    final ordered = <_Shot>[
      for (final s in slots)
        if (shotFor(s['id'] as String) != null) shotFor(s['id'] as String)!,
      ...extras,
    ];
    VoidCallback? viewer(_Shot? shot) {
      if (shot == null) return null;
      final index = ordered.indexOf(shot);
      if (index < 0) return null;
      return () => openPhotoViewer(
            context,
            images: [for (final s in ordered) s.data],
            initialIndex: index,
            title: label,
          );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.palette_outlined, size: 16, color: context.p.primary),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (slots.isNotEmpty)
                  for (final s in slots)
                    _SlotTile(
                      label: s['label'] as String,
                      required: s['required'] == true,
                      guide: s['guide'] as String?,
                      shot: shotFor(s['id'] as String),
                      onTap: () => onAdd(slotId: s['id'] as String),
                      onView: viewer(shotFor(s['id'] as String)),
                      onRemove: () {
                        final sh = shotFor(s['id'] as String);
                        if (sh != null) onRemove(sh);
                      },
                    ),
                for (final e in extras)
                  _SlotTile(
                    label: slots.isNotEmpty ? 'Extra' : '',
                    required: false,
                    guide: null,
                    shot: e,
                    onTap: () {},
                    onView: viewer(e),
                    onRemove: () => onRemove(e),
                  ),
                if (slots.isNotEmpty || extras.length < 8)
                  _AddTile(label: slots.isNotEmpty ? 'Extra' : 'Add', onTap: () => onAdd()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.label,
    required this.required,
    required this.guide,
    required this.shot,
    required this.onTap,
    required this.onRemove,
    this.onView,
  });
  final String label;
  final bool required;
  final String? guide;
  final _Shot? shot;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback? onView; // tap a captured photo to open it full-screen

  static const double _size = 108;

  void _previewGuide(BuildContext context) {
    if (guide == null || guide!.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(children: [
                Expanded(
                  child: Text(label.isEmpty ? 'Reference' : label,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.memory(base64Decode(guide!), fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Frame your photo to match this reference.',
                  style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filled = shot != null;
    final hasGuide = guide != null && guide!.isNotEmpty;
    return SizedBox(
      width: _size,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                onTap: filled ? onView : onTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: _size,
                  width: _size,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: required && !filled ? context.p.primary : context.p.border,
                      width: required && !filled ? 1.5 : 1,
                    ),
                    color: context.p.surface1,
                  ),
                  child: filled
                      ? Image.memory(base64Decode(shot!.data),
                          fit: BoxFit.cover, cacheWidth: 260, cacheHeight: 260)
                      : (hasGuide
                          // Empty slot with a reference: show the guide clearly so
                          // staff know the exact framing, with a capture hint.
                          ? Stack(fit: StackFit.expand, children: [
                              Image.memory(base64Decode(guide!), fit: BoxFit.cover, cacheWidth: 260, cacheHeight: 260),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.photo_camera, size: 14, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('Tap to shoot', style: TextStyle(fontSize: 10.5, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ])
                          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.add_a_photo_outlined, color: context.p.primary),
                              const SizedBox(height: 2),
                              Text('Add', style: TextStyle(fontSize: 11, color: context.p.textSecondary)),
                            ])),
                ),
              ),
              // Enlarge the reference for exact framing.
              if (hasGuide && !filled)
                Positioned(
                  top: 4,
                  left: 4,
                  child: GestureDetector(
                    onTap: () => _previewGuide(context),
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black.withValues(alpha: 0.55),
                      child: const Icon(Icons.zoom_in, size: 15, color: Colors.white),
                    ),
                  ),
                ),
              if (filled)
                Positioned(
                  top: -8,
                  right: -8,
                  child: IconButton(
                    icon: CircleAvatar(
                      radius: 11,
                      backgroundColor: context.p.danger,
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                    onPressed: onRemove,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 28,
            child: Text(
              label.isEmpty ? '' : (label + (required ? ' *' : '')),
              style: TextStyle(fontSize: 11, color: required ? context.p.primary : context.p.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 108,
              width: 108,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.p.border),
                color: context.p.surface1,
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add, color: context.p.primary),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 11, color: context.p.textSecondary)),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
