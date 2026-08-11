import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
import '../../widgets/async_view.dart';
import '../transfers/transfer_providers.dart';
import 'piece_providers.dart';
import 'scan_collector.dart';

/// Scan the pieces that physically arrived for a transfer. Anything on the order
/// that isn't scanned is marked missing with the chosen reason.
class ReceivePiecesScreen extends ConsumerStatefulWidget {
  const ReceivePiecesScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<ReceivePiecesScreen> createState() => _ReceivePiecesScreenState();
}

class _ReceivePiecesScreenState extends ConsumerState<ReceivePiecesScreen> {
  List<String> _codes = [];
  String _reason = 'lost';
  bool _busy = false;

  static const _reasons = ['damaged', 'lost', 'miscount', 'other'];

  Future<void> _receive() async {
    setState(() => _busy = true);
    try {
      final res = await ref.read(pieceRepositoryProvider).receive(
            orderId: widget.orderId,
            codes: _codes,
            missingReason: _reason,
          );
      ref.invalidate(transferDetailProvider(widget.orderId));
      ref.invalidate(transfersProvider);
      if (!mounted) return;
      final missing = (res['missing'] as num?)?.toInt() ?? 0;
      showOk(context, 'Received ${res['received']}${missing > 0 ? ', $missing missing' : ''}.');
      context.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: const [ThemeButton()], title: const Text('Scan receipt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Scan every piece that arrived. Any piece not scanned is recorded as missing.',
              style: TextStyle(color: context.p.textSecondary)),
          const SizedBox(height: 12),
          Row(children: [
            Text('Missing reason:', style: TextStyle(color: context.p.textSecondary)),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _reason,
              items: [for (final r in _reasons) DropdownMenuItem(value: r, child: Text(r[0].toUpperCase() + r.substring(1)))],
              onChanged: (v) => setState(() => _reason = v ?? 'lost'),
            ),
          ]),
          const SizedBox(height: 8),
          ScanCollector(onChanged: (c) => setState(() => _codes = c), hint: 'Scan arriving item'),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _busy ? null : _receive,
            icon: const Icon(Icons.check),
            label: Text(_busy ? 'Working…' : 'Confirm receipt (${_codes.length})'),
          ),
        ),
      ),
    );
  }
}
