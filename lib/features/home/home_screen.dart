import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
import '../auth/auth_controller.dart';
import '../dashboard/dashboard_screen.dart' show dashboardProvider;
import '../production/production_providers.dart' show jobBoardProvider;
import 'home_layout.dart';
import 'home_layout_controller.dart';
import 'home_layout_picker.dart';

class _Module {
  const _Module(this.label, this.icon, this.route, {this.ownerOnly = false, this.primary = false});
  final String label;
  final IconData icon;
  final String route;
  final bool ownerOnly;
  final bool primary; // shown in the bottom bar
}

const _modules = [
  _Module('Point of Sale', Icons.point_of_sale, '/pos', primary: true),
  _Module('Dashboard', Icons.dashboard_outlined, '/dashboard'),
  _Module('Products', Icons.inventory_2_outlined, '/products', primary: true),
  _Module('Stock', Icons.warehouse_outlined, '/stock', primary: true),
  _Module('Transfers', Icons.local_shipping_outlined, '/transfers'),
  _Module('Production', Icons.precision_manufacturing_outlined, '/production', primary: true),
  _Module('Invoices', Icons.receipt_long_outlined, '/invoices'),
  _Module('Daily report', Icons.summarize_outlined, '/reports'),
  _Module('Settings', Icons.settings_outlined, '/settings', ownerOnly: true),
];

/// Pieces currently out at vendors — drives the Production badge across layouts.
final _prodPendingProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(jobBoardProvider).maybeWhen(
        data: (orders) => orders.fold<int>(0, (s, o) => s + ((o as Map)['pending'] as num).toInt()),
        orElse: () => 0,
      );
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // One-time: offer the layout chooser the first time someone reaches home.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chosen = await ref.read(homeLayoutProvider.notifier).hasChosen();
      if (!chosen && mounted) showHomeLayoutSheet(context, firstRun: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    final isOwner = session?.isOwner ?? false;
    final layout = ref.watch(homeLayoutProvider);
    final modules = _modules.where((m) => !m.ownerOnly || isOwner).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sree Lakshmi Kalamkari'),
        actions: [
          const ThemeButton(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) {
              if (v == 'logout') ref.read(authControllerProvider.notifier).signOut();
              if (v == 'layout') showHomeLayoutSheet(context);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${session?.storeName ?? ''} · ${isOwner ? 'Owner' : 'Cashier'}',
                        style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'layout', child: Text('Home layout')),
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _StoreBanner(store: session?.storeName ?? '', name: session?.name ?? ''),
          Expanded(child: _body(layout, modules)),
        ],
      ),
      bottomNavigationBar: layout == HomeLayout.bottomNav ? _BottomBar(modules: modules) : null,
    );
  }

  Widget _body(HomeLayout layout, List<_Module> modules) {
    switch (layout) {
      case HomeLayout.grid:
        return _GridLayout(modules: modules);
      case HomeLayout.list:
        return _ListLayout(modules: modules);
      case HomeLayout.bigButtons:
        return _BigButtonsLayout(modules: modules);
      case HomeLayout.dashboard:
        return _DashboardLayout(modules: modules);
      case HomeLayout.bottomNav:
        return _CompactGrid(modules: modules);
    }
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _StoreBanner extends StatelessWidget {
  const _StoreBanner({required this.store, required this.name});
  final String store, name;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      color: context.p.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(Icons.storefront_outlined, color: context.p.primaryDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$store  ·  $name',
                style: TextStyle(fontWeight: FontWeight.w600, color: context.p.primaryDark)),
          ),
        ],
      ),
    );
  }
}

/// A small red count badge (used for Production "pending at vendor").
class _Badge extends ConsumerWidget {
  const _Badge({required this.route});
  final String route;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (route != '/production') return const SizedBox.shrink();
    final n = ref.watch(_prodPendingProvider);
    if (n == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: context.p.danger, borderRadius: BorderRadius.circular(20)),
      child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Grid (classic)
// ---------------------------------------------------------------------------
class _GridLayout extends StatelessWidget {
  const _GridLayout({required this.modules});
  final List<_Module> modules;
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.15,
      children: [for (final m in modules) _GridTile(module: m)],
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({required this.module});
  final _Module module;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.p.surface2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(module.route),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: context.p.border)),
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 52, width: 52,
                      decoration: BoxDecoration(color: context.p.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
                      child: Icon(module.icon, color: context.p.primary, size: 26),
                    ),
                    const SizedBox(height: 12),
                    Text(module.label, textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600, color: context.p.text)),
                  ],
                ),
              ),
              Positioned(top: 0, right: 0, child: _Badge(route: module.route)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Compact list
// ---------------------------------------------------------------------------
class _ListLayout extends StatelessWidget {
  const _ListLayout({required this.modules});
  final List<_Module> modules;
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: modules.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final m = modules[i];
        return Card(
          child: ListTile(
            onTap: () => context.push(m.route),
            leading: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: context.p.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
              child: Icon(m.icon, color: context.p.primary, size: 22),
            ),
            title: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w700)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              _Badge(route: m.route),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: context.p.textMuted),
            ]),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Big buttons
// ---------------------------------------------------------------------------
class _BigButtonsLayout extends StatelessWidget {
  const _BigButtonsLayout({required this.modules});
  final List<_Module> modules;
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: modules.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final m = modules[i];
        return Material(
          color: context.p.surface2,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push(m.route),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: context.p.border)),
              child: Row(
                children: [
                  Icon(m.icon, color: context.p.primary, size: 30),
                  const SizedBox(width: 18),
                  Expanded(child: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19))),
                  _Badge(route: m.route),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Dashboard-first
// ---------------------------------------------------------------------------
class _DashboardLayout extends ConsumerWidget {
  const _DashboardLayout({required this.modules});
  final List<_Module> modules;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final pending = ref.watch(_prodPendingProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        dash.when(
          loading: () => const SizedBox(height: 90, child: Center(child: CircularProgressIndicator())),
          error: (_, _) => const SizedBox.shrink(),
          data: (d) => GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: [
              _Kpi(label: 'Retail value', value: '₹${d['retailValue'] ?? 0}', color: context.p.primary),
              _Kpi(label: 'Units in stock', value: '${d['totalUnits'] ?? 0}', color: context.p.success),
              _Kpi(label: 'Low stock', value: '${d['lowStockCount'] ?? 0}', color: context.p.danger),
              _Kpi(label: 'Pieces at vendor', value: '$pending', color: context.p.accent),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text('Open a module',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: context.p.textSecondary)),
        ),
        _CompactGrid(modules: modules, shrinkWrap: true),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.p.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 11.5, color: context.p.textSecondary)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact icon grid (used by dashboard body + bottom-nav body)
// ---------------------------------------------------------------------------
class _CompactGrid extends StatelessWidget {
  const _CompactGrid({required this.modules, this.shrinkWrap = false});
  final List<_Module> modules;
  final bool shrinkWrap;
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: EdgeInsets.all(shrinkWrap ? 0 : 16),
      crossAxisCount: 3,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: [
        for (final m in modules)
          Material(
            color: context.p.surface2,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.push(m.route),
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: context.p.border)),
                padding: const EdgeInsets.all(8),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(m.icon, color: context.p.primary, size: 26),
                          const SizedBox(height: 8),
                          Text(m.label, textAlign: TextAlign.center, maxLines: 2,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.p.text)),
                        ],
                      ),
                    ),
                    Positioned(top: 0, right: 0, child: _Badge(route: m.route)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Bottom bar (the persistent quick-shortcut bar)
// ---------------------------------------------------------------------------
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.modules});
  final List<_Module> modules;
  @override
  Widget build(BuildContext context) {
    final primary = modules.where((m) => m.primary).toList();
    return NavigationBar(
      selectedIndex: 0,
      backgroundColor: context.p.surface2,
      onDestinationSelected: (i) => context.push(primary[i].route),
      destinations: [
        for (final m in primary)
          NavigationDestination(icon: Icon(m.icon), label: m.label.split(' ').first),
      ],
    );
  }
}
