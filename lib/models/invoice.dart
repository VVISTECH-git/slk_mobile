/// One line on a tax invoice.
class InvoiceItem {
  const InvoiceItem({
    required this.sku,
    required this.productName,
    required this.variantLabel,
    required this.hsnCode,
    required this.gstRate,
    required this.unitPrice,
    required this.quantity,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.lineTotal,
  });

  final String sku;
  final String productName;
  final String? variantLabel;
  final String? hsnCode;
  final double gstRate;
  final double unitPrice;
  final int quantity;
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double lineTotal;

  factory InvoiceItem.fromJson(Map<String, dynamic> j) => InvoiceItem(
        sku: j['sku'] as String,
        productName: j['productName'] as String,
        variantLabel: j['variantLabel'] as String?,
        hsnCode: j['hsnCode'] as String?,
        gstRate: (j['gstRate'] as num?)?.toDouble() ?? 0,
        unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0,
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        taxableValue: (j['taxableValue'] as num?)?.toDouble() ?? 0,
        cgst: (j['cgst'] as num?)?.toDouble() ?? 0,
        sgst: (j['sgst'] as num?)?.toDouble() ?? 0,
        lineTotal: (j['lineTotal'] as num?)?.toDouble() ?? 0,
      );
}

class InvoiceCustomer {
  const InvoiceCustomer({this.name, this.phone, this.email, this.gstin, this.address});
  final String? name;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? address;

  factory InvoiceCustomer.fromJson(Map<String, dynamic> j) => InvoiceCustomer(
        name: j['name'] as String?,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        gstin: j['gstin'] as String?,
        address: j['address'] as String?,
      );

  bool get hasAny => [name, phone, email, gstin, address].any((s) => s != null && s.isNotEmpty);
}

/// A complete tax invoice, as returned by GET /invoices/:id.
class InvoiceFull {
  const InvoiceFull({
    required this.id,
    required this.invoiceNumber,
    required this.createdAt,
    required this.storeName,
    required this.staffName,
    required this.customer,
    required this.items,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.taxTotal,
    required this.discount,
    required this.total,
    required this.paymentMode,
  });

  final String id;
  final String invoiceNumber;
  final String createdAt;
  final String? storeName;
  final String? staffName;
  final InvoiceCustomer customer;
  final List<InvoiceItem> items;
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double taxTotal;
  final double discount;
  final double total;
  final String paymentMode;

  factory InvoiceFull.fromJson(Map<String, dynamic> j) => InvoiceFull(
        id: j['id'] as String,
        invoiceNumber: j['invoiceNumber'] as String,
        createdAt: (j['createdAt'] ?? '') as String,
        storeName: j['storeName'] as String?,
        staffName: j['staffName'] as String?,
        customer: InvoiceCustomer.fromJson((j['customer'] as Map?)?.cast<String, dynamic>() ?? {}),
        items: ((j['items'] as List?) ?? [])
            .map((e) => InvoiceItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        taxableValue: (j['taxableValue'] as num?)?.toDouble() ?? 0,
        cgst: (j['cgst'] as num?)?.toDouble() ?? 0,
        sgst: (j['sgst'] as num?)?.toDouble() ?? 0,
        taxTotal: (j['taxTotal'] as num?)?.toDouble() ?? 0,
        discount: (j['discount'] as num?)?.toDouble() ?? 0,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        paymentMode: (j['paymentMode'] ?? '') as String,
      );
}

/// A row in the invoices list (GET /invoices).
class InvoiceListRow {
  const InvoiceListRow({
    required this.id,
    required this.invoiceNumber,
    required this.createdAt,
    required this.storeName,
    required this.customer,
    required this.paymentMode,
    required this.taxTotal,
    required this.total,
  });

  final String id;
  final String invoiceNumber;
  final String createdAt;
  final String? storeName;
  final String? customer;
  final String paymentMode;
  final double taxTotal;
  final double total;

  factory InvoiceListRow.fromJson(Map<String, dynamic> j) => InvoiceListRow(
        id: j['id'] as String,
        invoiceNumber: j['invoiceNumber'] as String,
        createdAt: (j['createdAt'] ?? '') as String,
        storeName: j['storeName'] as String?,
        customer: j['customer'] as String?,
        paymentMode: (j['paymentMode'] ?? '') as String,
        taxTotal: (j['taxTotal'] as num?)?.toDouble() ?? 0,
        total: (j['total'] as num?)?.toDouble() ?? 0,
      );
}
