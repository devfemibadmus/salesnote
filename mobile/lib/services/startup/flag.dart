import 'dart:convert';
import 'dart:developer' as developer;

import 'package:country_picker/country_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/constants/runtime.dart';
import '../../app/constants/storage.dart';
import '../../app/config.dart';
import '../cache/local.dart';
import '../media.dart';

class FlagService {
  FlagService._();

  static const _cacheVersionKey = StorageKeys.flagCacheVersion;
  static const _cacheVersion = StorageVersions.flagCache;
  static final _fallbackFlagBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WnR6QAAAABJRU5ErkJggg==',
  );

  static void _log(String message, {int level = 0}) {
    developer.log(message, name: 'SalesnoteBootstrap', level: level);
    debugPrint('SalesnoteBootstrap: $message');
  }

  static String iconUrl(
    String countryCode, {
    String size = AppConfig.defaultFlagIconSize,
  }) {
    return AppConfig.flagIconUrl(countryCode, size: size);
  }

  static Future<bool> warmAllFlags() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_cacheVersionKey) ?? 0;
    if (storedVersion == _cacheVersion) {
      _log('flag cache already warm version=$_cacheVersion');
      return true;
    }

    final countries = CountryService().getAll();
    final urls = countries
        .map((country) => iconUrl(country.countryCode))
        .toSet()
        .toList(growable: false);
    if (urls.isEmpty) {
      _log('flag warm skipped: no country URLs');
      return true;
    }
    final cachedUrls = urls
        .where(
          (url) => (MediaService.loadCachedBytes(url)?.isNotEmpty ?? false),
        )
        .toList(growable: false);
    final cachedUrlSet = cachedUrls.toSet();
    final missingUrls = urls
        .where((url) => !cachedUrlSet.contains(url))
        .toList(growable: false);
    if (missingUrls.isEmpty) {
      _log(
        'flag warm already satisfied from cache total=${urls.length} version=$_cacheVersion',
      );
      await prefs.setInt(_cacheVersionKey, _cacheVersion);
      return true;
    }
    _log(
      'warming ${missingUrls.length}/${urls.length} uncached flags '
      'cached=${cachedUrls.length} storedVersion=$storedVersion expectedVersion=$_cacheVersion',
    );
    final flagWarmResult = await _warmFlagsDetailed(missingUrls).timeout(
      TimingConstants.startupFlagWarmTimeout,
      onTimeout: () {
        _log('flag warm timed out', level: 900);
        return const _FlagWarmResult(
          warmedCount: 0,
          failedUrls: <String>[],
          fallbackUrls: <String>[],
          timedOut: true,
        );
      },
    );
    final totalReadyCount = cachedUrls.length + flagWarmResult.warmedCount;
    _log(
      'flag warm newlyWarmed=${flagWarmResult.warmedCount}/${missingUrls.length}',
    );
    if (flagWarmResult.failedUrls.isNotEmpty) {
      _log(
        'flag warm failedUrlsSample=${flagWarmResult.failedUrls.take(5).join(', ')}',
        level: 900,
      );
    }
    if (flagWarmResult.fallbackUrls.isNotEmpty) {
      _log(
        'flag warm fallbackUrlsSample=${flagWarmResult.fallbackUrls.take(5).join(', ')}',
        level: 900,
      );
    }
    if (flagWarmResult.timedOut) {
      _log('flag warm incomplete due to timeout', level: 900);
    }
    _log(
      'flag warm progress totalReady=$totalReadyCount/${urls.length} '
      'newlyWarmed=${flagWarmResult.warmedCount} cached=${cachedUrls.length}',
    );
    if (totalReadyCount == urls.length) {
      await prefs.setInt(_cacheVersionKey, _cacheVersion);
      return true;
    }
    return false;
  }

  static Future<_FlagWarmResult> _warmFlagsDetailed(List<String> urls) async {
    final uniqueUrls = urls.toSet().toList(growable: false);
    final failedUrls = <String>[];
    final fallbackUrls = <String>[];
    var warmedCount = 0;
    var cursor = 0;

    Future<void> worker() async {
      while (true) {
        if (cursor >= uniqueUrls.length) {
          return;
        }
        final currentIndex = cursor;
        cursor += 1;
        final url = uniqueUrls[currentIndex];
        final warmed = await MediaService.warmImage(url);
        if (warmed) {
          warmedCount += 1;
        } else {
          await LocalCache.saveCachedMedia(url, _fallbackFlagBytes);
          warmedCount += 1;
          failedUrls.add(url);
          fallbackUrls.add(url);
        }
      }
    }

    final workers = List.generate(6, (_) => worker());
    await Future.wait(workers);
    return _FlagWarmResult(
      warmedCount: warmedCount,
      failedUrls: failedUrls,
      fallbackUrls: fallbackUrls,
      timedOut: false,
    );
  }
}

class _FlagWarmResult {
  const _FlagWarmResult({
    required this.warmedCount,
    required this.failedUrls,
    required this.fallbackUrls,
    required this.timedOut,
  });

  final int warmedCount;
  final List<String> failedUrls;
  final List<String> fallbackUrls;
  final bool timedOut;
}
