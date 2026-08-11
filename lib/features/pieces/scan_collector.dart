import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../pos/barcode_scan_screen.dart';
import 'piece_providers.dart';

class ScannedPiece {
  ScannedPiece(this.code, {this.piece, this.error});
  final String code;
  Map<String, dynamic>? piece; // identity, once resolved
  String? error;
}

/// Reusable scan list: a focused field (Bluetooth HID scanner types here and
/// submits on Enter), a camera button, and a running list of scanned pieces —
/// each identified so the user sees what they scanned. Notifies [onChanged]
/// with the current valid codes.
class ScanCollector extends ConsumerStatefulWidget {
  const ScanCollector({super.key, required this.onChanged, this.hint = 'Scan or type item code'});
  final void Function(List<String> codes) onChanged;
  final String hint;

  @override
  ConsumerState<ScanCollector> createState() => _ScanCollectorState();
}

class _ScanCollectorState extends ConsumerState<ScanCollector> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  final List<ScannedPiece> _items = [];

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _notify() => widget.onChanged(_items.where((i) => i.error == null).map((i) => i.code).toList());

  Future<void> _add(String raw) async {
    final code = raw.trim();
    _field.clear();
    _focus.requestFocus();
    if (code.isEmpty) return;
    if (_items.any((i) => i.code == code)) return; // no duplicates
    final item = ScannedPiece(code);
    setState(() => _items.insert(0, item));
    try {
      final piece = await ref.read(pieceRepositoryProvider).identify(code);
      setState(() {
        item.piece = piece;
        item.error = piece == null ? 'Unknown code' : null;
      });
    } catch (e) {
      setState(() => item.error = '$e');
    }
    _notify();
  }

  Future<void> _camera() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen(title: 'Scan item QR')),
    );
    if (code != null) _add(code);
  }

  void _remove(ScannedPiece i) {
    setState(() => _items.remove(i));
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _field,
              focusNode: _focus,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: widget.hint, prefixIcon: const Icon(Icons.qr_code), border: const OutlineInputBorder()),
              onSubmitted: _add,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(onPressed: _camera, icon: const Icon(Icons.photo_camera_outlined)),
        ]),
        const SizedBox(height: 8),
        Text('${_items.where((i) => i.error == null).length} scanned',
            style: TextStyle(color: context.p.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        for (final i in _items)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: Icon(i.error != null ? Icons.error_outline : Icons.check_circle_outline,
                  color: i.error != null ? context.p.danger : context.p.success),
              title: Text(i.error != null ? i.code : '${i.piece?['productName'] ?? i.code}'),
              subtitle: Text(i.error ?? '${i.code} · ${_label(i.piece)}',
                  style: TextStyle(fontSize: 12, color: i.error != null ? context.p.danger : context.p.textSecondary)),
              trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _remove(i)),
            ),
          ),
      ],
    );
  }

  String _label(Map<String, dynamic>? p) {
    if (p == null) return '…';
    final bits = [p['color'], p['size'], p['status']].where((s) => (s as String?)?.isNotEmpty ?? false);
    return bits.join(' · ');
  }
}
