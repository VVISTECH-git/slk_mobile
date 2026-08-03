import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';

typedef ReconKey = ({String? date, String? storeId});

final reconProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, ReconKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/reports/reconciliation', query: {
    if (key.date != null) 'date': key.date,
    if (key.storeId != null) 'storeId': key.storeId,
  });
  return (data as Map).cast<String, dynamic>();
});

class ReconciliationScreen extends ConsumerStatefulWidget {
  const ReconciliationScreen({super.key});

  @override
  ConsumerState<ReconciliationScreen> createState() => _ReconciliationScreenState();
}

class _ReconciliationScreenState extends ConsumerState<ReconciliationScreen> {
  DateTime _date = DateTime.now();
  String? _storeId;

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_date);

  @override
  Widget build(BuildContext context) {
    final recon = ref.watch(reconProvider((date: _dateStr, storeId: _storeId)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily report'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(reconProvider((date: _dateStr, storeId: _storeId))),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AsyncView<Map<String, dynamic>>(
        value: recon,
        onRetry: () => ref.invalidate(reconProvider((date: _dateStr, storeId: _storeId))),
        data: (d) {
          final summary = (d['summary'] as Map?) ?? {};
          final byPayment = (d['byPayment'] as Map?) ?? {};
          final sold = (d['sold'] as List?) ?? [];
          final stores = ((d['stores'] as List?) ?? []).cast<dynamic>();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Filters
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(DateFormat('d MMM yyyy').format(_date)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _storeId,
                      decoration: const InputDecoration(labelText: 'Store', isDense: true),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All stores')),
                        ...stores.map((s) => DropdownMenuItem(
                            value: (s as Map)['id'] as String, child: Text('${s['name']}'))),
                      ],
                      onChanged: (v) => setState(() => _storeId = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.7,
                children: [
                  _Tile(label: 'Sales', value: money0((summary['amount'] as num?) ?? 0), color: context.p.primary),
                  _Tile(label: 'Invoices', value: '${summary['count'] ?? 0}', color: context.p.success),
                  _Tile(label: 'Units sold', value: '${summary['units'] ?? 0}', color: context.p.accent),
                  _Tile(label: 'GST collected', value: money0((summary['tax'] as num?) ?? 0), color: context.p.textSecondary),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Payment split', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: byPayment.isEmpty
                      ? Text('No sales on this day.', style: TextStyle(color: context.p.textSecondary))
                      : Column(
                          children: ['cash', 'upi', 'card']
                              .where((m) => byPayment.containsKey(m))
                              .map((m) {
                            final row = (byPayment[m] as Map);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(m.toUpperCase()),
                                  Text('${row['count']} · ${money0((row['amount'] as num?) ?? 0)}',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Items sold', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              if (sold.isEmpty)
                Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Nothing sold.', style: TextStyle(color: context.p.textSecondary))))
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: sold.map((r) {
                        final m = (r as Map);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${m['productName']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text('${m['sku']}', style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
                                  ],
                                ),
                              ),
                              Text('${m['qty']} · ${money0((m['amount'] as num?) ?? 0)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.p.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: context.p.textSecondary)),
        ],
      ),
    );
  }
}
