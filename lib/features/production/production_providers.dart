import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

// ---- Reads (map-based, like settings/dashboard) ----

final prodStagesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return (await ref.watch(apiClientProvider).get('/production/stages')) as List;
});

final prodVendorsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return (await ref.watch(apiClientProvider).get('/production/vendors')) as List;
});

final batchesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return (await ref.watch(apiClientProvider).get('/production/batches')) as List;
});

final batchDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final data = await ref.watch(apiClientProvider).get('/production/batches/$id');
  return (data as Map).cast<String, dynamic>();
});

/// The reconciliation board — open/partial challans with pending counts + aging.
final jobBoardProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return (await ref.watch(apiClientProvider).get('/production/reconciliation')) as List;
});

final jobOrderProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final data = await ref.watch(apiClientProvider).get('/production/orders/$id');
  return (data as Map).cast<String, dynamic>();
});

// ---- Writes ----

final productionRepositoryProvider = Provider((ref) => ProductionRepository(ref));

class ProductionRepository {
  ProductionRepository(this.ref);
  final Ref ref;

  Future<Map<String, dynamic>> createBatch({
    required String material,
    double? lengthMeters,
    String? supplier,
    double? cost,
    String? note,
  }) async {
    final data = await ref.read(apiClientProvider).post('/production/batches', body: {
      'material': material,
      if (lengthMeters != null) 'lengthMeters': lengthMeters,
      if (supplier != null && supplier.isNotEmpty) 'supplier': supplier,
      if (cost != null) 'cost': cost,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Cut a batch into serialized pieces. Returns the created tag codes.
  Future<List<String>> cutAndTag(String batchId, List<({String size, int quantity})> cuts) async {
    final data = await ref.read(apiClientProvider).post('/production/batches/$batchId/cut', body: {
      'cuts': [for (final c in cuts) {'size': c.size, 'quantity': c.quantity}],
    });
    final created = ((data as Map)['created'] as List? ?? []);
    return [for (final c in created) (c as Map)['tagCode'] as String];
  }

  /// Dispatch scanned pieces to a vendor for a stage. Returns the challan info
  /// including any skipped tags (unknown / already out).
  Future<Map<String, dynamic>> dispatch({
    required String vendorId,
    required String stageId,
    required List<String> tagCodes,
    String? note,
  }) async {
    final data = await ref.read(apiClientProvider).post('/production/dispatch', body: {
      'vendorId': vendorId,
      'stageId': stageId,
      'tagCodes': tagCodes,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Receive scanned pieces against a challan (partial supported).
  Future<Map<String, dynamic>> receive(String jobOrderId, List<String> tagCodes, {String? note}) async {
    final data = await ref.read(apiClientProvider).post('/production/orders/$jobOrderId/receive', body: {
      'tagCodes': tagCodes,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return (data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> lookupPiece(String tag) async {
    final data = await ref.read(apiClientProvider).get('/production/pieces/$tag');
    return (data as Map).cast<String, dynamic>();
  }
}
