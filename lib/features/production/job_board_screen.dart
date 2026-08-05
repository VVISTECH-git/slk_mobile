import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/theme_button.dart';
import 'production_providers.dart';

/// The accountability board: every open/partial challan, how many pieces are
/// still pending return, and how long they've been out.
class JobBoardScreen extends ConsumerWidget {
  const JobBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(jobBoardProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job board'),
        actions: [
          const ThemeButton(),
          IconButton(onPressed: () => ref.invalidate(jobBoardProvider), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: AsyncView<List<dynamic>>(
        value: board,
        onRetry: () => ref.invalidate(jobBoardProvider),
        isEmpty: (d) => d.isEmpty,
        emptyMessage: 'No open challans. Everything is accounted for.',
        data: (rows) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final o = (rows[i] as Map).cast<String, dynamic>();
            final pending = (o['pending'] as num).toInt();
            final received = (o['received'] as num).toInt();
            final total = (o['total'] as num).toInt();
            final age = (o['ageDays'] as num).toInt();
            final overdue = age >= 7 && pending > 0;
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  await context.push('/production/orders/${o['id']}');
                  ref.invalidate(jobBoardProvider);
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('${o['challanNo']}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          ),
                          _statusChip(context, o['status'] as String),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${o['vendorName'] ?? '—'} · ${o['stageName'] ?? '—'}',
                          style: TextStyle(fontSize: 13, color: context.p.text)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('$received / $total received',
                              style: TextStyle(fontSize: 13, color: context.p.textSecondary)),
                          const Spacer(),
                          Icon(Icons.schedule, size: 14, color: overdue ? context.p.danger : context.p.textMuted),
                          const SizedBox(width: 4),
                          Text(age == 0 ? 'today' : '${age}d out',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: overdue ? FontWeight.w700 : FontWeight.w400,
                                  color: overdue ? context.p.danger : context.p.textMuted)),
                        ],
                      ),
                      if (pending > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.p.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$pending pending return',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.p.danger)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    final (color, label) = switch (status) {
      'partial' => (context.p.accent, 'Partial'),
      _ => (context.p.primary, 'Open'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
