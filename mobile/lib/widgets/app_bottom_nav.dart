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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomSpacing = bottomInset > 0 ? bottomInset + 8 : 12.0;
    return Container(
      height: 72 + bottomSpacing,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFD9E1EE))),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomSpacing),
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
            InkWell(
              onTap: onAdd,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(29),
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
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 56,
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
