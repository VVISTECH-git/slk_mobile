/// A priced, in-stock variant sellable at the current till's store.
class SellableVariant {
  const SellableVariant({
    required this.id,
    required this.sku,
    required this.productName,
    required this.variantLabel,
    required this.price,
    required this.gstRate,
    required this.hsnCode,
    required this.stock,
  });

  final String id;
  final String sku;
  final String productName;
  final String variantLabel;
  final double price; // MRP (GST-inclusive)
  final double gstRate;
  final String? hsnCode;
  final int stock;

  factory SellableVariant.fromJson(Map<String, dynamic> j) => SellableVariant(
        id: j['id'] as String,
        sku: j['sku'] as String,
        productName: (j['productName'] ?? '—') as String,
        variantLabel: (j['variantLabel'] ?? '—') as String,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        gstRate: (j['gstRate'] as num?)?.toDouble() ?? 0,
        hsnCode: j['hsnCode'] as String?,
        stock: (j['stock'] as num?)?.toInt() ?? 0,
      );
}

/// A line in the working cart — a variant plus a chosen quantity.
class CartLine {
  const CartLine({required this.variant, required this.quantity});
  final SellableVariant variant;
  final int quantity;

  double get gross => variant.price * quantity;

  CartLine copyWith({int? quantity}) =>
      CartLine(variant: variant, quantity: quantity ?? this.quantity);
}
