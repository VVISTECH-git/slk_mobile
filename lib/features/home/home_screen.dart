import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/theme_button.dart';
import '../auth/auth_controller.dart';

class _Module {
  const _Module(this.label, this.icon, this.route, {this.ownerOnly = false});
  final String label;
  final IconData icon;
  final String route;
  final bool ownerOnly;
}

const _modules = [
  _Module('Point of Sale', Icons.point_of_sale, '/pos'),
  _Module('Dashboard', Icons.dashboard_outlined, '/dashboard'),
  _Module('Products', Icons.inventory_2_outlined, '/products'),
  _Module('Stock', Icons.warehouse_outlined, '/stock'),
  _Module('Transfers', Icons.local_shipping_outlined, '/transfers'),
  _Module('Invoices', Icons.receipt_long_outlined, '/invoices'),
  _Module('Daily report', Icons.summarize_outlined, '/reports'),
  _Module('Settings', Icons.settings_outlined, '/settings', ownerOnly: true),
];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    final isOwner = session?.isOwner ?? false;
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
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _StoreBanner(store: session?.storeName ?? '', name: session?.name ?? ''),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.15,
              children: modules.map((m) => _ModuleTile(module: m)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreBanner extends StatelessWidget {
  const _StoreBanner({required this.store, required this.name});
  final String store;
  final String name;
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

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module});
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.p.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: context.p.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(module.icon, color: context.p.primary, size: 26),
              ),
              const SizedBox(height: 12),
              Text(module.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600, color: context.p.text)),
            ],
          ),
        ),
      ),
    );
  }
}
