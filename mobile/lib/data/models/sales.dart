part of '../models.dart';

class SaleItemInput {
  SaleItemInput({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productName;
  final double quantity;
  final double unitPrice;

  Map<String, dynamic> toJson() => {
    'product_name': productName,
    'quantity': quantity,
    'unit_price': unitPrice,
  };
}

enum SaleStatus { paid, invoice }

SaleStatus _saleStatusFromJson(dynamic json) {
  final raw =
      (json['status'] ??
              json['payment_status'] ??
              json['document_type'] ??
              json['kind'])
          ?.toString()
          .trim()
          .toLowerCase();
  switch (raw) {
    case 'invoice':
    case 'unpaid':
    case 'pending':
      return SaleStatus.invoice;
    case 'paid':
    case 'receipt':
    case 'sale':
    default:
      return SaleStatus.paid;
  }
}

class SaleInput {
  SaleInput({
    this.signatureId,
    required this.customerName,
    required this.customerContact,
    required this.items,
    this.status = SaleStatus.paid,
    this.createdAt,
    this.discountAmount = 0,
    this.vatAmount = 0,
    this.serviceFeeAmount = 0,
    this.deliveryFeeAmount = 0,
    this.roundingAmount = 0,
    this.otherAmount = 0,
    this.otherLabel = 'Others',
  });

  final String? signatureId;
  final String customerName;
  final String customerContact;
  final List<SaleItemInput> items;
  final SaleStatus status;
  final String? createdAt;
  final double discountAmount;
  final double vatAmount;
  final double serviceFeeAmount;
  final double deliveryFeeAmount;
  final double roundingAmount;
  final double otherAmount;
  final String otherLabel;

  Map<String, dynamic> toJson() => {
    'signature_id': signatureId == null ? null : int.tryParse(signatureId!),
    'customer_name': customerName,
    'customer_contact': customerContact,
    'items': items.map((e) => e.toJson()).toList(),
    'status': status.name,
    'created_at': createdAt,
    'discount_amount': discountAmount,
    'vat_amount': vatAmount,
    'service_fee_amount': serviceFeeAmount,
    'delivery_fee_amount': deliveryFeeAmount,
    'rounding_amount': roundingAmount,
    'other_amount': otherAmount,
    'other_label': otherLabel,
  };
}

class SaleUpdateInput {
  SaleUpdateInput({
    this.signatureId,
    this.customerName,
    this.customerContact,
    this.items,
    this.status,
    this.discountAmount,
    this.vatAmount,
    this.serviceFeeAmount,
    this.deliveryFeeAmount,
    this.roundingAmount,
    this.otherAmount,
    this.otherLabel,
  });

  final String? signatureId;
  final String? customerName;
  final String? customerContact;
  final List<SaleItemInput>? items;
  final SaleStatus? status;
  final double? discountAmount;
  final double? vatAmount;
  final double? serviceFeeAmount;
  final double? deliveryFeeAmount;
  final double? roundingAmount;
  final double? otherAmount;
  final String? otherLabel;

  Map<String, dynamic> toJson() => {
    'signature_id': signatureId == null ? null : int.tryParse(signatureId!),
    'customer_name': customerName,
    'customer_contact': customerContact,
    'items': items?.map((e) => e.toJson()).toList(),
    'status': status?.name,
    'discount_amount': discountAmount,
    'vat_amount': vatAmount,
    'service_fee_amount': serviceFeeAmount,
    'delivery_fee_amount': deliveryFeeAmount,
    'rounding_amount': roundingAmount,
    'other_amount': otherAmount,
    'other_label': otherLabel,
  };
}

class SaleItem {
  SaleItem({
    required this.id,
    required this.saleId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String id;
  final String saleId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  factory SaleItem.fromJson(dynamic json) {
    return SaleItem(
      id: json['id'].toString(),
      saleId: json['sale_id'].toString(),
      productName: json['product_name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      lineTotal: (json['line_total'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sale_id': saleId,
    'product_name': productName,
    'quantity': quantity,
    'unit_price': unitPrice,
    'line_total': lineTotal,
  };
}

class Sale {
  Sale({
    required this.id,
    required this.shopId,
    this.signatureId,
    required this.status,
    this.customerName,
    this.customerContact,
    required this.subtotal,
    required this.discountAmount,
    required this.vatAmount,
    required this.serviceFeeAmount,
    required this.deliveryFeeAmount,
    required this.roundingAmount,
    required this.otherAmount,
    required this.otherLabel,
    required this.total,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final String shopId;
  final String? signatureId;
  final SaleStatus status;
  final String? customerName;
  final String? customerContact;
  final double subtotal;
  final double discountAmount;
  final double vatAmount;
  final double serviceFeeAmount;
  final double deliveryFeeAmount;
  final double roundingAmount;
  final double otherAmount;
  final String otherLabel;
  final double total;
  final String createdAt;
  final List<SaleItem> items;

  bool get isInvoice => status == SaleStatus.invoice;
  bool get isPaidReceipt => status == SaleStatus.paid;
  String get numberPrefix => isInvoice ? 'INV' : 'REC';
  String get documentTitle => isInvoice ? 'Invoice' : 'E-Receipt';
  String get createActionLabel =>
      isInvoice ? 'Create Invoice' : 'Create Sale & Receipt';

  factory Sale.fromJson(dynamic json) {
    return Sale(
      id: json['id'].toString(),
      shopId: json['shop_id'].toString(),
      signatureId: json['signature_id']?.toString(),
      status: _saleStatusFromJson(json),
      customerName: json['customer_name'] as String?,
      customerContact: json['customer_contact'] as String?,
      subtotal: ((json['subtotal'] ?? json['total']) as num).toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      vatAmount:
          ((json['vat_amount'] ?? json['tax_amount']) as num?)?.toDouble() ?? 0,
      serviceFeeAmount: (json['service_fee_amount'] as num?)?.toDouble() ?? 0,
      deliveryFeeAmount: (json['delivery_fee_amount'] as num?)?.toDouble() ?? 0,
      roundingAmount: (json['rounding_amount'] as num?)?.toDouble() ?? 0,
      otherAmount: (json['other_amount'] as num?)?.toDouble() ?? 0,
      otherLabel: (json['other_label'] as String?)?.trim().isNotEmpty == true
          ? (json['other_label'] as String).trim()
          : 'Others',
      total: (json['total'] as num).toDouble(),
      createdAt: json['created_at'] as String,
      items: (json['items'] as List).map((e) => SaleItem.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'shop_id': shopId,
    'signature_id': signatureId,
    'status': status.name,
    'customer_name': customerName,
    'customer_contact': customerContact,
    'subtotal': subtotal,
    'discount_amount': discountAmount,
    'vat_amount': vatAmount,
    'service_fee_amount': serviceFeeAmount,
    'delivery_fee_amount': deliveryFeeAmount,
    'rounding_amount': roundingAmount,
    'other_amount': otherAmount,
    'other_label': otherLabel,
    'total': total,
    'created_at': createdAt,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

class ReceiptCreateInput {
  ReceiptCreateInput({required this.saleId, this.signatureId});

  final String saleId;
  final String? signatureId;

  Map<String, dynamic> toJson() => {
    'sale_id': saleId,
    'signature_id': signatureId,
  };
}

class ReceiptItem {
  ReceiptItem({
    required this.id,
    required this.saleId,
    required this.shopId,
    required this.signatureId,
    required this.createdAt,
  });

  final String id;
  final String saleId;
  final String shopId;
  final String? signatureId;
  final String createdAt;

  factory ReceiptItem.fromJson(dynamic json) {
    return ReceiptItem(
      id: json['id'].toString(),
      saleId: json['sale_id'].toString(),
      shopId: json['shop_id'].toString(),
      signatureId: json['signature_id']?.toString(),
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sale_id': saleId,
    'shop_id': shopId,
    'signature_id': signatureId,
    'created_at': createdAt,
  };
}

class Receipt {
  Receipt({
    required this.id,
    required this.saleId,
    required this.shopId,
    required this.signatureId,
    required this.createdAt,
  });

  final String id;
  final String saleId;
  final String shopId;
  final String? signatureId;
  final String createdAt;

  factory Receipt.fromJson(dynamic json) {
    return Receipt(
      id: json['id'].toString(),
      saleId: json['sale_id'].toString(),
      shopId: json['shop_id'].toString(),
      signatureId: json['signature_id']?.toString(),
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sale_id': saleId,
    'shop_id': shopId,
    'signature_id': signatureId,
    'created_at': createdAt,
  };
}

class ReceiptDetail {
  ReceiptDetail({
    required this.receipt,
    required this.shop,
    required this.sale,
    required this.signature,
  });

  final Receipt receipt;
  final ShopProfile shop;
  final Sale sale;
  final SignatureItem? signature;

  factory ReceiptDetail.fromJson(dynamic json) {
    return ReceiptDetail(
      receipt: Receipt.fromJson(json['receipt']),
      shop: ShopProfile.fromJson(json['shop']),
      sale: Sale.fromJson(json['sale']),
      signature: json['signature'] == null
          ? null
          : SignatureItem.fromJson(json['signature']),
    );
  }

  Map<String, dynamic> toJson() => {
    'receipt': receipt.toJson(),
    'shop': shop.toJson(),
    'sale': sale.toJson(),
    'signature': signature?.toJson(),
  };
}
