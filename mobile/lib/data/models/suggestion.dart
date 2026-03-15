part of '../models.dart';

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
