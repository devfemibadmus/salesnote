import 'package:flutter/widgets.dart';

class RegionService {
  RegionService._();
  static String getDeviceRegionCode() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final code = locale.countryCode?.toUpperCase();
    debugPrint('Device locale: $locale, region: $code');
    return code ?? 'US';
  }
}
