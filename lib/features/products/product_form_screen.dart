import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import 'product_providers.dart';

// Holds the controllers for one variant row (disposed with the screen).
class _VariantForm {
  String? id; // existing variant id (edit mode) — keeps SKUs stable
  String? sku;
  final color = TextEditingController();
  final size = TextEditingController();
  final barcode = TextEditingController();
  final cost = TextEditingController();
  final b2c = TextEditingController();
  final b2b = TextEditingController();
  final List<String> images = []; // base64 JPEG, up to 5
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
        'images': images,
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
        vf.images.addAll(((v['images'] as List?) ?? []).cast<String>());
        final inv = (v['inv'] as Map?)?.cast<String, dynamic>() ?? {};
        inv.forEach((locId, m) {
          vf.stockFor(locId).text = ((m as Map)['onHand'] ?? '0').toString();
        });
        _variants.add(vf);
      }
      if (_variants.isEmpty) _variants.add(_VariantForm());
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
  List<DropdownMenuItem<String>> _categoryItems(List cats) {
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

    final items = cats.map((c) => (id: c['id'] as String, label: path(c as Map))).toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return items.map((e) => DropdownMenuItem(value: e.id, child: Text(e.label))).toList();
  }

  Future<void> _save(List<Map<String, dynamic>> locations) async {
    if (_name.text.trim().isEmpty) {
      showError(context, 'Enter a product name.');
      return;
    }
    if (_categoryId == null) {
      showError(context, 'Pick a category.');
      return;
    }
    final filled = _variants.where((v) => v.hasContent).toList();
    if (filled.isEmpty) {
      showError(context, 'Add at least one variant (colour/size or price).');
      return;
    }
    if (filled.any((v) => v.images.isEmpty)) {
      showError(context, 'Add at least one photo to every variant.');
      return;
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
        appBar: AppBar(title: const Text('Edit product')),
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
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category *', hintText: 'Pick a category'),
                items: _categoryItems(cats),
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                        DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unitType,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: const [
                        DropdownMenuItem(value: 'piece', child: Text('Piece')),
                        DropdownMenuItem(value: 'set', child: Text('Set')),
                        DropdownMenuItem(value: 'meter', child: Text('Meter')),
                      ],
                      onChanged: (v) => setState(() => _unitType = v ?? 'piece'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _section('Tax'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hsn,
                      decoration: const InputDecoration(labelText: 'HSN code'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _gst,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'GST %'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Optional attributes
              _DetailsSection(
                expanded: _showDetails,
                onToggle: () => setState(() => _showDetails = !_showDetails),
                child: Column(
                  children: [
                    TextField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                    const SizedBox(height: 12),
                    _attrDropdown('Fabric', l['fabrics'], _fabricId, (v) => setState(() => _fabricId = v)),
                    const SizedBox(height: 12),
                    _attrDropdown('Technique', l['techniques'], _techniqueId, (v) => setState(() => _techniqueId = v)),
                    const SizedBox(height: 12),
                    _attrDropdown('Dye type', l['dyeTypes'], _dyeId, (v) => setState(() => _dyeId = v)),
                    const SizedBox(height: 12),
                    _attrDropdown('Border style', l['borderStyles'], _borderId, (v) => setState(() => _borderId = v)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Variants
              Row(
                children: [
                  _section('Variants'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _variants.add(_VariantForm())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
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

  Widget _attrDropdown(String label, dynamic rows, String? value, ValueChanged<String?> onChanged) {
    final list = (rows as List?) ?? [];
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: null, child: Text('—')),
        ...list.map((r) => DropdownMenuItem(value: (r as Map)['id'] as String, child: Text('${r['name']}'))),
      ],
      onChanged: onChanged,
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
              Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.inkSoft),
              const SizedBox(width: 6),
              const Text('More details (optional)', style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
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
  final VoidCallback onChanged;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 72,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      variant.images.add(base64Encode(bytes));
      onChanged();
    } catch (e) {
      if (context.mounted) showError(context, 'Could not add photo: $e');
    }
  }

  void _addPhoto(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () {
              Navigator.pop(context);
              _pick(context, ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.pop(context);
              _pick(context, ImageSource.gallery);
            },
          ),
        ]),
      ),
    );
  }

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
                Text('Variant ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (canRemove)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  ),
              ],
            ),
            // ---- Photos (required: 1–5) ----
            Row(children: [
              const Text('Photos *', style: TextStyle(fontSize: 12, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text('${variant.images.length}/5', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            ]),
            const SizedBox(height: 6),
            SizedBox(
              height: 84,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (int j = 0; j < variant.images.length; j++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(base64Decode(variant.images[j]), height: 84, width: 84, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: IconButton(
                              icon: const CircleAvatar(radius: 11, backgroundColor: AppColors.danger, child: Icon(Icons.close, size: 14, color: Colors.white)),
                              onPressed: () {
                                variant.images.removeAt(j);
                                onChanged();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (variant.images.length < 5)
                    InkWell(
                      onTap: () => _addPhoto(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 84,
                        width: 84,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                          color: AppColors.cream,
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, color: AppColors.terracotta),
                            SizedBox(height: 2),
                            Text('Add', style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: variant.color, decoration: const InputDecoration(labelText: 'Colour'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: variant.size, decoration: const InputDecoration(labelText: 'Size'))),
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
            const Text('Opening stock', style: TextStyle(fontSize: 12, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
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
