import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart' as fs;
import 'package:http/http.dart' as http;

import '../../app/constants/runtime.dart';
import '../../app/config.dart';
import '../cache/local.dart';

enum LiveCashierCue {
  actionStarted,
  reconnecting,
  reconnected,
  sessionClosed,
  micMuted,
  micUnmuted,
}

class LiveCashierCueService {
  LiveCashierCueService._();

  static final http.Client _client = http.Client();
  static final fs.FlutterSoundPlayer _player = fs.FlutterSoundPlayer();
  static Future<void>? _playerInitFuture;
  static final Map<String, Future<Uint8List?>> _loadFutures =
      <String, Future<Uint8List?>>{};
  static final Map<LiveCashierCue, DateTime> _lastPlayedAt =
      <LiveCashierCue, DateTime>{};
  static Future<void> _playQueue = Future<void>.value();

  static const Duration _networkTimeout =
      TimingConstants.liveCashierCueNetworkTimeout;
  static const Duration _actionCooldown =
      TimingConstants.liveCashierCueActionCooldown;
  static const Duration _reconnectingCooldown =
      TimingConstants.liveCashierCueReconnectingCooldown;
  static const Duration _reconnectedCooldown =
      TimingConstants.liveCashierCueReconnectedCooldown;

  static void _log(
    String message, {
    int level = 0,
    String name = 'SalesnoteBootstrap',
  }) {
    developer.log(message, name: name, level: level);
    debugPrint('$name: $message');
  }

  static String _cueKey(LiveCashierCue cue) {
    switch (cue) {
      case LiveCashierCue.actionStarted:
        return 'action_started';
      case LiveCashierCue.reconnecting:
        return 'reconnecting';
      case LiveCashierCue.reconnected:
        return 'reconnected';
      case LiveCashierCue.sessionClosed:
        return 'session_closed';
      case LiveCashierCue.micMuted:
        return 'mic_muted';
      case LiveCashierCue.micUnmuted:
        return 'mic_unmuted';
    }
  }

  static String urlFor(LiveCashierCue cue) =>
      AppConfig.liveCashierCueUrls[_cueKey(cue)] ?? '';

  static Future<bool> warmAllCues() async {
    return _warmCueUrls(AppConfig.liveCashierCueUrls.values);
  }

  static Future<bool> _warmCueUrls(Iterable<String> urls) async {
    final normalizedUrls = urls
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedUrls.isEmpty) {
      _log('cue warm skipped: no cue URLs');
      return true;
    }
    _log('warming ${normalizedUrls.length} live cashier cues');
    final results = await Future.wait<bool>(
      normalizedUrls.map(_cacheCueByUrl),
      eagerError: false,
    );
    final warmedCount = results.where((item) => item).length;
    _log('warmed $warmedCount/${normalizedUrls.length} live cashier cues');
    if (warmedCount != normalizedUrls.length) {
      final failedUrls = <String>[
        for (var index = 0; index < normalizedUrls.length; index++)
          if (!results[index]) normalizedUrls[index],
      ];
      _log('cue warm failedUrls=${failedUrls.join(', ')}', level: 900);
    }
    return warmedCount == normalizedUrls.length;
  }

  static Future<void> playActionStarted() =>
      _queuePlay(LiveCashierCue.actionStarted, cooldown: _actionCooldown);

  static Future<void> playReconnecting() =>
      _queuePlay(LiveCashierCue.reconnecting, cooldown: _reconnectingCooldown);

  static Future<void> playReconnected() =>
      _queuePlay(LiveCashierCue.reconnected, cooldown: _reconnectedCooldown);

  static Future<void> playBootstrapReady() =>
      _queuePlay(LiveCashierCue.reconnected, cooldown: _reconnectedCooldown);

  static Future<void> playSessionClosed() =>
      _queuePlay(LiveCashierCue.sessionClosed, cooldown: _reconnectingCooldown);

  static Future<void> playMicMuted() => _queuePlay(
    LiveCashierCue.micMuted,
    cooldown: TimingConstants.liveCashierCueMicToggleCooldown,
  );

  static Future<void> playMicUnmuted() => _queuePlay(
    LiveCashierCue.micUnmuted,
    cooldown: TimingConstants.liveCashierCueMicToggleCooldown,
  );

  static Future<void> _queuePlay(
    LiveCashierCue cue, {
    required Duration cooldown,
  }) {
    _playQueue = _playQueue.then((_) => _playCue(cue, cooldown: cooldown));
    return _playQueue;
  }

  static Future<void> _playCue(
    LiveCashierCue cue, {
    required Duration cooldown,
  }) async {
    final lastPlayedAt = _lastPlayedAt[cue];
    if (lastPlayedAt != null &&
        DateTime.now().difference(lastPlayedAt) < cooldown) {
      return;
    }
    final url = urlFor(cue);
    if (url.isEmpty) {
      return;
    }
    final bytes = await _loadCueBytes(url);
    if (bytes == null || bytes.isEmpty) {
      return;
    }
    await _ensurePlayerReady();
    try {
      await _player.stopPlayer();
    } catch (_) {}
    try {
      _lastPlayedAt[cue] = DateTime.now();
      await _player.startPlayer(
        fromDataBuffer: bytes,
        codec: fs.Codec.mp3,
        whenFinished: () {},
      );
    } catch (error) {
      developer.log(
        'failed to play live cashier cue $cue: $error',
        name: 'LiveCashierCueService',
        level: 900,
      );
    }
  }

  static Future<void> _ensurePlayerReady() async {
    final existing = _playerInitFuture;
    if (existing != null) {
      await existing;
      return;
    }
    final future = () async {
      await _player.openPlayer();
    }();
    _playerInitFuture = future;
    try {
      await future;
    } finally {
      if (identical(_playerInitFuture, future)) {
        _playerInitFuture = null;
      }
    }
  }

  static Future<Uint8List?> _loadCueBytes(String url) {
    final cached = LocalCache.loadCachedMedia(url);
    if (cached != null && cached.isNotEmpty) {
      return Future<Uint8List?>.value(cached);
    }
    final inFlight = _loadFutures[url];
    if (inFlight != null) {
      return inFlight;
    }
    final future = () async {
      final bytes = await _fetchCueBytes(url);
      if (bytes != null && bytes.isNotEmpty) {
        await LocalCache.saveCachedMedia(url, bytes);
      }
      return bytes;
    }();
    _loadFutures[url] = future;
    future.whenComplete(() => _loadFutures.remove(url));
    return future;
  }

  static Future<bool> _cacheCueByUrl(String url) async {
    final cached = LocalCache.loadCachedMedia(url);
    if (cached != null && cached.isNotEmpty) {
      _log('cue cache hit url=$url');
      return true;
    }
    final bytes = await _fetchCueBytes(url);
    if (bytes == null || bytes.isEmpty) {
      _log('cue cache miss/fetch failed url=$url', level: 900);
      return false;
    }
    await LocalCache.saveCachedMedia(url, bytes);
    _log('cue cached url=$url bytes=${bytes.length}');
    return true;
  }

  static Future<Uint8List?> _fetchCueBytes(String url) async {
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(_networkTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _log(
          'cue fetch bad status url=$url status=${response.statusCode}',
          level: 900,
        );
        return null;
      }
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (contentType.startsWith('audio/') ||
          url.toLowerCase().endsWith('.mp3') ||
          url.toLowerCase().endsWith('.wav') ||
          url.toLowerCase().endsWith('.m4a')) {
        return Uint8List.fromList(response.bodyBytes);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        _log('cue fetch invalid json payload url=$url', level: 900);
        return null;
      }
      final files = (decoded['files'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>();
      for (final file in files) {
        final content = file['content']?.toString() ?? '';
        if (content.trim().isEmpty) {
          continue;
        }
        final match = RegExp(
          r'dataUri:\s*"([^"]+)"',
          dotAll: true,
        ).firstMatch(content);
        if (match == null) {
          continue;
        }
        final dataUri = match.group(1)?.trim() ?? '';
        if (!dataUri.startsWith('data:audio/')) {
          continue;
        }
        final commaIndex = dataUri.indexOf(',');
        if (commaIndex <= 0 || commaIndex >= dataUri.length - 1) {
          continue;
        }
        return base64Decode(dataUri.substring(commaIndex + 1));
      }
      _log('cue fetch found no usable audio file url=$url', level: 900);
    } catch (error) {
      _log(
        'failed to fetch live cashier cue from $url: $error',
        name: 'LiveCashierCueService',
        level: 900,
      );
    }
    return null;
  }
}
