/// A row in the Transfers list.
class TransferListRow {
  const TransferListRow({
    required this.id,
    required this.orderNumber,
    required this.fromName,
    required this.toName,
    required this.status,
    required this.itemCount,
    required this.units,
    required this.createdAt,
    required this.createdBy,
  });

  final String id;
  final String orderNumber;
  final String? fromName;
  final String? toName;
  final String status; // dispatched | received | cancelled
  final int itemCount;
  final int units;
  final String createdAt;
  final String createdBy;

  factory TransferListRow.fromJson(Map<String, dynamic> j) => TransferListRow(
        id: j['id'] as String,
        orderNumber: j['orderNumber'] as String,
        fromName: j['fromName'] as String?,
        toName: j['toName'] as String?,
        status: (j['status'] ?? '') as String,
        itemCount: (j['itemCount'] as num?)?.toInt() ?? 0,
        units: (j['units'] as num?)?.toInt() ?? 0,
        createdAt: (j['createdAt'] ?? '') as String,
        createdBy: (j['createdBy'] ?? '') as String,
      );
}

/// A variant available to dispatch from a location (has stock there).
class TransferVariant {
  const TransferVariant({
    required this.id,
    required this.sku,
    required this.productName,
    required this.variantLabel,
    required this.stock,
  });

  final String id;
  final String sku;
  final String productName;
  final String variantLabel;
  final int stock;

  factory TransferVariant.fromJson(Map<String, dynamic> j) => TransferVariant(
        id: j['id'] as String,
        sku: j['sku'] as String,
        productName: (j['productName'] ?? '—') as String,
        variantLabel: (j['variantLabel'] ?? '—') as String,
        stock: (j['stock'] as num?)?.toInt() ?? 0,
      );
}

class TransferItem {
  const TransferItem({
    required this.id,
    required this.sku,
    required this.productName,
    required this.variantLabel,
    required this.quantityDispatched,
    required this.quantityReceived,
  });

  final String id;
  final String sku;
  final String productName;
  final String? variantLabel;
  final int quantityDispatched;
  final int? quantityReceived;

  factory TransferItem.fromJson(Map<String, dynamic> j) => TransferItem(
        id: j['id'] as String,
        sku: j['sku'] as String,
        productName: j['productName'] as String,
        variantLabel: j['variantLabel'] as String?,
        quantityDispatched: (j['quantityDispatched'] as num?)?.toInt() ?? 0,
        quantityReceived: (j['quantityReceived'] as num?)?.toInt(),
      );
}

class TransferDetail {
  const TransferDetail({
    required this.id,
    required this.orderNumber,
    required this.fromName,
    required this.toName,
    required this.status,
    required this.note,
    required this.createdBy,
    required this.createdAt,
    required this.receivedBy,
    required this.receivedAt,
    required this.items,
  });

  final String id;
  final String orderNumber;
  final String? fromName;
  final String? toName;
  final String status;
  final String? note;
  final String createdBy;
  final String createdAt;
  final String? receivedBy;
  final String? receivedAt;
  final List<TransferItem> items;

  factory TransferDetail.fromJson(Map<String, dynamic> j) => TransferDetail(
        id: j['id'] as String,
        orderNumber: j['orderNumber'] as String,
        fromName: j['fromName'] as String?,
        toName: j['toName'] as String?,
        status: (j['status'] ?? '') as String,
        note: j['note'] as String?,
        createdBy: (j['createdBy'] ?? '') as String,
        createdAt: (j['createdAt'] ?? '') as String,
        receivedBy: j['receivedBy'] as String?,
        receivedAt: j['receivedAt'] as String?,
        items: ((j['items'] as List?) ?? [])
            .map((e) => TransferItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
