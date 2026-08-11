import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

/// Serialized-stock operations: identify a scanned code, and mint codes (goods-in).
final pieceRepositoryProvider = Provider((ref) => PieceRepository(ref));

class PieceRepository {
  PieceRepository(this.ref);
  final Ref ref;

  /// Scan-to-identify. Returns the piece + product, or null if the code is unknown.
  Future<Map<String, dynamic>?> identify(String code) async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get('/stock/pieces/${Uri.encodeComponent(code.trim())}');
      return (data as Map).cast<String, dynamic>();
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Goods-in: mint [count] unique codes for a variant at a location.
  Future<List<String>> generate({
    required String variantId,
    required String locationId,
    required int count,
  }) async {
    final data = await ref.read(apiClientProvider).post('/stock/pieces', body: {
      'variantId': variantId,
      'locationId': locationId,
      'count': count,
    });
    final map = (data as Map).cast<String, dynamic>();
    return ((map['codes'] as List?) ?? []).cast<String>();
  }
}
