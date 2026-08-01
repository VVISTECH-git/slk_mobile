import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import 'pos_providers.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _payment = 'cash';
  final _discount = TextEditingController(text: '0');
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _gstin = TextEditingController();
  final _address = TextEditingController();
  bool _showCustomer = false;
  bool _busy = false;

  @override
  void dispose() {
    _discount.dispose();
    _name.dispose();
    _phone.dispose();
    _gstin.dispose();
    _address.dispose();
    super.dispose();
  }

  double get _discountValue => double.tryParse(_discount.text.trim()) ?? 0;

  Future<void> _complete() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      showError(context, 'The cart is empty.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref.read(posRepositoryProvider).createInvoice(
            cart: cart,
            paymentMode: _payment,
            discount: _discountValue,
            customer: _showCustomer
                ? {
                    'name': _name.text.trim(),
                    'phone': _phone.text.trim(),
                    'gstin': _gstin.text.trim(),
                    'address': _address.text.trim(),
                  }
                : null,
          );
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(sellableProvider); // stock changed
      if (!mounted) return;
      // Replace so the back button returns to the till, not checkout.
      context.pushReplacement('/pos/invoice/${result.invoiceId}');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final subtotal = cart.fold<double>(0, (s, l) => s + l.gross);
    final total = (subtotal - _discountValue).clamp(0, double.infinity);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Cart lines ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final l in cart)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.variant.productName,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('${l.variant.sku} · ${money(l.variant.price)} × ${l.quantity}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                              ],
                            ),
                          ),
                          Text(money(l.gross), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- Payment mode ----
          const _SectionLabel('Payment mode'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'cash', label: Text('Cash'), icon: Icon(Icons.payments_outlined)),
              ButtonSegment(value: 'upi', label: Text('UPI'), icon: Icon(Icons.qr_code)),
              ButtonSegment(value: 'card', label: Text('Card'), icon: Icon(Icons.credit_card)),
            ],
            selected: {_payment},
            onSelectionChanged: (s) => setState(() => _payment = s.first),
          ),
          const SizedBox(height: 16),

          // ---- Discount ----
          TextField(
            controller: _discount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Discount (₹)',
              prefixIcon: Icon(Icons.percent),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),

          // ---- Optional customer ----
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Add customer details'),
            subtitle: const Text('For a named GST invoice'),
            value: _showCustomer,
            onChanged: (v) => setState(() => _showCustomer = v),
          ),
          if (_showCustomer) ...[
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 10),
            TextField(controller: _gstin, decoration: const InputDecoration(labelText: 'GSTIN')),
            const SizedBox(height: 10),
            TextField(
                controller: _address,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address')),
          ],
          const SizedBox(height: 16),

          // ---- Totals ----
          Card(
            color: AppColors.terracotta.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _totalRow('Subtotal', money(subtotal)),
                  if (_discountValue > 0) _totalRow('Discount', '− ${money(_discountValue)}'),
                  const Divider(),
                  _totalRow('Total (incl. GST)', money(total), bold: true),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _busy || cart.isEmpty ? null : _complete,
            child: _busy
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Complete sale · ${money(total)}'),
          ),
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 18 : 15,
      color: AppColors.ink,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 15));
}
