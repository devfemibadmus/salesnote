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
        final os = info.version.release.trim().isEmpty
            ? 'Unknown version'
            : info.version.release;
        return DeviceInfoData(name: name, platform: 'Android', os: os);
      }

      if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        final machine = info.utsname.machine;
        final model = _mapIosMachineId(machine);
        
        // If the user's custom name is generic "iPhone" and we have a specific model,
        // use the specific model name instead.
        final rawName = info.name;
        final name = (rawName == 'iPhone' || rawName.isEmpty) 
            ? model 
            : _join([rawName, model]) ?? model;
            
        final os = info.systemVersion.trim().isEmpty
            ? 'Unknown version'
            : info.systemVersion;
        return DeviceInfoData(name: name, platform: 'iOS', os: os);
      }

      if (Platform.isMacOS) {
        final info = await _plugin.macOsInfo;
        final name = _join([info.computerName, info.model]) ?? 'macOS';
        final os = info.osRelease.trim().isEmpty
            ? 'Unknown version'
            : info.osRelease;
        return DeviceInfoData(name: name, platform: 'macOS', os: os);
      }

      if (Platform.isWindows) {
        final info = await _plugin.windowsInfo;
        final name = info.computerName.isEmpty ? 'Windows' : info.computerName;
        final os = info.displayVersion.trim().isEmpty
            ? 'Unknown version'
            : info.displayVersion;
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

  static String _mapIosMachineId(String machine) {
    const Map<String, String> mapping = {
      // iPhone
      'iPhone8,1': 'iPhone 6s',
      'iPhone8,2': 'iPhone 6s Plus',
      'iPhone8,4': 'iPhone SE (1st Gen)',
      'iPhone9,1': 'iPhone 7',
      'iPhone9,3': 'iPhone 7',
      'iPhone9,2': 'iPhone 7 Plus',
      'iPhone9,4': 'iPhone 7 Plus',
      'iPhone10,1': 'iPhone 8',
      'iPhone10,4': 'iPhone 8',
      'iPhone10,2': 'iPhone 8 Plus',
      'iPhone10,5': 'iPhone 8 Plus',
      'iPhone10,3': 'iPhone X',
      'iPhone10,6': 'iPhone X',
      'iPhone11,2': 'iPhone XS',
      'iPhone11,4': 'iPhone XS Max',
      'iPhone11,6': 'iPhone XS Max',
      'iPhone11,8': 'iPhone XR',
      'iPhone12,1': 'iPhone 11',
      'iPhone12,3': 'iPhone 11 Pro',
      'iPhone12,5': 'iPhone 11 Pro Max',
      'iPhone12,8': 'iPhone SE (2nd Gen)',
      'iPhone13,1': 'iPhone 12 mini',
      'iPhone13,2': 'iPhone 12',
      'iPhone13,3': 'iPhone 12 Pro',
      'iPhone13,4': 'iPhone 12 Pro Max',
      'iPhone14,4': 'iPhone 13 mini',
      'iPhone14,5': 'iPhone 13',
      'iPhone14,2': 'iPhone 13 Pro',
      'iPhone14,3': 'iPhone 13 Pro Max',
      'iPhone14,6': 'iPhone SE (3rd Gen)',
      'iPhone14,7': 'iPhone 14',
      'iPhone14,8': 'iPhone 14 Plus',
      'iPhone15,2': 'iPhone 14 Pro',
      'iPhone15,3': 'iPhone 14 Pro Max',
      'iPhone15,4': 'iPhone 15',
      'iPhone15,5': 'iPhone 15 Plus',
      'iPhone16,1': 'iPhone 15 Pro',
      'iPhone16,2': 'iPhone 15 Pro Max',
      'iPhone17,1': 'iPhone 16 Pro',
      'iPhone17,2': 'iPhone 16 Pro Max',
      'iPhone17,3': 'iPhone 16',
      'iPhone17,4': 'iPhone 16 Plus',
      // Simulator
      'i386': 'Simulator',
      'x86_64': 'Simulator',
      'arm64': 'Simulator',
    };

    if (mapping.containsKey(machine)) {
      return mapping[machine]!;
    }

    // Fallback logic
    if (machine.startsWith('iPhone')) return 'iPhone';
    if (machine.startsWith('iPad')) return 'iPad';
    if (machine.startsWith('iPod')) return 'iPod';
    if (machine.startsWith('Watch')) return 'Apple Watch';
    if (machine.startsWith('AppleTV')) return 'Apple TV';

    return machine;
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
