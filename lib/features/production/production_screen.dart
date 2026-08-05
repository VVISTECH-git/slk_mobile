import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
import 'production_providers.dart';

/// Landing hub for the Job Work / Production module: a live "pieces out" summary
/// plus entries into batches, dispatch, the reconciliation board, and lookup.
class ProductionScreen extends ConsumerWidget {
  const ProductionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(jobBoardProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Production'),
        actions: [
          const ThemeButton(),
          IconButton(onPressed: () => ref.invalidate(jobBoardProvider), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary of what's currently out with vendors.
          board.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (orders) {
              final pending = orders.fold<int>(0, (s, o) => s + ((o as Map)['pending'] as num).toInt());
              final challans = orders.length;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.p.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.p.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping_outlined, color: context.p.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        pending == 0
                            ? 'Nothing out with vendors.'
                            : '$pending piece${pending == 1 ? '' : 's'} out across $challans challan${challans == 1 ? '' : 's'}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _Tile(
            icon: Icons.inventory_2_outlined,
            title: 'Batches',
            subtitle: 'Raw kora batches · cut & tag pieces',
            onTap: () => context.push('/production/batches'),
          ),
          _Tile(
            icon: Icons.qr_code_scanner,
            title: 'Send to vendor',
            subtitle: 'Scan pieces out for a stage',
            onTap: () async {
              await context.push('/production/dispatch');
              ref.invalidate(jobBoardProvider);
            },
          ),
          _Tile(
            icon: Icons.fact_check_outlined,
            title: 'Job board',
            subtitle: 'Open challans · receive · what\'s pending',
            onTap: () async {
              await context.push('/production/board');
              ref.invalidate(jobBoardProvider);
            },
          ),
          _Tile(
            icon: Icons.search,
            title: 'Piece lookup',
            subtitle: 'Scan a tag to see its full history',
            onTap: () => context.push('/production/lookup'),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: context.p.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: context.p.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        subtitle: Text(subtitle, style: TextStyle(color: context.p.textSecondary, fontSize: 13)),
        trailing: Icon(Icons.chevron_right, color: context.p.textMuted),
        onTap: onTap,
      ),
    );
  }
}
