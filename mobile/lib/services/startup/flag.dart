import 'dart:developer' as developer;

import 'package:country_picker/country_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/constants/runtime.dart';
import '../../app/constants/storage.dart';
import '../../app/config.dart';
import '../media.dart';

class FlagService {
  FlagService._();

  static const _cacheVersionKey = StorageKeys.flagCacheVersion;
  static const _cacheVersion = StorageVersions.flagCache;

  static String iconUrl(
    String countryCode, {
    String size = AppConfig.defaultFlagIconSize,
  }) {
    return AppConfig.flagIconUrl(countryCode, size: size);
  }

  static Future<void> warmAllFlags() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_cacheVersionKey) ?? 0;
    if (storedVersion == _cacheVersion) {
      developer.log('flag cache already warm', name: 'SalesnoteBootstrap');
      return;
    }

    final countries = CountryService().getAll();
    final urls = countries
        .map((country) => iconUrl(country.countryCode))
        .toList();
    developer.log('warming ${urls.length} flags', name: 'SalesnoteBootstrap');
    final warmedCount = await MediaService.warmImages(urls).timeout(
      TimingConstants.startupFlagWarmTimeout,
      onTimeout: () {
        developer.log(
          'flag warm timed out',
          name: 'SalesnoteBootstrap',
          level: 900,
        );
        return 0;
      },
    );
    developer.log(
      'warmed $warmedCount/${urls.length} flags',
      name: 'SalesnoteBootstrap',
    );
    if (warmedCount == urls.length) {
      await prefs.setInt(_cacheVersionKey, _cacheVersion);
    }
  }
}
