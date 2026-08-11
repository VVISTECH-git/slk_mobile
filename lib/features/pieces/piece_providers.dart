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

  /// Dispatch scanned pieces to a location → returns the new transfer order id.
  Future<String> dispatch({required List<String> codes, required String toLocationId, String? note}) async {
    final data = await ref.read(apiClientProvider).post('/pieces/dispatch', body: {
      'codes': codes,
      'toLocationId': toLocationId,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return ((data as Map).cast<String, dynamic>())['id'] as String;
  }

  /// Receive scanned pieces for a transfer; unscanned pieces become missing.
  Future<Map<String, dynamic>> receive({
    required String orderId,
    required List<String> codes,
    String? missingReason,
  }) async {
    final data = await ref.read(apiClientProvider).post('/pieces/receive', body: {
      'orderId': orderId,
      'codes': codes,
      if (missingReason != null) 'missingReason': missingReason,
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Sell scanned pieces at the till.
  Future<Map<String, dynamic>> sell({
    required List<String> codes,
    required String channel,
    required String paymentMode,
    double discount = 0,
    Map<String, String?>? customer,
  }) async {
    final data = await ref.read(apiClientProvider).post('/pieces/sell', body: {
      'codes': codes,
      'channel': channel,
      'paymentMode': paymentMode,
      'discount': discount,
      if (customer != null) 'customer': customer,
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// One-time: serialize existing quantity stock into pieces.
  Future<int> backfill() async {
    final data = await ref.read(apiClientProvider).post('/stock/pieces/backfill');
    return (((data as Map).cast<String, dynamic>())['created'] as num?)?.toInt() ?? 0;
  }
}
