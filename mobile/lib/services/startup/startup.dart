import 'dart:async';

import 'flag.dart';
import 'cues.dart';

class StartupWarmupService {
  StartupWarmupService._();

  static void warmAll() {
    unawaited(FlagService.warmAllFlags());
    unawaited(LiveCashierCueService.warmAllCues());
  }
}
