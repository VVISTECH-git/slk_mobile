import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/transfer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
import '../../widgets/async_view.dart';
import 'transfer_providers.dart';
import 'transfers_screen.dart' show TransferStatusChip;

class TransferDetailScreen extends ConsumerStatefulWidget {
  const TransferDetailScreen({super.key, required this.transferId});
  final String transferId;

  @override
  ConsumerState<TransferDetailScreen> createState() => _TransferDetailScreenState();
}

class _TransferDetailScreenState extends ConsumerState<TransferDetailScreen> {
  final Map<String, int> _received = {}; // itemId → received qty (defaults to dispatched)
  bool _busy = false;

  Future<void> _receive(TransferDetail t) async {
    setState(() => _busy = true);
    try {
      final list = t.items
          .map((it) => (itemId: it.id, quantity: _received[it.id] ?? it.quantityDispatched))
          .toList();
      await ref.read(transferRepositoryProvider).receive(t.id, list);
      ref.invalidate(transferDetailProvider(widget.transferId));
      if (!mounted) return;
      showOk(context, 'Transfer received.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(TransferDetail t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel transfer?'),
        content: const Text('In-transit stock will return to the source location.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel transfer')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(transferRepositoryProvider).cancel(t.id);
      ref.invalidate(transferDetailProvider(widget.transferId));
      if (!mounted) return;
      showOk(context, 'Transfer cancelled.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(transferDetailProvider(widget.transferId));
    return Scaffold(
      appBar: AppBar(
        actions: const [ThemeButton()],title: const Text('Transfer')),
      body: AsyncView<TransferDetail>(
        value: detail,
        onRetry: () => ref.invalidate(transferDetailProvider(widget.transferId)),
        data: (t) => _body(t),
      ),
    );
  }

  Widget _body(TransferDetail t) {
    final dispatched = t.status == 'dispatched';
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(t.orderNumber,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          ),
                          TransferStatusChip(status: t.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${t.fromName ?? '—'}  →  ${t.toName ?? '—'}'),
                      Text('Dispatched by ${t.createdBy} · ${t.createdAt}',
                          style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                      if (t.receivedBy != null)
                        Text('Received by ${t.receivedBy} · ${t.receivedAt ?? ''}',
                            style: TextStyle(fontSize: 12, color: context.p.success)),
                      if ((t.note ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(t.note!, style: const TextStyle(fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(dispatched ? 'Confirm received quantities' : 'Items',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              for (final it in t.items) _itemRow(it, editable: dispatched),
            ],
          ),
        ),
        if (dispatched)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _cancel(t),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _receive(t),
                      icon: const Icon(Icons.check),
                      label: Text(_busy ? 'Working…' : 'Confirm receipt'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _itemRow(TransferItem it, {required bool editable}) {
    final recv = _received[it.id] ?? it.quantityDispatched;
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
                  Text(it.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${it.sku}${it.variantLabel != null && it.variantLabel != '—' ? ' · ${it.variantLabel}' : ''}',
                      style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                  Text('Dispatched: ${it.quantityDispatched}',
                      style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                ],
              ),
            ),
            if (editable)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: recv > 0 ? () => setState(() => _received[it.id] = recv - 1) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$recv', style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    onPressed: recv < it.quantityDispatched
                        ? () => setState(() => _received[it.id] = recv + 1)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              )
            else
              Text(
                it.quantityReceived != null ? 'Recv: ${it.quantityReceived}' : '—',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: it.quantityReceived != null && it.quantityReceived! < it.quantityDispatched
                      ? context.p.danger
                      : context.p.text,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
