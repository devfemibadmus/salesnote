part of '../models.dart';

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
