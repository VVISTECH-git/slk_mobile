import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
import '../../widgets/async_view.dart';
import '../pos/barcode_scan_screen.dart';
import 'piece_providers.dart';

/// Scan (Bluetooth scanner or camera) or type a code → identify the exact piece
/// and its product. The text field stays focused so a HID scanner's keystrokes
/// land here and submit on its trailing Enter.
class ScanIdentifyScreen extends ConsumerStatefulWidget {
  const ScanIdentifyScreen({super.key});

  @override
  ConsumerState<ScanIdentifyScreen> createState() => _ScanIdentifyScreenState();
}

class _ScanIdentifyScreenState extends ConsumerState<ScanIdentifyScreen> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  Map<String, dynamic>? _result;
  String? _notFoundCode;

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _lookup(String raw) async {
    final code = raw.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _result = null;
      _notFoundCode = null;
    });
    try {
      final piece = await ref.read(pieceRepositoryProvider).identify(code);
      setState(() {
        _result = piece;
        _notFoundCode = piece == null ? code : null;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
      _field.clear();
      _focus.requestFocus(); // ready for the next scan
    }
  }

  Future<void> _cameraScan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen(title: 'Scan item QR')),
    );
    if (code != null) _lookup(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: const [ThemeButton()], title: const Text('Identify item')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Scan an item\'s QR with the Bluetooth scanner or camera — or type its code.',
            style: TextStyle(color: context.p.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _field,
                  focusNode: _focus,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Item code',
                    hintText: 'e.g. SLK-P000123',
                    prefixIcon: Icon(Icons.qr_code),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: _lookup,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _cameraScan,
                icon: const Icon(Icons.photo_camera_outlined),
                tooltip: 'Scan with camera',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_busy) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (_notFoundCode != null && !_busy)
            Card(
              color: context.p.danger.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.error_outline, color: context.p.danger),
                  const SizedBox(width: 10),
                  Expanded(child: Text('No item found for “$_notFoundCode”.')),
                ]),
              ),
            ),
          if (_result != null && !_busy) _resultCard(_result!),
        ],
      ),
    );
  }

  Widget _resultCard(Map<String, dynamic> p) {
    final label = [p['color'], p['size']].where((s) => (s as String?)?.isNotEmpty ?? false).join(' / ');
    final status = (p['status'] ?? '') as String;
    final statusColor = switch (status) {
      'available' => context.p.success,
      'sold' => context.p.textSecondary,
      'in_transit' => context.p.primary,
      _ => context.p.danger,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('${p['productName']}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(status.replaceAll('_', ' '),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ]),
            if (label.isNotEmpty) Text(label, style: TextStyle(color: context.p.textSecondary)),
            const Divider(height: 20),
            _kv('Item code', '${p['tagCode']}'),
            _kv('SKU', '${p['sku']}'),
            _kv('Location', '${p['locationName'] ?? '—'}'),
            _kv('Tagged', '${p['createdAt'] ?? '—'}'),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: TextStyle(color: context.p.textSecondary)),
            Flexible(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
