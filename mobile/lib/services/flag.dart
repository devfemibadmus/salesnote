import 'dart:developer' as developer;

import 'package:country_picker/country_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'media.dart';

class FlagService {
  FlagService._();

  static const _cacheVersionKey = 'flag_cache_version';
  static const _cacheVersion = 1;
  static const _iconSize = '72x54';

  static String iconUrl(String countryCode, {String size = _iconSize}) {
    final code = countryCode.trim().toLowerCase();
    return 'https://flagpedia.net/data/flags/icon/$size/$code.png';
  }

  static Future<void> warmAllFlags() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_cacheVersionKey) ?? 0;
    if (storedVersion == _cacheVersion) {
      developer.log('flag cache already warm', name: 'SalesnoteBootstrap');
      return;
    }

    final countries = CountryService().getAll();
    final urls = countries.map((country) => iconUrl(country.countryCode)).toList();
    developer.log(
      'warming ${urls.length} flags',
      name: 'SalesnoteBootstrap',
    );
    final warmedCount = await MediaService.warmImages(urls).timeout(
      const Duration(seconds: 20),
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
