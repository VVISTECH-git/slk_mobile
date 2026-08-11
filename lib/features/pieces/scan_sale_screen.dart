import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/theme_button.dart';
import '../../widgets/async_view.dart';
import '../pos/pos_providers.dart';
import 'piece_providers.dart';
import 'scan_collector.dart';

/// Sell by scanning the actual pieces. Retail (B2C) or wholesale (B2B); GST is
/// computed on the server (IGST for out-of-state GSTINs).
class ScanSaleScreen extends ConsumerStatefulWidget {
  const ScanSaleScreen({super.key});

  @override
  ConsumerState<ScanSaleScreen> createState() => _ScanSaleScreenState();
}

class _ScanSaleScreenState extends ConsumerState<ScanSaleScreen> {
  List<String> _codes = [];
  bool _wholesale = false;
  String _payment = 'cash';
  final _name = TextEditingController();
  final _gstin = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _gstin.dispose();
    super.dispose();
  }

  Future<void> _sell() async {
    if (_codes.isEmpty) return showError(context, 'Scan at least one item.');
    setState(() => _busy = true);
    try {
      final res = await ref.read(pieceRepositoryProvider).sell(
            codes: _codes,
            channel: _wholesale ? 'wholesale' : 'retail',
            paymentMode: _payment,
            customer: (_name.text.trim().isNotEmpty || _gstin.text.trim().isNotEmpty)
                ? {'name': _name.text.trim(), 'gstin': _gstin.text.trim()}
                : null,
          );
      ref.invalidate(sellableProvider);
      if (!mounted) return;
      context.pushReplacement('/pos/invoice/${res['invoiceId']}');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: const [ThemeButton()], title: const Text('Scan sale')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Retail'), icon: Icon(Icons.storefront_outlined)),
              ButtonSegment(value: true, label: Text('Wholesale'), icon: Icon(Icons.inventory_2_outlined)),
            ],
            selected: {_wholesale},
            onSelectionChanged: (s) => setState(() => _wholesale = s.first),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'cash', label: Text('Cash')),
              ButtonSegment(value: 'upi', label: Text('UPI')),
              ButtonSegment(value: 'card', label: Text('Card')),
            ],
            selected: {_payment},
            onSelectionChanged: (s) => setState(() => _payment = s.first),
          ),
          const SizedBox(height: 12),
          if (_wholesale || _name.text.isNotEmpty) ...[
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Customer name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
              controller: _gstin,
              decoration: const InputDecoration(labelText: 'GSTIN (for IGST/CGST split)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
          ],
          ScanCollector(onChanged: (c) => setState(() => _codes = c), hint: 'Scan item to sell'),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _busy ? null : _sell,
            icon: const Icon(Icons.point_of_sale),
            label: Text(_busy ? 'Billing…' : 'Sell ${_codes.length} piece${_codes.length == 1 ? '' : 's'}'),
          ),
        ),
      ),
    );
  }
}
