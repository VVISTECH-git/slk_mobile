import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../core/format.dart';
import '../../models/invoice.dart';
import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
import '../../widgets/async_view.dart';
import 'invoice_pdf.dart';
import 'invoice_providers.dart';

class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({super.key, required this.invoiceId, this.justCreated = false});
  final String invoiceId;
  final bool justCreated;

  Future<Uint8List> _pdf(WidgetRef ref, InvoiceFull inv) async {
    final business = await ref.read(businessProfileProvider.future);
    final bytes = await buildInvoicePdf(inv, business);
    return Uint8List.fromList(bytes);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(invoiceProvider(invoiceId));

    return Scaffold(
      appBar: AppBar(
        actions: const [ThemeButton()],
        title: Text(justCreated ? 'Sale complete' : 'Invoice'),
        leading: justCreated
            ? IconButton(
                icon: const Icon(Icons.close),
                // Pop back to the till (kept under this route by the checkout's
                // pushReplacement) so the home hub stays reachable. `go('/pos')`
                // would reset the stack and strip POS's back button.
                onPressed: () => context.canPop() ? context.pop() : context.go('/'),
              )
            : null,
      ),
      body: AsyncView<InvoiceFull>(
        value: invoice,
        onRetry: () => ref.invalidate(invoiceProvider(invoiceId)),
        data: (inv) => _InvoiceBody(inv: inv, justCreated: justCreated),
      ),
      bottomNavigationBar: invoice.maybeWhen(
        data: (inv) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      final bytes = await _pdf(ref, inv);
                      await Printing.sharePdf(bytes: bytes, filename: '${inv.invoiceNumber}.pdf');
                    },
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Printing.layoutPdf(onLayout: (_) => _pdf(ref, inv)),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print / PDF'),
                  ),
                ),
              ],
            ),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({required this.inv, required this.justCreated});
  final InvoiceFull inv;
  final bool justCreated;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (justCreated)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: context.p.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: context.p.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Sale recorded · ${money(inv.total)}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: context.p.success)),
                ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(inv.invoiceNumber,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    _PaymentChip(mode: inv.paymentMode),
                  ],
                ),
                Text(inv.createdAt, style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                if (inv.storeName != null)
                  Text('${inv.storeName}${inv.staffName != null ? ' · ${inv.staffName}' : ''}',
                      style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                if (inv.customer.hasAny) ...[
                  const Divider(height: 20),
                  const Text('Customer', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(inv.customer.name ?? '—'),
                  if (inv.customer.phone?.isNotEmpty == true)
                    Text(inv.customer.phone!, style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                  if (inv.customer.gstin?.isNotEmpty == true)
                    Text('GSTIN: ${inv.customer.gstin}',
                        style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final it in inv.items) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                                '${it.sku} · ${money(it.unitPrice)} × ${it.quantity}'
                                '${it.gstRate > 0 ? ' · GST ${it.gstRate.toStringAsFixed(0)}%' : ''}',
                                style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                          ],
                        ),
                      ),
                      Text(money(it.lineTotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const Divider(height: 18),
                ],
                _row('Taxable value', money(inv.taxableValue)),
                if (inv.isInterState)
                  _row('IGST', money(inv.igst))
                else ...[
                  _row('CGST', money(inv.cgst)),
                  _row('SGST', money(inv.sgst)),
                ],
                if (inv.discount > 0) _row('Discount', '− ${money(inv.discount)}'),
                const SizedBox(height: 6),
                _row('Total (incl. GST)', money(inv.total), bold: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 17 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          const SizedBox(width: 8),
          Flexible(child: Text(value, style: style, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.mode});
  final String mode;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.p.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(mode.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.p.primaryDark)),
    );
  }
}
