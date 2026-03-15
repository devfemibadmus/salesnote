import 'package:flutter/material.dart';

enum AppBottomTab { none, home, sales, items, settings }

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

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
      child: Container(
        height: navHeight + bottomInset + 20,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFD9E1EE))),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 22,
              offset: Offset(0, -8),
            ),
          ],
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
              _TapScale(
                onTap: onAdd,
                onLongPress: onAddLongPress,
                borderRadius: BorderRadius.circular(29),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 820),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, (1 - value) * 10),
                      child: Transform.scale(
                        scale: 0.92 + (value * 0.08),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(29),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x29007AFF),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 30),
                  ),
                ),
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
    return _TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: 74,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0x14007AFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? const Color(0x22007AFF) : Colors.transparent,
          ),
        ),
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          offset: Offset(0, active ? -0.04 : 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                scale: active ? 1.1 : 1.0,
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
                child: Text(label),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: active ? 18 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TapScale extends StatefulWidget {
  const _TapScale({
    required this.onTap,
    required this.child,
    required this.borderRadius,
    this.onLongPress,
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      scale: _pressed ? 0.93 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: widget.borderRadius,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          child: widget.child,
        ),
      ),
    );
  }
}
