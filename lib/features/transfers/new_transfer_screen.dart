import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/product.dart';
import '../../models/transfer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
import '../../widgets/async_view.dart';
import '../../widgets/picker_field.dart';
import 'transfer_providers.dart';

class NewTransferScreen extends ConsumerStatefulWidget {
  const NewTransferScreen({super.key});

  @override
  ConsumerState<NewTransferScreen> createState() => _NewTransferScreenState();
}

class _NewTransferScreenState extends ConsumerState<NewTransferScreen> {
  String? _from;
  String? _to;
  final _note = TextEditingController();
  final Map<String, int> _qty = {}; // variantId → quantity
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _dispatch() async {
    if (_from == null || _to == null) {
      showError(context, 'Pick a source and destination.');
      return;
    }
    if (_from == _to) {
      showError(context, 'Source and destination must differ.');
      return;
    }
    final items = _qty.entries.where((e) => e.value > 0).map((e) => (variantId: e.key, quantity: e.value)).toList();
    if (items.isEmpty) {
      showError(context, 'Add at least one item.');
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await ref.read(transferRepositoryProvider).create(
            fromLocationId: _from!,
            toLocationId: _to!,
            items: items,
            note: _note.text.trim(),
          );
      if (!mounted) return;
      showOk(context, 'Transfer dispatched.');
      context.pushReplacement('/transfers/$id');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(transferLocationsProvider);

    return Scaffold(
      appBar: AppBar(
        actions: const [ThemeButton()],title: const Text('New transfer')),
      body: AsyncView<List<NamedLocation>>(
        value: locations,
        onRetry: () => ref.invalidate(transferLocationsProvider),
        data: (locs) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PickerField(
              label: 'Dispatch from',
              value: _from,
              options: [for (final l in locs) PickerOption(l.id, l.name)],
              onChanged: (v) => setState(() {
                _from = v;
                _qty.clear(); // stock context changed
              }),
            ),
            const SizedBox(height: 12),
            PickerField(
              label: 'Send to',
              value: _to,
              options: [for (final l in locs) PickerOption(l.id, l.name)],
              onChanged: (v) => setState(() => _to = v),
            ),
            const SizedBox(height: 16),
            if (_from == null)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Choose a source to list its stock.', style: TextStyle(color: context.p.textSecondary))),
              )
            else
              _ItemPicker(
                locationId: _from!,
                qty: _qty,
                onChanged: (id, q) => setState(() {
                  if (q <= 0) {
                    _qty.remove(id);
                  } else {
                    _qty[id] = q;
                  }
                }),
              ),
            const SizedBox(height: 12),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)')),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _busy ? null : _dispatch,
            icon: const Icon(Icons.local_shipping),
            label: Text(_busy ? 'Dispatching…' : 'Dispatch (${_qty.length} item${_qty.length == 1 ? '' : 's'})'),
          ),
        ),
      ),
    );
  }
}

class _ItemPicker extends ConsumerStatefulWidget {
  const _ItemPicker({required this.locationId, required this.qty, required this.onChanged});
  final String locationId;
  final Map<String, int> qty;
  final void Function(String variantId, int qty) onChanged;

  @override
  ConsumerState<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends ConsumerState<_ItemPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final variants = ref.watch(variantsAtLocationProvider(widget.locationId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(hintText: 'Search stock at source', prefixIcon: Icon(Icons.search)),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 8),
        variants.when(
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$e', style: TextStyle(color: context.p.danger))),
          data: (list) {
            final q = _query.trim().toLowerCase();
            final rows = q.isEmpty
                ? list
                : list.where((v) => v.productName.toLowerCase().contains(q) || v.sku.toLowerCase().contains(q)).toList();
            if (rows.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('No stock here.'));
            return Column(children: rows.map((v) => _row(v)).toList());
          },
        ),
      ],
    );
  }

  Widget _row(TransferVariant v) {
    final q = widget.qty[v.id] ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${v.sku} · ${v.variantLabel} · ${v.stock} in stock',
                      style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                ],
              ),
            ),
            IconButton(
              onPressed: q > 0 ? () => widget.onChanged(v.id, q - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$q', style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(
              onPressed: q < v.stock ? () => widget.onChanged(v.id, q + 1) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}
