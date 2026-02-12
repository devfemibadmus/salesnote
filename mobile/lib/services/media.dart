import '../app/config.dart';
import 'cache/local.dart';

class MediaService {
  static String resolveSrc(String src, {bool withCacheBust = true}) {
    final trimmed = src.trim();
    if (trimmed.isEmpty) return trimmed;

    final uri = _toUri(trimmed);
    if (uri == null) return trimmed;
    if (!withCacheBust) return uri.toString();

    final bust = LocalCache.getShopLogoCacheBust();
    if (bust <= 0) return uri.toString();
    final nextQuery = Map<String, String>.from(uri.queryParameters)
      ..['cb'] = bust.toString();
    return uri.replace(queryParameters: nextQuery).toString();
  }

  static Uri? _toUri(String src) {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Uri.tryParse(src);
    }
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    final path = src.startsWith('/') ? src.substring(1) : src;
    return Uri.tryParse('$base/$path');
  }
}
