import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../theme/app_theme.dart';

/// Full-screen continuous scanner: keeps the camera open and accumulates every
/// distinct code scanned, with a beep + haptic per new one and a live counter.
/// Pops with the `List<String>` of unique codes when you tap Done. Used for
/// scan-out (dispatch) and scan-in (receive) where you scan many pieces in a row.
class ContinuousScanScreen extends StatefulWidget {
  const ContinuousScanScreen({
    super.key,
    this.title = 'Scan pieces',
    this.already = const <String>{},
  });

  final String title;

  /// Codes already collected (e.g. re-opening the scanner to add more) — shown
  /// as duplicates rather than re-added.
  final Set<String> already;

  @override
  State<ContinuousScanScreen> createState() => _ContinuousScanScreenState();
}

class _ContinuousScanScreenState extends State<ContinuousScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.all],
  );
  final _codes = <String>{};
  String? _lastMessage;
  bool _lastWasDup = false;

  @override
  void initState() {
    super.initState();
    _codes.addAll(widget.already);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v == null || v.isEmpty) continue;
      final code = v.trim();
      if (_codes.contains(code)) {
        if (_lastMessage != code || !_lastWasDup) {
          setState(() {
            _lastMessage = code;
            _lastWasDup = true;
          });
        }
        continue;
      }
      _codes.add(code);
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);
      setState(() {
        _lastMessage = code;
        _lastWasDup = false;
      });
    }
  }

  Future<void> _manualEntry() async {
    final c = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter tag code'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Tag code'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (code != null && code.isNotEmpty && mounted) {
      setState(() {
        if (_codes.add(code)) {
          _lastMessage = code;
          _lastWasDup = false;
        } else {
          _lastMessage = code;
          _lastWasDup = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('${widget.title} · ${_codes.length}'),
        actions: [
          IconButton(onPressed: _manualEntry, icon: const Icon(Icons.keyboard_outlined), tooltip: 'Type a code'),
          IconButton(onPressed: () => _controller.toggleTorch(), icon: const Icon(Icons.flashlight_on_outlined)),
          IconButton(onPressed: () => _controller.switchCamera(), icon: const Icon(Icons.cameraswitch_outlined)),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Reticle
          Container(
            height: 200,
            width: 260,
            decoration: BoxDecoration(
              border: Border.all(color: _lastWasDup ? Colors.orangeAccent : context.p.accent, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          // Live feedback of the last scan
          Positioned(
            top: 24,
            child: _lastMessage == null
                ? const SizedBox.shrink()
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_lastWasDup ? Colors.orange : Colors.green).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _lastWasDup ? 'Already scanned: $_lastMessage' : 'Added: $_lastMessage',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
          ),
          // Running counter + Done
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black.withValues(alpha: 0.55),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${_codes.length} scanned',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(_codes.toList()),
                      icon: const Icon(Icons.check),
                      label: Text('Done (${_codes.length})'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
