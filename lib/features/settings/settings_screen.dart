import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/async_view.dart';
import 'business_edit_screen.dart';
import 'settings_providers.dart';
import 'staff_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  SettingsRepository _repo(WidgetRef ref) => ref.read(settingsRepositoryProvider);

  Future<void> _guard(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(settingsProvider);
      if (context.mounted) showOk(context, 'Saved.');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<String?> _promptName(BuildContext context, String title, {String hint = 'Name'}) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Add')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(onPressed: () => ref.invalidate(settingsProvider), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: AsyncView<Map<String, dynamic>>(
        value: settings,
        onRetry: () => ref.invalidate(settingsProvider),
        data: (d) {
          final business = (d['business'] as Map?)?.cast<String, dynamic>() ?? {};
          final staff = (d['staff'] as List?) ?? [];
          final stores = ((d['stores'] as List?) ?? []).cast<dynamic>();
          final locations = (d['locations'] as List?) ?? [];
          final categories = (d['categories'] as List?) ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---- Appearance ----
              _SectionHeader('Appearance'),
              const _ThemePicker(),
              const SizedBox(height: 20),

              // ---- Business profile ----
              _SectionHeader('Business profile'),
              Card(
                child: ListTile(
                  title: Text('${business['legalName'] ?? 'Set business details'}'),
                  subtitle: Text(
                    'GSTIN: ${business['gstin']?.toString().isNotEmpty == true ? business['gstin'] : '— not set —'}',
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => BusinessEditScreen(business: business)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ---- Staff ----
              _SectionHeader('Staff & PINs', onAdd: () async {
                final res = await showStaffDialog(context, stores: stores);
                if (res != null) {
                  await _guard(context, ref, () => _repo(ref).addStaff(
                        name: res.name, pin: res.pin ?? '', storeId: res.storeId, role: res.role));
                }
              }),
              ...staff.map((s) {
                final m = (s as Map);
                return Card(
                  child: ListTile(
                    title: Text('${m['name']}'),
                    subtitle: Text('${m['role']}${m['storeName'] != null ? ' · ${m['storeName']}' : ''} · PIN ${m['pin']}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') {
                          final res = await showStaffDialog(context, stores: stores, existing: m.cast<String, dynamic>());
                          if (res != null) {
                            await _guard(context, ref, () => _repo(ref).updateStaff(m['id'] as String,
                                name: res.name, storeId: res.storeId, role: res.role, pin: res.pin));
                          }
                        } else if (v == 'delete') {
                          await _guard(context, ref, () => _repo(ref).deleteStaff(m['id'] as String));
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),

              // ---- Locations ----
              _SectionHeader('Locations', onAdd: () async {
                final name = await _promptName(context, 'New location');
                if (name != null && name.isNotEmpty) {
                  await _guard(context, ref, () => _repo(ref).addLocation(name, 'retail'));
                }
              }),
              ...locations.map((l) {
                final m = (l as Map);
                return _NamedRow(
                  name: '${m['name']}',
                  sub: '${m['type']} · ${m['inUse']} in use',
                  onDelete: (m['inUse'] as num?) == 0
                      ? () => _guard(context, ref, () => _repo(ref).deleteLocation(m['id'] as String))
                      : null,
                );
              }),
              const SizedBox(height: 20),

              // ---- Categories ----
              _SectionHeader('Categories & codes', onAdd: () async {
                final name = await _promptName(context, 'New category');
                if (name != null && name.isNotEmpty) {
                  await _guard(context, ref, () => _repo(ref).addCategory(name, null));
                }
              }),
              ...categories.map((c) {
                final m = (c as Map);
                return _NamedRow(
                  name: '${m['path'] ?? m['name']}',
                  sub: 'Code: ${m['code'] ?? '—'} · ${m['inUse']} in use',
                  onDelete: (m['inUse'] as num?) == 0
                      ? () => _guard(context, ref, () => _repo(ref).deleteCategory(m['id'] as String))
                      : null,
                );
              }),
              const SizedBox(height: 20),

              // ---- Attributes ----
              _AttrGroup(title: 'Fabrics', kind: 'fabric', rows: (d['fabrics'] as List?) ?? [], onChanged: () => ref.invalidate(settingsProvider)),
              _AttrGroup(title: 'Techniques', kind: 'technique', rows: (d['techniques'] as List?) ?? [], onChanged: () => ref.invalidate(settingsProvider)),
              _AttrGroup(title: 'Dye types', kind: 'dye', rows: (d['dyeTypes'] as List?) ?? [], onChanged: () => ref.invalidate(settingsProvider)),
              _AttrGroup(title: 'Border styles', kind: 'border', rows: (d['borderStyles'] as List?) ?? [], onChanged: () => ref.invalidate(settingsProvider)),
            ],
          );
        },
      ),
    );
  }
}

/// Swatch-tile theme picker, LEAP-style: tap a card to switch the whole app's
/// look instantly. The choice persists across launches.
class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeControllerProvider);
    return Column(
      children: [
        for (final t in SlkThemes.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ThemeTile(
              theme: t,
              selected: t.id == current.id,
              onTap: () => ref.read(themeControllerProvider.notifier).select(t),
            ),
          ),
      ],
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.theme, required this.selected, required this.onTap});
  final SlkTheme theme;
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
              // Swatch preview
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.p.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Expanded(child: Container(color: theme.palette.appBar)),
                    Row(
                      children: [
                        Expanded(child: Container(height: 14, color: theme.palette.primary)),
                        Expanded(child: Container(height: 14, color: theme.palette.accent)),
                        Expanded(child: Container(height: 14, color: theme.palette.surface1)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(theme.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(theme.description, style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: context.p.primary)
              else
                Icon(Icons.circle_outlined, color: context.p.border),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.onAdd});
  final String title;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          if (onAdd != null)
            TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
        ],
      ),
    );
  }
}

class _NamedRow extends StatelessWidget {
  const _NamedRow({required this.name, required this.sub, this.onDelete});
  final String name;
  final String sub;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        dense: true,
        title: Text(name),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
        trailing: onDelete == null
            ? Icon(Icons.lock_outline, size: 16, color: context.p.textSecondary)
            : IconButton(onPressed: onDelete, icon: Icon(Icons.delete_outline, color: context.p.danger)),
      ),
    );
  }
}

class _AttrGroup extends ConsumerWidget {
  const _AttrGroup({required this.title, required this.kind, required this.rows, required this.onChanged});
  final String title;
  final String kind;
  final List rows;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${rows.length} item${rows.length == 1 ? '' : 's'}'),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        ...rows.map((r) {
          final m = (r as Map);
          return ListTile(
            dense: true,
            title: Text('${m['name']}'),
            subtitle: Text('${m['inUse']} in use', style: const TextStyle(fontSize: 12)),
            trailing: (m['inUse'] as num?) == 0
                ? IconButton(
                    icon: Icon(Icons.delete_outline, color: context.p.danger),
                    onPressed: () async {
                      try {
                        await ref.read(settingsRepositoryProvider).deleteAttribute(kind, m['id'] as String);
                        onChanged();
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                    },
                  )
                : Icon(Icons.lock_outline, size: 16, color: context.p.textSecondary),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text('Add $title'),
            onPressed: () async {
              final c = TextEditingController();
              final name = await showDialog<String>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('New ${title.toLowerCase()}'),
                  content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Add')),
                  ],
                ),
              );
              if (name != null && name.isNotEmpty) {
                try {
                  await ref.read(settingsRepositoryProvider).addAttribute(kind, name);
                  onChanged();
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              }
            },
          ),
        ),
      ],
    );
  }
}
