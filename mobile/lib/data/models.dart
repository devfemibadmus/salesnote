class RegisterInput {
  RegisterInput({
    required this.shopName,
    required this.phone,
    required this.currencyCode,
    required this.email,
    required this.password,
    required this.timezone,
    this.address,
    this.logoUrl,
  });

  final String shopName;
  final String phone;
  final String currencyCode;
  final String email;
  final String password;
  final String timezone;
  final String? address;
  final String? logoUrl;

  Map<String, dynamic> toJson() => {
    'shop_name': shopName,
    'phone': phone,
    'email': email,
    'password': password,
    'timezone': timezone,
    'address': address,
    'logo_url': logoUrl,
  };
}

class ShopUpdateInput {
  ShopUpdateInput({
    this.name,
    this.phone,
    this.email,
    this.address,
    this.logoUrl,
    this.password,
    this.bankAccounts,
  });

  final String? name;
  final String? phone;
  final String? email;
  final String? address;
  final String? logoUrl;
  final String? password;
  final List<ShopBankAccount>? bankAccounts;

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'logo_url': logoUrl,
    'password': password,
    'bank_accounts': bankAccounts?.map((e) => e.toJson()).toList(),
  };
}

class ShopBankAccount {
  ShopBankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });

  final String id;
  final String bankName;
  final String accountNumber;
  final String accountName;

  factory ShopBankAccount.fromJson(dynamic json) {
    return ShopBankAccount(
      id: json['id'].toString(),
      bankName: (json['bank_name'] as String? ?? '').trim(),
      accountNumber: (json['account_number'] as String? ?? '').trim(),
      accountName: (json['account_name'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': int.tryParse(id),
    'bank_name': bankName,
    'account_number': accountNumber,
    'account_name': accountName,
  };
}

class ShopProfile {
  ShopProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.currencyCode,
    required this.liveAgentTokensUsed,
    required this.liveAgentTokensAvailable,
    required this.email,
    this.address,
    this.logoUrl,
    required this.timezone,
    required this.createdAt,
    this.bankAccounts = const <ShopBankAccount>[],
  });

  final String id;
  final String name;
  final String phone;
  final String currencyCode;
  final int liveAgentTokensUsed;
  final int liveAgentTokensAvailable;
  final String email;
  final String? address;
  final String? logoUrl;
  final String timezone;
  final String createdAt;
  final List<ShopBankAccount> bankAccounts;

  factory ShopProfile.fromJson(dynamic json) {
    final rawCurrencyCode = json['currency_code']?.toString().trim();
    if (rawCurrencyCode == null || rawCurrencyCode.isEmpty) {
      throw const FormatException('Missing shop currency_code.');
    }

    return ShopProfile(
      id: json['id'].toString(),
      name: json['name'] as String,
      phone: json['phone'] as String,
      currencyCode: rawCurrencyCode.toUpperCase(),
      liveAgentTokensUsed:
          (json['live_agent_tokens_used'] as num?)?.toInt() ?? 0,
      liveAgentTokensAvailable:
          (json['live_agent_tokens_available'] as num?)?.toInt() ?? 3000000,
      email: json['email'] as String,
      address: json['address'] as String?,
      logoUrl: json['logo_url'] as String?,
      timezone: json['timezone'] as String? ?? 'UTC',
      createdAt: json['created_at'] as String,
      bankAccounts: (json['bank_accounts'] as List<dynamic>? ?? const [])
          .map(ShopBankAccount.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'currency_code': currencyCode,
    'live_agent_tokens_used': liveAgentTokensUsed,
    'live_agent_tokens_available': liveAgentTokensAvailable,
    'email': email,
    'address': address,
    'logo_url': logoUrl,
    'timezone': timezone,
    'created_at': createdAt,
    'bank_accounts': bankAccounts.map((e) => e.toJson()).toList(),
  };
}

class AuthResult {
  AuthResult({required this.accessToken, required this.shop});

  final String accessToken;
  final ShopProfile shop;

  factory AuthResult.fromJson(dynamic json) {
    return AuthResult(
      accessToken: json['access_token'] as String,
      shop: ShopProfile.fromJson(json['shop']),
    );
  }
}

class SignatureInput {
  SignatureInput({required this.name, required this.imageUrl});

  final String name;
  final String imageUrl;

  Map<String, dynamic> toJson() => {'name': name, 'image_url': imageUrl};
}

class SignatureItem {
  SignatureItem({
    required this.id,
    required this.shopId,
    required this.name,
    required this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String shopId;
  final String name;
  final String imageUrl;
  final String createdAt;

  factory SignatureItem.fromJson(dynamic json) {
    return SignatureItem(
      id: json['id'].toString(),
      shopId: json['shop_id'].toString(),
      name: json['name'] as String,
      imageUrl: json['image_url'] as String,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'shop_id': shopId,
    'name': name,
    'image_url': imageUrl,
    'created_at': createdAt,
  };
}

class SuggestionInput {
  SuggestionInput({required this.key, required this.value});

  final String key;
  final String value;

  Map<String, dynamic> toJson() => {'key': key, 'value': value};
}

class SuggestionItem {
  SuggestionItem({
    required this.id,
    required this.shopId,
    required this.key,
    required this.value,
    required this.usageCount,
    required this.lastUsedAt,
    required this.createdAt,
  });

  final String id;
  final String shopId;
  final String key;
  final String value;
  final int usageCount;
  final String lastUsedAt;
  final String createdAt;

  factory SuggestionItem.fromJson(dynamic json) {
    return SuggestionItem(
      id: json['id'].toString(),
      shopId: json['shop_id'].toString(),
      key: json['key'] as String,
      value: json['value'] as String,
      usageCount: json['usage_count'] as int,
      lastUsedAt: json['last_used_at'] as String,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'shop_id': shopId,
    'key': key,
    'value': value,
    'usage_count': usageCount,
    'last_used_at': lastUsedAt,
    'created_at': createdAt,
  };
}

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
  final raw = (json['status'] ??
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

class AnalyticsPoint {
  AnalyticsPoint({
    required this.period,
    required this.total,
    required this.units,
  });

  final String period;
  final double total;
  final double units;

  factory AnalyticsPoint.fromJson(dynamic json) {
    return AnalyticsPoint(
      period: json['period'] as String,
      total: (json['total'] as num).toDouble(),
      units: (json['units'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'period': period,
    'total': total,
    'units': units,
  };
}

class ProductMovement {
  ProductMovement({
    required this.productName,
    required this.quantity,
    required this.sold30Days,
  });

  final String productName;
  final double quantity;
  final double sold30Days;

  factory ProductMovement.fromJson(dynamic json) {
    final quantity = (json['quantity'] as num).toDouble();
    return ProductMovement(
      productName: json['product_name'] as String,
      quantity: quantity,
      sold30Days: (json['sold_30_days'] as num?)?.toDouble() ?? quantity,
    );
  }

  Map<String, dynamic> toJson() => {
    'product_name': productName,
    'quantity': quantity,
    'sold_30_days': sold30Days,
  };
}

class AnalyticsSummary {
  AnalyticsSummary({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.fastMoving,
    required this.slowMoving,
  });

  final List<AnalyticsPoint> daily;
  final List<AnalyticsPoint> weekly;
  final List<AnalyticsPoint> monthly;
  final List<ProductMovement> fastMoving;
  final List<ProductMovement> slowMoving;

  factory AnalyticsSummary.fromJson(dynamic json) {
    return AnalyticsSummary(
      daily: (json['daily'] as List)
          .map((e) => AnalyticsPoint.fromJson(e))
          .toList(),
      weekly: (json['weekly'] as List)
          .map((e) => AnalyticsPoint.fromJson(e))
          .toList(),
      monthly: (json['monthly'] as List)
          .map((e) => AnalyticsPoint.fromJson(e))
          .toList(),
      fastMoving: (json['fast_moving'] as List)
          .map((e) => ProductMovement.fromJson(e))
          .toList(),
      slowMoving: (json['slow_moving'] as List)
          .map((e) => ProductMovement.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'daily': daily.map((e) => e.toJson()).toList(),
    'weekly': weekly.map((e) => e.toJson()).toList(),
    'monthly': monthly.map((e) => e.toJson()).toList(),
    'fast_moving': fastMoving.map((e) => e.toJson()).toList(),
    'slow_moving': slowMoving.map((e) => e.toJson()).toList(),
  };
}

class HomeSummary {
  HomeSummary({
    required this.shop,
    required this.analytics,
    required this.recentSales,
  });

  final ShopProfile shop;
  final AnalyticsSummary analytics;
  final List<Sale> recentSales;

  factory HomeSummary.fromJson(dynamic json) {
    return HomeSummary(
      shop: ShopProfile.fromJson(json['shop']),
      analytics: AnalyticsSummary.fromJson(json['analytics']),
      recentSales: (json['recent_sales'] as List)
          .map((e) => Sale.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'shop': shop.toJson(),
    'analytics': analytics.toJson(),
    'recent_sales': recentSales.map((e) => e.toJson()).toList(),
  };
}

class DeviceSession {
  DeviceSession({
    required this.id,
    required this.shopId,
    this.deviceName,
    this.devicePlatform,
    this.deviceOs,
    this.ipAddress,
    this.location,
    this.userAgent,
    this.fcmToken,
    this.createdAt,
    this.lastSeenAt,
    this.deletedAt,
  });

  final String id;
  final String shopId;
  final String? deviceName;
  final String? devicePlatform;
  final String? deviceOs;
  final String? ipAddress;
  final String? location;
  final String? userAgent;
  final String? fcmToken;
  final String? createdAt;
  final String? lastSeenAt;
  final String? deletedAt;

  factory DeviceSession.fromJson(dynamic json) {
    return DeviceSession(
      id: json['id'].toString(),
      shopId: json['shop_id'].toString(),
      deviceName: json['device_name'] as String?,
      devicePlatform: json['device_platform'] as String?,
      deviceOs: json['device_os'] as String?,
      ipAddress: json['ip_address'] as String?,
      location: json['location'] as String?,
      userAgent: json['user_agent'] as String?,
      fcmToken: json['fcm_token'] as String?,
      createdAt: json['created_at'] as String?,
      lastSeenAt: json['last_seen_at'] as String?,
      deletedAt: json['deleted_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'shop_id': shopId,
    'device_name': deviceName,
    'device_platform': devicePlatform,
    'device_os': deviceOs,
    'ip_address': ipAddress,
    'location': location,
    'user_agent': userAgent,
    'fcm_token': fcmToken,
    'created_at': createdAt,
    'last_seen_at': lastSeenAt,
    'deleted_at': deletedAt,
  };
}

class SettingsSummary {
  SettingsSummary({
    required this.shop,
    required this.devices,
    required this.currentDevicePushEnabled,
  });

  final ShopProfile shop;
  final List<DeviceSession> devices;
  final bool currentDevicePushEnabled;

  factory SettingsSummary.fromJson(dynamic json) {
    return SettingsSummary(
      shop: ShopProfile.fromJson(json['shop']),
      devices: (json['devices'] as List)
          .map((e) => DeviceSession.fromJson(e))
          .toList(),
      currentDevicePushEnabled: json['current_device_push_enabled'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'shop': shop.toJson(),
    'devices': devices.map((e) => e.toJson()).toList(),
    'current_device_push_enabled': currentDevicePushEnabled,
  };
}
