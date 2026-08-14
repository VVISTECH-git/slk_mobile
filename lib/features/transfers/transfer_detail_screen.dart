import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/transfer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
import '../../widgets/async_view.dart';
import '../../widgets/picker_field.dart';
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
  final Map<String, String> _reason = {}; // itemId → discrepancy reason (short receipts)
  final Map<String, String> _note = {}; // itemId → optional note
  bool _busy = false;

  static const _reasons = ['damaged', 'lost', 'miscount', 'other'];

  Future<void> _receive(TransferDetail t) async {
    // Every short line must have a reason (backend enforces this too).
    for (final it in t.items) {
      final recv = _received[it.id] ?? it.quantityDispatched;
      if (recv < it.quantityDispatched && (_reason[it.id] ?? '').isEmpty) {
        showError(context, 'Pick a reason for the short quantity on ${it.productName}.');
        return;
      }
    }
    setState(() => _busy = true);
    try {
      final list = t.items.map((it) {
        final recv = _received[it.id] ?? it.quantityDispatched;
        final short = recv < it.quantityDispatched;
        return (
          itemId: it.id,
          quantity: recv,
          reason: short ? _reason[it.id] : null,
          note: short ? _note[it.id] : null,
        );
      }).toList();
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              await context.push('/pieces/receive/${t.id}');
                              ref.invalidate(transferDetailProvider(widget.transferId));
                            },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan to receive'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
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
                        child: FilledButton.tonalIcon(
                          onPressed: _busy ? null : () => _receive(t),
                          icon: const Icon(Icons.check),
                          label: Text(_busy ? 'Working…' : 'Confirm (counts)'),
                        ),
                      ),
                    ],
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
    final short = recv < it.quantityDispatched;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                else ...[
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
              ],
            ),
            // Received short — capture why (editable) or show why (received).
            if (editable && short) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: context.p.danger),
                const SizedBox(width: 6),
                Text('Short by ${it.quantityDispatched - recv} — reason required',
                    style: TextStyle(fontSize: 12, color: context.p.danger, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              PickerField(
                label: 'Reason',
                value: (_reason[it.id] ?? '').isEmpty ? null : _reason[it.id],
                options: [
                  for (final r in _reasons) PickerOption(r, r[0].toUpperCase() + r.substring(1)),
                ],
                onChanged: (v) => setState(() => _reason[it.id] = v ?? ''),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder(), isDense: true),
                onChanged: (v) => _note[it.id] = v,
              ),
            ] else if (!editable &&
                it.quantityReceived != null &&
                it.quantityReceived! < it.quantityDispatched &&
                (it.discrepancyReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Short: ${it.discrepancyReason}${(it.discrepancyNote ?? '').isNotEmpty ? ' · ${it.discrepancyNote}' : ''}',
                style: TextStyle(fontSize: 12, color: context.p.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
