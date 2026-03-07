import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app/config.dart';
import 'cache/local.dart';

class MediaService {
  static String resolveSrc(String src, {bool withCacheBust = true}) {
    final trimmed = src.trim();
    if (trimmed.isEmpty) return trimmed;

    final uri = _toCanonicalUri(trimmed);
    if (uri == null) return trimmed;
    if (!withCacheBust) return uri.toString();

    final bust = LocalCache.getShopLogoCacheBust();
    if (bust <= 0) return uri.toString();
    final nextQuery = Map<String, String>.from(uri.queryParameters)
      ..['cb'] = bust.toString();
    return uri.replace(queryParameters: nextQuery).toString();
  }

  static String? canonicalUrl(String? src) {
    final trimmed = (src ?? '').trim();
    if (trimmed.isEmpty) return null;
    return _toCanonicalUri(trimmed)?.toString();
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

  static Future<void> warmImage(String? src) async {
    final key = canonicalUrl(src);
    if (key == null || key.isEmpty) return;

    final url = resolveSrc(src!, withCacheBust: false);
    if (url.isEmpty) return;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      if (response.bodyBytes.isEmpty) return;
      await LocalCache.saveCachedMedia(key, response.bodyBytes);
    } catch (_) {}
  }

  static Future<void> warmImages(Iterable<String?> sources) async {
    final seen = <String>{};
    for (final src in sources) {
      final key = canonicalUrl(src);
      if (key == null || !seen.add(key)) continue;
      await warmImage(src);
    }
  }

  static Uri? _toCanonicalUri(String src) {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      final uri = Uri.tryParse(src);
      return _stripCacheBust(uri);
    }
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    final path = src.startsWith('/') ? src.substring(1) : src;
    final uri = Uri.tryParse('$base/$path');
    return _stripCacheBust(uri);
  }

  static Uri? _stripCacheBust(Uri? uri) {
    if (uri == null) return null;
    if (!uri.queryParameters.containsKey('cb')) return uri;
    final nextQuery = Map<String, String>.from(uri.queryParameters)
      ..remove('cb');
    return uri.replace(queryParameters: nextQuery.isEmpty ? null : nextQuery);
  }
}
