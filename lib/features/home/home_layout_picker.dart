import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'home_layout.dart';
import 'home_layout_controller.dart';

/// Shows the home-layout chooser as a modal bottom sheet. Used both for the
/// one-time first-run prompt and from Settings.
Future<void> showHomeLayoutSheet(BuildContext context, {bool firstRun = false}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: context.p.surface1,
    builder: (_) => _HomeLayoutSheet(firstRun: firstRun),
  );
}

class _HomeLayoutSheet extends StatelessWidget {
  const _HomeLayoutSheet({required this.firstRun});
  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(firstRun ? 'Choose your home view' : 'Home layout',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.p.text)),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text('You can change this anytime in Settings › Appearance.',
                  style: TextStyle(fontSize: 12.5, color: context.p.textSecondary)),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: HomeLayoutTiles(closeOnSelect: firstRun),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The list of selectable layout tiles — embeddable in Settings or a sheet.
class HomeLayoutTiles extends ConsumerWidget {
  const HomeLayoutTiles({super.key, this.closeOnSelect = false});
  final bool closeOnSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(homeLayoutProvider);
    return Column(
      children: [
        for (final m in homeLayouts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LayoutTile(
              meta: m,
              selected: m.layout == current,
              onTap: () {
                ref.read(homeLayoutProvider.notifier).select(m.layout);
                if (closeOnSelect) Navigator.of(context).maybePop();
              },
            ),
          ),
      ],
    );
  }
}

class _LayoutTile extends StatelessWidget {
  const _LayoutTile({required this.meta, required this.selected, required this.onTap});
  final HomeLayoutMeta meta;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.p.surface2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? context.p.primary : context.p.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.p.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(meta.icon, color: context.p.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meta.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(meta.description, style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: context.p.primary),
            ],
          ),
        ),
      ),
    );
  }
}
