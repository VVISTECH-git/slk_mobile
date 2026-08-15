import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/picker_field.dart';
import '../auth/auth_controller.dart';
import 'category_providers.dart';

// Mirror of the server's deriveCode() so the SKU prefix preview matches what the
// backend will store for a brand-new category.
const _preferredCodes = <String, String>{
  'Sarees': 'SAR',
  'Silk Sarees': 'SLK',
  'Cotton Sarees': 'CTN',
  'Kalamkari Sarees': 'KLM',
  'Dress Material': 'DRM',
  'Kurtas': 'KUR',
  'Dupattas': 'DUP',
  'Home Furnishing': 'HOM',
  'Bedsheets': 'BED',
};

String _deriveCode(String name) {
  final key = name.trim();
  final preferred = _preferredCodes[key];
  if (preferred != null) return preferred;
  final cleaned = key.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (cleaned.isEmpty) return 'GEN';
  return cleaned.substring(0, cleaned.length < 3 ? cleaned.length : 3).toUpperCase();
}

const _units = ['piece', 'set', 'meter'];

class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({super.key, this.categoryId, this.initialParentId});

  /// Null → create; non-null → edit.
  final String? categoryId;

  /// For create: the parent (sub-)category to pre-select (e.g. drilled-into sub).
  final String? initialParentId;

  bool get isEdit => categoryId != null;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _codeEdited = false; // once the user edits the code, stop auto-suggesting
  final _hsn = TextEditingController();
  final _gst = TextEditingController();
  final _cost = TextEditingController();
  final _retail = TextEditingController();
  final _b2b = TextEditingController();

  String? _parentId;
  String? _fabricId;
  String? _techniqueId;
  String? _dyeTypeId;
  String? _borderStyleId;
  String _unit = 'piece';
  bool _active = true;

  bool _initialized = false;
  bool _parentDefaulted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {})); // live code preview
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _hsn.dispose();
    _gst.dispose();
    _cost.dispose();
    _retail.dispose();
    _b2b.dispose();
    super.dispose();
  }

  // Seed controllers from the existing row once, in edit mode.
  void _seed(CategoryRow row) {
    if (_initialized) return;
    _name.text = row.name;
    _code.text = row.code ?? '';
    _hsn.text = row.hsnCode ?? '';
    _gst.text = _trimNum(row.gstRate);
    _cost.text = _trimNum(row.costPrice);
    _retail.text = _trimNum(row.b2cPrice);
    _b2b.text = _trimNum(row.b2bPrice);
    _parentId = row.parentId;
    _fabricId = row.fabricId;
    _techniqueId = row.techniqueId;
    _dyeTypeId = row.dyeTypeId;
    _borderStyleId = row.borderStyleId;
    _unit = _units.contains(row.unitType) ? row.unitType! : 'piece';
    _active = row.status != 'inactive';
    _initialized = true;
  }

  static String _trimNum(String? v) {
    if (v == null) return '';
    final d = double.tryParse(v);
    if (d == null) return v;
    return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final repo = ref.read(categoryRepositoryProvider);
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'parentId': _parentId,
      'status': _active ? 'active' : 'inactive',
      'fabricId': _fabricId,
      'techniqueId': _techniqueId,
      'dyeTypeId': _dyeTypeId,
      'borderStyleId': _borderStyleId,
      'unitType': _unit,
      'hsnCode': _hsn.text.trim().isEmpty ? null : _hsn.text.trim(),
      'gstRate': _gst.text.trim().isEmpty ? null : _gst.text.trim(),
      'costPrice': _cost.text.trim().isEmpty ? null : _cost.text.trim(),
      'b2cPrice': _retail.text.trim().isEmpty ? null : _retail.text.trim(),
      'b2bPrice': _b2b.text.trim().isEmpty ? null : _b2b.text.trim(),
    };
    if (_code.text.trim().isNotEmpty) body['code'] = _code.text.trim();
    try {
      if (widget.isEdit) {
        await repo.update(widget.categoryId!, body);
      } else {
        await repo.create(body);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isEdit ? 'Design updated' : 'Design created')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: context.p.danger),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete design?'),
        content: Text('“${_name.text.trim()}” will be removed. This can\'t be undone.\n\n'
            'Designs that still have products or sub-designs can\'t be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.p.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(categoryRepositoryProvider).delete(widget.categoryId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Design deleted')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: context.p.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookupsAsync = ref.watch(categoryLookupsProvider);
    final isOwner = ref.watch(authControllerProvider).session?.isOwner ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit design' : 'New design'),
        actions: [
          if (widget.isEdit && isOwner)
            IconButton(
              tooltip: 'Delete',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: lookupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$e', style: TextStyle(color: context.p.danger)),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(categoryLookupsProvider),
              child: const Text('Try again'),
            ),
          ]),
        ),
        data: (lookups) {
          // New category: default the parent to the first sub-category under the
          // focus category (e.g. Cotton Sarees under Sarees).
          if (!widget.isEdit && !_parentDefaulted) {
            _parentDefaulted = true;
            final subs = _focusSubs(lookups);
            final init = widget.initialParentId;
            if (init != null && subs.any((s) => s.id == init)) {
              _parentId = init; // drilled into a specific sub-category
            } else if (subs.isNotEmpty) {
              _parentId = subs.first.id; // default to first sub under focus
            } else {
              _parentId = init; // no focus scope — use whatever was passed
            }
          }

          // In edit mode we need the existing row to seed the form.
          if (widget.isEdit && !_initialized) {
            final catsAsync = ref.watch(categoriesProvider);
            return catsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.p.danger))),
              data: (rows) {
                CategoryRow? found;
                for (final r in rows) {
                  if (r.id == widget.categoryId) {
                    found = r;
                    break;
                  }
                }
                if (found == null) {
                  return const Center(child: Text('Design not found.'));
                }
                _seed(found);
                return _form(lookups);
              },
            );
          }
          return _form(lookups);
        },
      ),
    );
  }

  Widget _form(CategoryLookups lookups) {
    final codePreview = _code.text.trim().isNotEmpty
        ? _code.text.trim().toUpperCase()
        : _deriveCode(_name.text);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _sectionLabel('Classification'),
          _dropdown(
            label: kCategoryFocus != null ? 'Sub-design (under $kCategoryFocus)' : 'Parent design',
            value: _parentId,
            options: kCategoryFocus != null
                ? [
                    for (final c in _focusSubs(lookups).where((c) => c.id != widget.categoryId))
                      PickerOption(c.id, c.name)
                  ]
                : [
                    // Can't be its own parent.
                    for (final c in lookups.topCategories.where((c) => c.id != widget.categoryId))
                      PickerOption(c.id, c.name)
                  ],
            // Non-focus mode allowed "None (top-level)".
            allowClear: kCategoryFocus == null,
            hint: kCategoryFocus == null ? 'None (top-level)' : null,
            onChanged: (v) => setState(() => _parentId = v),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Design name *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            onChanged: (v) {
              // Keep the code suggestion following the name until the user edits it.
              if (!_codeEdited && !widget.isEdit) {
                setState(() => _code.text = _deriveCode(v));
              } else {
                setState(() {});
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: widget.isEdit ? 'Code override' : 'Code (SKU prefix)',
              helperText: widget.isEdit
                  ? 'A–Z / 0–9, max 6. Only affects products numbered after this change.'
                  : 'A–Z / 0–9, max 6. Auto-suggested from the name — edit if you like.',
            ),
            onChanged: (_) => setState(() => _codeEdited = true),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.qr_code_2, size: 16, color: context.p.textSecondary),
              const SizedBox(width: 6),
              Text('SKU will look like: ', style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
              Text('SLK-$codePreview-####',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: context.p.primaryDark)),
            ],
          ),

          const SizedBox(height: 22),
          _sectionLabel('Default attributes'),
          Text('Pieces in this design inherit these.',
              style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Technique',
            value: _techniqueId,
            options: _refItems(lookups.techniques),
            allowClear: true,
            hint: '—',
            onChanged: (v) => setState(() => _techniqueId = v),
          ),
          const SizedBox(height: 14),
          _dropdown(
            label: 'Fabric',
            value: _fabricId,
            options: _refItems(lookups.fabrics),
            allowClear: true,
            hint: '—',
            onChanged: (v) => setState(() => _fabricId = v),
          ),
          const SizedBox(height: 14),
          _dropdown(
            label: 'Border style',
            value: _borderStyleId,
            options: _refItems(lookups.borderStyles),
            allowClear: true,
            hint: '—',
            onChanged: (v) => setState(() => _borderStyleId = v),
          ),
          const SizedBox(height: 14),
          _dropdown(
            label: 'Dye type',
            value: _dyeTypeId,
            options: _refItems(lookups.dyeTypes),
            allowClear: true,
            hint: '—',
            onChanged: (v) => setState(() => _dyeTypeId = v),
          ),
          const SizedBox(height: 14),
          _dropdown(
            label: 'Unit',
            value: _unit,
            options: [
              for (final u in _units) PickerOption(u, u[0].toUpperCase() + u.substring(1))
            ],
            onChanged: (v) => setState(() => _unit = v ?? 'piece'),
          ),

          const SizedBox(height: 22),
          _sectionLabel('Tax'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _hsn,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'HSN code'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _gst,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'GST %', suffixText: '%'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final d = double.tryParse(v.trim());
                    if (d == null || d < 0 || d > 99) return 'Enter 0–99';
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),
          _sectionLabel('Default price'),
          Text(
            'The design price. Each colour can override it when tagging pieces.',
            style: TextStyle(fontSize: 12, color: context.p.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cost,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'Cost', prefixText: '₹ '),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _retail,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'Retail (MRP)', prefixText: '₹ '),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _b2b,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'B2B', prefixText: '₹ '),
                ),
              ),
            ],
          ),

          if (widget.isEdit) ...[
            const SizedBox(height: 22),
            _sectionLabel('Photos'),
            Text(
              'Capture reference shots for this design (Front, Pallu, Border…) so every '
              'product here is photographed the same way.',
              style: TextStyle(fontSize: 12, color: context.p.textSecondary),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push(
                '/category/${widget.categoryId}/photos',
                extra: {'name': _name.text.trim()},
              ),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Capture / manage photos'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],

          if (widget.isEdit && (ref.watch(authControllerProvider).session?.isOwner ?? false)) ...[
            const SizedBox(height: 22),
            _sectionLabel('Stock'),
            Text('Tag finished pieces received for this design with QR codes.',
                style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push('/goods-in'),
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Receive stock (tag pieces)'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],

          const SizedBox(height: 22),
          _sectionLabel('Status'),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: Text(_active ? 'Active' : 'Inactive'),
            subtitle: Text(
              _active ? 'Visible and usable for new products.' : 'Hidden from new-product pickers.',
              style: TextStyle(fontSize: 12, color: context.p.textSecondary),
            ),
          ),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(widget.isEdit ? 'Save changes' : 'Create design'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: context.p.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Sub-categories under the focus category (e.g. the Sarees sub-categories).
  List<NamedRef> _focusSubs(CategoryLookups lookups) {
    if (kCategoryFocus == null) return const [];
    String? focusId;
    for (final c in lookups.topCategories) {
      if (c.name == kCategoryFocus) {
        focusId = c.id;
        break;
      }
    }
    if (focusId == null) return const [];
    return lookups.categories.where((c) => c.parentId == focusId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<PickerOption> _refItems(List<NamedRef> refs) =>
      [for (final r in refs) PickerOption(r.id, r.name)];

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: context.p.primaryDark)),
      );

  Widget _dropdown({
    required String label,
    required String? value,
    required List<PickerOption> options,
    required ValueChanged<String?> onChanged,
    bool allowClear = false,
    String? hint,
  }) {
    return PickerField(
      label: label,
      value: value,
      options: options,
      onChanged: onChanged,
      allowClear: allowClear,
      hint: hint,
    );
  }
}
