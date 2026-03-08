import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const bool forceDisableDeviceBoldText = true;
  static const TextScaler textScaler = TextScaler.noScaling;

  static MediaQueryData apply(MediaQueryData mediaQuery) {
    return mediaQuery.copyWith(
      boldText: !forceDisableDeviceBoldText ? mediaQuery.boldText : false,
      textScaler: textScaler,
    );
  }
}
