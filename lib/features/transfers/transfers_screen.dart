import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/transfer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
import '../../widgets/async_view.dart';
import 'transfer_providers.dart';

class TransfersScreen extends ConsumerWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(transfersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfers'),
        actions: [
          const ThemeButton(),
          IconButton(
            tooltip: 'Scan dispatch',
            onPressed: () async {
              await context.push('/pieces/dispatch');
              ref.invalidate(transfersProvider);
            },
            icon: const Icon(Icons.qr_code_scanner),
          ),
          IconButton(onPressed: () => ref.invalidate(transfersProvider), icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/transfers/new');
          ref.invalidate(transfersProvider);
        },
        backgroundColor: context.p.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New transfer'),
      ),
      body: AsyncView<List<TransferListRow>>(
        value: transfers,
        onRetry: () => ref.invalidate(transfersProvider),
        isEmpty: (d) => d.isEmpty,
        emptyMessage: 'No transfers yet. Create one to move stock between locations.',
        data: (rows) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _TransferCard(row: rows[i]),
        ),
      ),
    );
  }
}

class _TransferCard extends ConsumerWidget {
  const _TransferCard({required this.row});
  final TransferListRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await context.push('/transfers/${row.id}');
          ref.invalidate(transfersProvider);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(row.orderNumber,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  TransferStatusChip(status: row.status),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 16, color: context.p.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('${row.fromName ?? '—'}  →  ${row.toName ?? '—'}',
                        style: TextStyle(fontSize: 13, color: context.p.text)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${row.itemCount} item${row.itemCount == 1 ? '' : 's'} · ${row.units} units · ${row.createdAt}',
                  style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class TransferStatusChip extends StatelessWidget {
  const TransferStatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'received' => (context.p.success, 'Received'),
      'cancelled' => (context.p.textSecondary, 'Cancelled'),
      _ => (context.p.accent, 'In transit'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
