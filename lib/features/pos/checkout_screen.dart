import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
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
    final wholesale = ref.read(wholesaleProvider);
    setState(() => _busy = true);
    try {
      final result = await ref.read(posRepositoryProvider).createInvoice(
            cart: cart,
            paymentMode: _payment,
            discount: _discountValue,
            channel: wholesale ? 'wholesale' : 'retail',
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
      ref.read(wholesaleProvider.notifier).state = false; // reset for next sale
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
    final wholesale = ref.watch(wholesaleProvider);
    final subtotal = cart.fold<double>(0, (s, l) => s + l.grossFor(wholesale));
    final total = (subtotal - _discountValue).clamp(0, double.infinity);

    return Scaffold(
      appBar: AppBar(
        actions: const [ThemeButton()],title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Sales channel ----
          const _SectionLabel('Sale type'),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Retail'), icon: Icon(Icons.storefront_outlined)),
              ButtonSegment(value: true, label: Text('Wholesale'), icon: Icon(Icons.inventory_2_outlined)),
            ],
            selected: {wholesale},
            onSelectionChanged: (s) => setState(() {
              ref.read(wholesaleProvider.notifier).state = s.first;
              if (s.first) _showCustomer = true; // GSTIN needed for wholesale GST
            }),
          ),
          if (wholesale)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'B2B prices applied. Enter the buyer\'s GSTIN — GST auto-switches to IGST for out-of-state buyers.',
                style: TextStyle(fontSize: 12, color: context.p.textSecondary, height: 1.3),
              ),
            ),
          const SizedBox(height: 16),

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
                                Text('${l.variant.sku} · ${money(l.variant.priceFor(wholesale))} × ${l.quantity}',
                                    style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                              ],
                            ),
                          ),
                          Text(money(l.grossFor(wholesale)), style: const TextStyle(fontWeight: FontWeight.w700)),
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
            color: context.p.primary.withValues(alpha: 0.06),
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
      color: context.p.text,
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
      style: TextStyle(fontWeight: FontWeight.w700, color: context.p.text, fontSize: 15));
}
