import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../models/invoice.dart';
import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
import '../../widgets/async_view.dart';
import 'invoice_providers.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(invoicesListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          const ThemeButton(),
          IconButton(onPressed: () => ref.invalidate(invoicesListProvider), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: AsyncView<List<InvoiceListRow>>(
        value: invoices,
        onRetry: () => ref.invalidate(invoicesListProvider),
        isEmpty: (d) => d.isEmpty,
        emptyMessage: 'No invoices yet.',
        data: (rows) {
          final q = _query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? rows
              : rows
                  .where((r) =>
                      r.invoiceNumber.toLowerCase().contains(q) ||
                      (r.customer ?? '').toLowerCase().contains(q))
                  .toList();
          final total = filtered.fold<double>(0, (s, r) => s + r.total);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search invoice # or customer',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: context.p.primary.withValues(alpha: 0.06),
                child: Text('${filtered.length} invoices · ${money0(total)}',
                    style: TextStyle(fontWeight: FontWeight.w600, color: context.p.primaryDark)),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _InvoiceCard(row: filtered[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.row});
  final InvoiceListRow row;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/invoices/${row.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${row.customer ?? 'Walk-in'}${row.storeName != null ? ' · ${row.storeName}' : ''}',
                      style: TextStyle(fontSize: 12, color: context.p.textSecondary),
                    ),
                    Text(row.createdAt, style: TextStyle(fontSize: 11, color: context.p.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(money(row.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(row.paymentMode.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.p.primaryDark)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
