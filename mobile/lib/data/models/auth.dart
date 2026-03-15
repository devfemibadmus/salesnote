part of '../models.dart';

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
