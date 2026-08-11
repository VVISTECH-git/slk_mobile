import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/product.dart';
import '../../widgets/theme_button.dart';
import '../../widgets/async_view.dart';
import '../transfers/transfer_providers.dart';
import 'piece_providers.dart';
import 'scan_collector.dart';

/// Scan pieces out of their current location to a destination — creates a
/// piece-level transfer order.
class DispatchPiecesScreen extends ConsumerStatefulWidget {
  const DispatchPiecesScreen({super.key});

  @override
  ConsumerState<DispatchPiecesScreen> createState() => _DispatchPiecesScreenState();
}

class _DispatchPiecesScreenState extends ConsumerState<DispatchPiecesScreen> {
  String? _to;
  final _note = TextEditingController();
  List<String> _codes = [];
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _dispatch() async {
    if (_to == null) return showError(context, 'Pick a destination.');
    if (_codes.isEmpty) return showError(context, 'Scan at least one item.');
    setState(() => _busy = true);
    try {
      final id = await ref.read(pieceRepositoryProvider).dispatch(
            codes: _codes,
            toLocationId: _to!,
            note: _note.text.trim(),
          );
      ref.invalidate(transfersProvider);
      if (!mounted) return;
      showOk(context, 'Dispatched ${_codes.length} pieces.');
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
      appBar: AppBar(actions: const [ThemeButton()], title: const Text('Scan dispatch')),
      body: AsyncView<List<NamedLocation>>(
        value: locations,
        onRetry: () => ref.invalidate(transferLocationsProvider),
        data: (locs) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _to,
              decoration: const InputDecoration(labelText: 'Send to', border: OutlineInputBorder()),
              items: locs.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))).toList(),
              onChanged: (v) => setState(() => _to = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ScanCollector(onChanged: (c) => setState(() => _codes = c)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _busy ? null : _dispatch,
            icon: const Icon(Icons.local_shipping),
            label: Text(_busy ? 'Dispatching…' : 'Dispatch ${_codes.length} piece${_codes.length == 1 ? '' : 's'}'),
          ),
        ),
      ),
    );
  }
}
