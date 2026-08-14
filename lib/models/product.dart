/// A row in the Products list (aggregated per product).
class ProductListRow {
  const ProductListRow({
    required this.id,
    required this.name,
    required this.productCode,
    required this.status,
    required this.categoryPath,
    required this.variantCount,
    required this.minPrice,
    required this.maxPrice,
    required this.totalStock,
    required this.stockByLoc,
    required this.lowStock,
    this.productId,
    this.colour,
  });

  final String id;
  // When the list is grouped per colour, `id` is the variant id; use productId
  // for navigation to the product, and colour is that row's colour.
  final String? productId;
  final String? colour;
  final String name;
  final String productCode;
  final String status; // active | inactive | draft
  final String categoryPath;
  final int variantCount;
  final double? minPrice;
  final double? maxPrice;
  final int totalStock;
  final Map<String, int> stockByLoc;
  final bool lowStock;

  factory ProductListRow.fromJson(Map<String, dynamic> j) => ProductListRow(
        id: j['id'] as String,
        productId: j['productId'] as String?,
        colour: j['colour'] as String?,
        name: j['name'] as String,
        productCode: (j['productCode'] ?? '—') as String,
        status: (j['status'] ?? 'draft') as String,
        categoryPath: (j['categoryPath'] ?? '') as String,
        variantCount: (j['variantCount'] as num?)?.toInt() ?? 0,
        minPrice: (j['minPrice'] as num?)?.toDouble(),
        maxPrice: (j['maxPrice'] as num?)?.toDouble(),
        totalStock: (j['totalStock'] as num?)?.toInt() ?? 0,
        stockByLoc: ((j['stockByLoc'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        lowStock: (j['lowStock'] as bool?) ?? false,
      );
}

/// A named location column in the products/stock lists.
class NamedLocation {
  const NamedLocation({required this.id, required this.name});
  final String id;
  final String name;
  factory NamedLocation.fromJson(Map<String, dynamic> j) =>
      NamedLocation(id: j['id'] as String, name: j['name'] as String);
}

/// The Products list payload: rows + the location columns.
class ProductsList {
  const ProductsList({required this.rows, required this.locations, this.total = 0});
  final List<ProductListRow> rows;
  final List<NamedLocation> locations;
  final int total; // total matching products (for pagination)

  factory ProductsList.fromJson(Map<String, dynamic> j) => ProductsList(
        rows: ((j['rows'] as List?) ?? [])
            .map((e) => ProductListRow.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        locations: ((j['locations'] as List?) ?? [])
            .map((e) => NamedLocation.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}
