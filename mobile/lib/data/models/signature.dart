part of '../models.dart';

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
