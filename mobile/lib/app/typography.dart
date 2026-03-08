import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const bool forceDisableDeviceBoldText = true;
  static const double minTextScaleFactor = 1.0;
  static const double maxTextScaleFactor = 1.15;

  static MediaQueryData apply(MediaQueryData mediaQuery) {
    return mediaQuery.copyWith(
      boldText: !forceDisableDeviceBoldText ? mediaQuery.boldText : false,
      textScaler: mediaQuery.textScaler.clamp(
        minScaleFactor: minTextScaleFactor,
        maxScaleFactor: maxTextScaleFactor,
      ),
    );
  }
}
