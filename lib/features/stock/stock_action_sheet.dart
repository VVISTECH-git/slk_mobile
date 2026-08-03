import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product.dart';
import '../../models/stock.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import 'stock_providers.dart';

enum StockAction { receive, adjust, transfer }

/// Bottom sheet to receive / adjust / transfer a single variant. Returns true
/// if a change was committed (so the caller can refresh).
Future<bool?> showStockActionSheet(
  BuildContext context, {
  required StockVariant variant,
  required List<NamedLocation> locations,
  StockAction initial = StockAction.receive,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.p.surface2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _StockActionForm(variant: variant, locations: locations, initial: initial),
    ),
  );
}

class _StockActionForm extends ConsumerStatefulWidget {
  const _StockActionForm({required this.variant, required this.locations, required this.initial});
  final StockVariant variant;
  final List<NamedLocation> locations;
  final StockAction initial;

  @override
  ConsumerState<_StockActionForm> createState() => _StockActionFormState();
}

class _StockActionFormState extends ConsumerState<_StockActionForm> {
  late StockAction _action = widget.initial;
  String? _location;
  String? _toLocation;
  final _qty = TextEditingController(text: '1');
  final _note = TextEditingController();
  bool _remove = false; // for adjust
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _location = widget.locations.firstOrNull?.id;
    _toLocation = widget.locations.length > 1 ? widget.locations[1].id : null;
  }

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_qty.text.trim()) ?? 0;
    if (qty <= 0) {
      showError(context, 'Enter a quantity greater than zero.');
      return;
    }
    if (_location == null) {
      showError(context, 'Pick a location.');
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(stockRepositoryProvider);
      switch (_action) {
        case StockAction.receive:
          await repo.receive(
              variantId: widget.variant.id, locationId: _location!, quantity: qty, note: _note.text.trim());
        case StockAction.adjust:
          await repo.adjust(
              variantId: widget.variant.id,
              locationId: _location!,
              delta: _remove ? -qty : qty,
              note: _note.text.trim());
        case StockAction.transfer:
          if (_toLocation == null || _toLocation == _location) {
            showError(context, 'Pick a different destination.');
            setState(() => _busy = false);
            return;
          }
          await repo.transfer(
              variantId: widget.variant.id,
              fromLocationId: _location!,
              toLocationId: _toLocation!,
              quantity: qty,
              note: _note.text.trim());
      }
      if (!mounted) return;
      showOk(context, 'Stock updated.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.variant.productName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text('${widget.variant.sku} · ${widget.variant.variantLabel}',
              style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
          const SizedBox(height: 14),
          SegmentedButton<StockAction>(
            segments: const [
              ButtonSegment(value: StockAction.receive, label: Text('Receive')),
              ButtonSegment(value: StockAction.adjust, label: Text('Adjust')),
              ButtonSegment(value: StockAction.transfer, label: Text('Transfer')),
            ],
            selected: {_action},
            onSelectionChanged: (s) => setState(() => _action = s.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _location,
            decoration: InputDecoration(
                labelText: _action == StockAction.transfer ? 'From location' : 'Location'),
            items: widget.locations
                .map((l) => DropdownMenuItem(value: l.id, child: Text(l.name)))
                .toList(),
            onChanged: (v) => setState(() => _location = v),
          ),
          if (_action == StockAction.transfer) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _toLocation,
              decoration: const InputDecoration(labelText: 'To location'),
              items: widget.locations
                  .map((l) => DropdownMenuItem(value: l.id, child: Text(l.name)))
                  .toList(),
              onChanged: (v) => setState(() => _toLocation = v),
            ),
          ],
          if (_action == StockAction.adjust) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_remove ? 'Removing stock (damage/loss)' : 'Adding stock (found/correction)'),
              value: _remove,
              onChanged: (v) => setState(() => _remove = v),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _qty,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
