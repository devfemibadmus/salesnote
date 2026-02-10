import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoData {
  DeviceInfoData({this.name, this.platform, this.os});

  final String? name;
  final String? platform;
  final String? os;

  Map<String, dynamic> toJson() => {
        'name': name,
        'platform': platform,
        'os': os,
      };

  static DeviceInfoData fromJson(Map<String, dynamic> json) {
    return DeviceInfoData(
      name: json['name']?.toString(),
      platform: json['platform']?.toString(),
      os: json['os']?.toString(),
    );
  }
}

class DeviceInfoService {
  DeviceInfoService._();

  static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

  static Future<DeviceInfoData> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        final brand = info.brand;
        final model = info.model;
        final name = _join([brand, model]) ?? 'Android';
        final os = _join(['Android', info.version.release]) ?? 'Android';
        return DeviceInfoData(name: name, platform: 'Android', os: os);
      }

      if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        final name = _join([info.name, info.model]) ?? 'iOS';
        final os = _join(['iOS', info.systemVersion]) ?? 'iOS';
        return DeviceInfoData(name: name, platform: 'iOS', os: os);
      }

      if (Platform.isMacOS) {
        final info = await _plugin.macOsInfo;
        final name = _join([info.computerName, info.model]) ?? 'macOS';
        final os = _join(['macOS', info.osRelease]) ?? 'macOS';
        return DeviceInfoData(name: name, platform: 'macOS', os: os);
      }

      if (Platform.isWindows) {
        final info = await _plugin.windowsInfo;
        final name = info.computerName.isEmpty ? 'Windows' : info.computerName;
        final os = _join(['Windows', info.displayVersion]) ?? 'Windows';
        return DeviceInfoData(name: name, platform: 'Windows', os: os);
      }

      if (Platform.isLinux) {
        final info = await _plugin.linuxInfo;
        final name = info.prettyName.isEmpty ? 'Linux' : info.prettyName;
        final versionId = info.versionId;
        final os = (versionId == null || versionId.isEmpty) ? 'Linux' : versionId;
        return DeviceInfoData(name: name, platform: 'Linux', os: os);
      }
    } catch (_) {}

    final fallbackPlatform = Platform.operatingSystem;
    final fallbackOs = Platform.operatingSystemVersion;
    return DeviceInfoData(
      name: fallbackPlatform,
      platform: fallbackPlatform,
      os: fallbackOs,
    );
  }

  static String? _join(List<String?> parts) {
    final items = parts
        .where((p) => p?.trim().isNotEmpty ?? false)
        .whereType<String>()
        .toList();
    if (items.isEmpty) return null;
    return items.join(' ');
  }
}
