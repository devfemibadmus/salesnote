import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';

class AppNotice {
  AppNotice._();

  static OverlayEntry? _entry;
  static Timer? _timer;
  static const Color _infoAccent = Color(0xFF1F6FEB);
  static const Color _errorAccent = Color(0xFFEF4444);

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    bool? isError,
  }) {
    hide();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final showAsError = isError ?? _looksLikeError(message);
    final accent = showAsError ? _errorAccent : _infoAccent;

    _entry = OverlayEntry(
      builder: (overlayContext) {
        final mediaQuery = MediaQuery.of(overlayContext);
        final keyboardInset = mediaQuery.viewInsets.bottom;

        return Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: keyboardInset > 0 ? keyboardInset + 24 : 0,
                  ),
                  child: Align(
                    alignment: keyboardInset > 0
                        ? const Alignment(0, 0.12)
                        : const Alignment(0, 0.4),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: IntrinsicWidth(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppTheme.appBackground,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: accent.withValues(alpha: 0.5)),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.16),
                                blurRadius: 28,
                                spreadRadius: 3,
                                offset: Offset(0, 0),
                              ),
                              const BoxShadow(
                                color: Color(0x120F172A),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            child: Text(
                              message,
                              textAlign: TextAlign.center,
                              softWrap: true,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_entry!);
    _timer = Timer(duration, hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  static bool _looksLikeError(String message) {
    final text = message.toLowerCase();
    const errorHints = <String>[
      'unable',
      'failed',
      'error',
      'invalid',
      'required',
      'not granted',
      'must be',
      'cannot',
      'can\'t',
      'could not',
      'missing',
      'denied',
      'expired',
      'too large',
      'too long',
      'too short',
      'not available',
      'please try again',
    ];

    for (final hint in errorHints) {
      if (text.contains(hint)) {
        return true;
      }
    }
    return false;
  }
}
