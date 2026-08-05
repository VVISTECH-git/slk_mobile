import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/theme_button.dart';
import 'continuous_scanner.dart';
import 'production_providers.dart';

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  bool _busy = false;

  Future<void> _scanReceive() async {
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => const ContinuousScanScreen(title: 'Scan received')),
    );
    if (result == null || result.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await ref.read(productionRepositoryProvider).receive(widget.orderId, result);
      ref.invalidate(jobOrderProvider(widget.orderId));
      if (!mounted) return;
      final unknown = (res['unknown'] as List? ?? []);
      showOk(context, 'Received ${res['received']} · ${res['pending']} still pending');
      if (unknown.isNotEmpty || (res['alreadyReceived'] as num) > 0) _showAnomalies(res);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showAnomalies(Map<String, dynamic> res) {
    final unknown = (res['unknown'] as List? ?? []);
    final already = (res['alreadyReceived'] as num).toInt();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scan notes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.p.danger)),
              const SizedBox(height: 8),
              if (already > 0) Text('$already were already received (ignored).'),
              for (final u in unknown) Text('$u — not on this challan', style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(jobOrderProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive'),
        actions: [
          const ThemeButton(),
          IconButton(onPressed: () => ref.invalidate(jobOrderProvider(widget.orderId)), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: AsyncView<Map<String, dynamic>>(
        value: order,
        onRetry: () => ref.invalidate(jobOrderProvider(widget.orderId)),
        data: (o) {
          final pieces = (o['pieces'] as List? ?? []);
          final pending = (o['pendingCount'] as num).toInt();
          final received = (o['receivedCount'] as num).toInt();
          final total = (o['total'] as num).toInt();
          final closed = o['status'] == 'closed';
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${o['challanNo']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text('${o['vendorName'] ?? '—'} · ${o['stageName'] ?? '—'}',
                                style: TextStyle(color: context.p.textSecondary)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _stat(context, 'Received', '$received', context.p.success),
                                const SizedBox(width: 10),
                                _stat(context, 'Pending', '$pending', pending > 0 ? context.p.danger : context.p.textMuted),
                                const SizedBox(width: 10),
                                _stat(context, 'Total', '$total', context.p.text),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Pieces', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 8),
                    for (final p in pieces)
                      _pieceRow(context, (p as Map).cast<String, dynamic>()),
                  ],
                ),
              ),
              if (!closed)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _scanReceive,
                      icon: _busy
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan received pieces'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _pieceRow(BuildContext context, Map<String, dynamic> p) {
    final received = p['status'] == 'received';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(received ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18, color: received ? context.p.success : context.p.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${p['tag']}',
                style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: received ? context.p.textMuted : context.p.text)),
          ),
          if ((p['size'] ?? '') != '') Text('${p['size']}', style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
        ],
      ),
    );
  }
}
