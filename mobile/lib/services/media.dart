import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app/config.dart';
import 'cache/local.dart';

class MediaService {
  static final http.Client _client = http.Client();
  static String resolveSrc(String src, {bool withCacheBust = true}) {
    final trimmed = src.trim();
    if (trimmed.isEmpty) return trimmed;

    final uri = _toFetchUri(trimmed);
    if (uri == null) return trimmed;
    return uri.toString();
  }

  static String? canonicalUrl(String? src) {
    final trimmed = (src ?? '').trim();
    if (trimmed.isEmpty) return null;
    return _toCacheKeyUri(trimmed)?.toString();
  }

  static Uint8List? loadCachedBytes(String? src) {
    final key = canonicalUrl(src);
    if (key == null || key.isEmpty) return null;
    return LocalCache.loadCachedMedia(key);
  }

  static ImageProvider<Object>? imageProvider(
    String? src, {
    bool withCacheBust = true,
  }) {
    final bytes = loadCachedBytes(src);
    if (bytes != null) {
      return MemoryImage(bytes);
    }

    final raw = (src ?? '').trim();
    if (raw.isEmpty) return null;
    final resolved = resolveSrc(raw, withCacheBust: withCacheBust);
    if (resolved.isEmpty) return null;
    return NetworkImage(resolved);
  }

  static Future<bool> warmImage(String? src) async {
    final key = canonicalUrl(src);
    if (key == null || key.isEmpty) return false;

    final url = resolveSrc(src!, withCacheBust: false);
    if (url.isEmpty) return false;

    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      if (response.bodyBytes.isEmpty) return false;
      await LocalCache.saveCachedMedia(key, response.bodyBytes);
      return true;
    } catch (_) {}
    return false;
  }

  static Future<int> warmImages(
    Iterable<String?> sources, {
    int concurrency = 6,
  }) async {
    final seen = <String>{};
    final queue = <String?>[];
    for (final src in sources) {
      final key = canonicalUrl(src);
      if (key == null || !seen.add(key)) {
        continue;
      }
      queue.add(src);
    }

    var successCount = 0;
    var cursor = 0;

    Future<void> worker() async {
      while (true) {
        if (cursor >= queue.length) return;
        final currentIndex = cursor;
        cursor++;
        if (await warmImage(queue[currentIndex])) {
          successCount++;
        }
      }
    }

    final workers = List.generate(
      concurrency.clamp(1, 12),
      (_) => worker(),
    );
    await Future.wait(workers);
    return successCount;
  }

  static Uri? _toFetchUri(String src) {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Uri.tryParse(src);
    }
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    final path = src.startsWith('/') ? src.substring(1) : src;
    return Uri.tryParse('$base/$path');
  }

  static Uri? _toCacheKeyUri(String src) {
    final uri = _toFetchUri(src);
    return _stripVolatileParts(uri);
  }

  static Uri? _stripVolatileParts(Uri? uri) {
    if (uri == null) return null;
    return uri.replace(queryParameters: null, fragment: null);
  }
}
