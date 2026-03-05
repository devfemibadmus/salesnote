import 'package:flutter/material.dart';

enum AppBottomTab { home, sales, items, settings }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.activeTab,
    required this.onHome,
    required this.onSales,
    required this.onAdd,
    required this.onItems,
    required this.onSettings,
  });

  final AppBottomTab activeTab;
  final VoidCallback onHome;
  final VoidCallback onSales;
  final VoidCallback onAdd;
  final VoidCallback onItems;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final navHeight = (screenHeight * 0.085).clamp(56.0, 80.0);
    return Container(
      height: navHeight + bottomInset,
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
            _TapScale(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(29),
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
            _NavItem(
              icon: Icons.inventory_2,
              label: 'Items',
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
    return _TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              scale: active ? 1.08 : 1.0,
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
              child: Text(label),
            ),
          ],
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
  });

  final VoidCallback onTap;
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
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          child: widget.child,
        ),
      ),
    );
  }
}
