import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../app/constants/runtime.dart';
import 'flag.dart';
import 'cues.dart';

class StartupWarmupService {
  StartupWarmupService._();

  static void _log(String message, {int level = 0}) {
    developer.log(message, name: 'SalesnoteBootstrap', level: level);
    debugPrint('SalesnoteBootstrap: $message');
  }

  static Future<void> ensureReady() async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      final stopwatch = Stopwatch()..start();
      _log('startup:warmup:attempt $attempt');
      final results = await Future.wait<bool>([
        FlagService.warmAllFlags(),
        LiveCashierCueService.warmAllCues(),
      ]);
      final flagsReady = results[0];
      final cuesReady = results[1];
      _log(
        'startup:warmup:result attempt=$attempt '
        'flagsReady=$flagsReady cuesReady=$cuesReady '
        'elapsed=${stopwatch.elapsedMilliseconds}ms',
      );
      if (flagsReady && cuesReady) {
        _log('startup:warmup:ready on attempt $attempt');
        return;
      }
      _log(
        'startup:warmup:retrying after failed attempt $attempt '
        '(flagsReady=$flagsReady cuesReady=$cuesReady) '
        'in ${TimingConstants.startupWarmRetryDelay.inSeconds}s',
        level: 900,
      );
      await Future<void>.delayed(TimingConstants.startupWarmRetryDelay);
    }
  }
}
