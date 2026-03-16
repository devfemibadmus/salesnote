import 'dart:async';
import 'dart:developer' as developer;

import '../../app/constants/runtime.dart';
import 'flag.dart';
import 'cues.dart';

class StartupWarmupService {
  StartupWarmupService._();

  static Future<void> ensureReady() async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      developer.log(
        'startup:warmup:attempt $attempt',
        name: 'SalesnoteBootstrap',
      );
      final results = await Future.wait<bool>([
        FlagService.warmAllFlags(),
        LiveCashierCueService.warmAllCues(),
      ]);
      if (results.every((item) => item)) {
        developer.log(
          'startup:warmup:ready on attempt $attempt',
          name: 'SalesnoteBootstrap',
        );
        return;
      }
      developer.log(
        'startup:warmup:retrying after failed attempt $attempt',
        name: 'SalesnoteBootstrap',
        level: 900,
      );
      await Future<void>.delayed(TimingConstants.startupWarmRetryDelay);
    }
  }
}
