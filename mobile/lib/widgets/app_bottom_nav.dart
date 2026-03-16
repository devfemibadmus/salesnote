import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppBottomTab { none, home, sales, items, settings }

enum _NavHapticStyle { subtle, action }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.activeTab,
    required this.onHome,
    required this.onSales,
    required this.onAdd,
    this.onAddLongPress,
    required this.onItems,
    required this.onSettings,
  });

  final AppBottomTab activeTab;
  final VoidCallback onHome;
  final VoidCallback onSales;
  final VoidCallback onAdd;
  final VoidCallback? onAddLongPress;
  final VoidCallback onItems;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    const double navHeight = kBottomNavigationBarHeight;

    return Container(
      height: navHeight + bottomInset + 20,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFD9E1EE))),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home,
              label: 'Home',
              active: activeTab == AppBottomTab.home,
              onTap: onHome,
            ),
            _NavItem(
              icon: Icons.bar_chart,
              label: 'Sales',
              active: activeTab == AppBottomTab.sales,
              onTap: onSales,
            ),
            _VoiceHoldAddButton(
              onTap: onAdd,
              onVoiceLock: onAddLongPress,
            ),
            _NavItem(
              icon: Icons.receipt_long,
              label: 'Invoices',
              active: activeTab == AppBottomTab.items,
              onTap: onItems,
            ),
            _NavItem(
              icon: Icons.settings,
              label: 'Settings',
              active: activeTab == AppBottomTab.settings,
              onTap: onSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF007AFF) : const Color(0xFF94A3B8);
    return _NavTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      hapticStyle: _NavHapticStyle.subtle,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTap extends StatelessWidget {
  const _NavTap({
    required this.onTap,
    required this.child,
    required this.borderRadius,
    required this.hapticStyle,
  });

  final VoidCallback onTap;
  final Widget child;
  final BorderRadius borderRadius;
  final _NavHapticStyle hapticStyle;

  Future<void> _triggerTapFeedback(BuildContext context) async {
    if (hapticStyle == _NavHapticStyle.action) {
      await _triggerActionHaptic();
      return;
    }
    await HapticFeedback.selectionClick();
  }

  Future<void> _triggerActionHaptic() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
    if (Platform.isAndroid) {
      try {
        await HapticFeedback.vibrate();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () {
          unawaited(_triggerTapFeedback(context));
          onTap();
        },
        child: child,
      ),
    );
  }
}

class _VoiceHoldAddButton extends StatefulWidget {
  const _VoiceHoldAddButton({required this.onTap, this.onVoiceLock});

  final VoidCallback onTap;
  final VoidCallback? onVoiceLock;

  @override
  State<_VoiceHoldAddButton> createState() => _VoiceHoldAddButtonState();
}

class _VoiceHoldAddButtonState extends State<_VoiceHoldAddButton> {
  static const double _lockThreshold = 56;

  bool _holding = false;
  bool _locked = false;
  double _dragOffset = 0;

  Future<void> _triggerVoiceLock() async {
    if (_locked || widget.onVoiceLock == null) {
      return;
    }
    setState(() {
      _locked = true;
    });
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
    widget.onVoiceLock!();
  }

  void _resetState() {
    if (!mounted) return;
    setState(() {
      _holding = false;
      _locked = false;
      _dragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _holding || _locked;
    final progress = (_dragOffset / _lockThreshold).clamp(0.0, 1.0);
    final label = _locked
        ? 'Live'
        : (_holding ? (progress >= 1 ? 'Release' : 'Drag up') : null);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPressStart: widget.onVoiceLock == null
          ? null
          : (_) {
              setState(() {
                _holding = true;
                _locked = false;
                _dragOffset = 0;
              });
            },
      onLongPressMoveUpdate: widget.onVoiceLock == null
          ? null
          : (details) {
              if (_locked) return;
              final dragOffset = (-details.offsetFromOrigin.dy).clamp(0.0, 96.0);
              setState(() {
                _dragOffset = dragOffset;
              });
              if (dragOffset >= _lockThreshold) {
                unawaited(_triggerVoiceLock());
              }
            },
      onLongPressEnd: widget.onVoiceLock == null
          ? null
          : (_) {
              final shouldTrigger = !_locked && _dragOffset >= _lockThreshold;
              if (shouldTrigger) {
                unawaited(_triggerVoiceLock());
              }
              _resetState();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFDC2626) : const Color(0xFF007AFF),
          borderRadius: BorderRadius.circular(29),
          boxShadow: [
            BoxShadow(
              color: active
                  ? const Color(0x29DC2626)
                  : const Color(0x29007AFF),
              blurRadius: 12 + (progress * 8),
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              active ? Icons.mic_rounded : Icons.add,
              color: Colors.white,
              size: 30,
            ),
            if (label != null)
              Positioned(
                top: -24,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
