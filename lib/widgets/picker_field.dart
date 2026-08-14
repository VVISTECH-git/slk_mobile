import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One selectable option. [color] renders a swatch dot (used for colours).
class PickerOption {
  const PickerOption(this.value, this.label, {this.color});
  final String value;
  final String label;
  final Color? color;
}

/// A form-field-styled selector that opens a clean bottom-sheet picker instead
/// of the default dropdown overlay. Used app-wide so every selector matches.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
    this.allowClear = false,
  });

  final String label;
  final String? value;
  final List<PickerOption> options;
  final ValueChanged<String?> onChanged;
  final String? hint;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    PickerOption? sel;
    for (final o in options) {
      if (o.value == value) {
        sel = o;
        break;
      }
    }
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final result = await showModalBottomSheet<_PickResult>(
          context: context,
          isScrollControlled: true,
          backgroundColor: context.p.surface2,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _PickerSheet(
            title: label,
            options: options,
            current: value,
            allowClear: allowClear,
          ),
        );
        if (result != null) onChanged(result.cleared ? null : result.value);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          suffixIcon: const Icon(Icons.expand_more),
        ),
        child: Row(
          children: [
            if (sel?.color != null) ...[
              _Swatch(color: sel!.color!),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                sel?.label ?? (hint ?? 'Select'),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: sel == null ? context.p.textMuted : context.p.text,
                  fontWeight: sel == null ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickResult {
  const _PickResult(this.value, {this.cleared = false});
  final String? value;
  final bool cleared;
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.current,
    required this.allowClear,
  });
  final String title;
  final List<PickerOption> options;
  final String? current;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // grabber
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.p.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                if (allowClear && current != null)
                  TextButton(
                    onPressed: () => Navigator.pop(context, const _PickResult(null, cleared: true)),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: options.length,
              itemBuilder: (_, i) {
                final o = options[i];
                final selected = o.value == current;
                return ListTile(
                  leading: o.color != null ? _Swatch(color: o.color!, size: 22) : null,
                  title: Text(o.label,
                      style: TextStyle(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? context.p.primaryDark : context.p.text)),
                  trailing: selected ? Icon(Icons.check, color: context.p.primary) : null,
                  onTap: () => Navigator.pop(context, _PickResult(o.value)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, this.size = 18});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: context.p.border),
      ),
    );
  }
}

/// Standard saree colour → swatch colour. Unknown names get a neutral dot.
const Map<String, int> _colourHex = {
  'red': 0xFFD32F2F, 'maroon': 0xFF800000, 'rani pink': 0xFFE30B5C, 'pink': 0xFFFF80AB,
  'peach': 0xFFFFCBA4, 'orange': 0xFFFB8C00, 'rust': 0xFFB7410E, 'mustard': 0xFFE1AD01,
  'yellow': 0xFFFDD835, 'gold': 0xFFD4AF37, 'cream': 0xFFFFF1C1, 'off white': 0xFFF3EEDD,
  'white': 0xFFFFFFFF, 'beige': 0xFFE8DCB5, 'brown': 0xFF795548, 'coffee': 0xFF6F4E37,
  'green': 0xFF388E3C, 'mehendi': 0xFF6B8E23, 'teal': 0xFF008080, 'sea green': 0xFF2E8B57,
  'blue': 0xFF1976D2, 'sky blue': 0xFF87CEEB, 'navy': 0xFF001F5B, 'indigo': 0xFF3F51B5,
  'purple': 0xFF8E24AA,
};

Color colourSwatch(String name) {
  final hex = _colourHex[name.trim().toLowerCase()];
  return Color(hex ?? 0xFFBDBDBD);
}

/// Build colour options (with swatches) from a list of colour names.
List<PickerOption> colourOptions(List<String> names) =>
    [for (final n in names) PickerOption(n, n, color: colourSwatch(n))];

/// Build plain options where value == label.
List<PickerOption> plainOptions(List<String> values) =>
    [for (final v in values) PickerOption(v, v)];
