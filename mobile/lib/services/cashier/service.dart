part of 'core.dart';

class LiveCashierService {
  LiveCashierService._();

  static OverlayEntry? _entry;
  static final GlobalKey<_LiveCashierOverlayState> _overlayKey =
      GlobalKey<_LiveCashierOverlayState>();

  static bool get isVisible => _entry != null;

  static Future<void> show(BuildContext context) async {
    if (_entry != null) {
      _overlayKey.currentState?._expandPanel();
      return;
    }
    final overlay =
        AppNavigator.key.currentState?.overlay ??
        Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    _entry = OverlayEntry(
      builder: (_) => _LiveCashierOverlay(key: _overlayKey),
    );
    overlay.insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }

  static void expand() {
    _overlayKey.currentState?._expandPanel();
  }
}
