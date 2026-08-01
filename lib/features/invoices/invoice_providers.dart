import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/invoice.dart';

/// One full tax invoice by id (POS result view + Invoices detail).
final invoiceProvider =
    FutureProvider.autoDispose.family<InvoiceFull, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/invoices/$id');
  return InvoiceFull.fromJson((data as Map).cast<String, dynamic>());
});

/// The invoices list (most recent first).
final invoicesListProvider =
    FutureProvider.autoDispose<List<InvoiceListRow>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/invoices');
  return (data as List)
      .map((e) => InvoiceListRow.fromJson((e as Map).cast<String, dynamic>()))
      .toList();
});

/// Business profile printed on invoices (legal name, GSTIN, address…).
final businessProfileProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/settings/business');
  return (data as Map).cast<String, dynamic>();
});
