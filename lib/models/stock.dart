import 'product.dart';

/// A variant with its current per-location stock (Stock view + pickers).
class StockVariant {
  const StockVariant({
    required this.id,
    required this.sku,
    required this.productName,
    required this.variantLabel,
    required this.stockByLoc,
    required this.totalStock,
  });

  final String id;
  final String sku;
  final String productName;
  final String variantLabel;
  final Map<String, int> stockByLoc;
  final int totalStock;

  factory StockVariant.fromJson(Map<String, dynamic> j) => StockVariant(
        id: j['id'] as String,
        sku: j['sku'] as String,
        productName: (j['productName'] ?? '—') as String,
        variantLabel: (j['variantLabel'] ?? '—') as String,
        stockByLoc: ((j['stockByLoc'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        totalStock: (j['totalStock'] as num?)?.toInt() ?? 0,
      );
}

class StockData {
  const StockData({required this.variants, required this.locations});
  final List<StockVariant> variants;
  final List<NamedLocation> locations;

  factory StockData.fromJson(Map<String, dynamic> j) => StockData(
        variants: ((j['variants'] as List?) ?? [])
            .map((e) => StockVariant.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        locations: ((j['locations'] as List?) ?? [])
            .map((e) => NamedLocation.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// A row in the stock-movement audit ledger.
class MovementRow {
  const MovementRow({
    required this.id,
    required this.createdAt,
    required this.type,
    required this.productName,
    required this.sku,
    required this.variantLabel,
    required this.fromName,
    required this.toName,
    required this.quantity,
    required this.note,
    required this.reference,
    required this.createdBy,
  });

  final String id;
  final String createdAt;
  final String type; // opening | receive | transfer | adjust | sale | transfer_out | transfer_in
  final String productName;
  final String sku;
  final String variantLabel;
  final String? fromName;
  final String? toName;
  final int quantity;
  final String? note;
  final String? reference;
  final String createdBy;

  factory MovementRow.fromJson(Map<String, dynamic> j) => MovementRow(
        id: j['id'] as String,
        createdAt: (j['createdAt'] ?? '') as String,
        type: (j['type'] ?? '') as String,
        productName: (j['productName'] ?? '—') as String,
        sku: (j['sku'] ?? '—') as String,
        variantLabel: (j['variantLabel'] ?? '—') as String,
        fromName: j['fromName'] as String?,
        toName: j['toName'] as String?,
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        note: j['note'] as String?,
        reference: j['reference'] as String?,
        createdBy: (j['createdBy'] ?? '') as String,
      );
}
