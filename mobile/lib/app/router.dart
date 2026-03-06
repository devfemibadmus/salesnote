import 'package:flutter/material.dart';

import '../screens/auth/auth.dart';
import '../screens/home/home.dart';
import '../screens/items/items.dart';
import '../screens/newsales/newsales.dart';
import '../screens/notification/notification.dart';
import '../screens/onboarding/onboarding.dart';
import '../screens/sales/sales.dart';
import '../screens/shop/shop.dart';
import 'routes.dart';

class AppRouter {
  static int? _lastTabIndex;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '';
    final int? nextIndex = AppRoutes.tabIndices[name];
    final int? prevIndex = _lastTabIndex;
    
    // Only update last index if it's a main tab
    if (nextIndex != null) {
      _lastTabIndex = nextIndex;
    }

    Route<dynamic> buildDefault(Widget page) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => page,
      );
    }

    // Directional transition for main tabs
    Route<dynamic> buildTab(Widget page) {
      if (prevIndex == null || nextIndex == null || prevIndex == nextIndex) {
        return buildDefault(page);
      }

      final bool slideForward = nextIndex > prevIndex;
      final beginOffset = Offset(slideForward ? 0.06 : -0.06, 0);

      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slide = Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ));

          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: child,
            ),
          );
        },
      );
    }

    switch (name) {
      case AppRoutes.auth:
        return buildDefault(const AuthScreen());
      case AppRoutes.onboarding:
        return buildDefault(const OnboardingScreen());
      case AppRoutes.home:
        return buildTab(const HomeScreen());
      case AppRoutes.sales:
        final args = settings.arguments;
        final salesArgs = args is SalesRouteArgs ? args : null;
        return buildTab(SalesScreen(routeArgs: salesArgs));
      case AppRoutes.items:
        return buildTab(const ItemsScreen());
      case AppRoutes.newSale:
        return buildDefault(const NewSaleScreen());
      case AppRoutes.shop:
        return buildTab(const ShopScreen());
      case AppRoutes.notification:
        return buildDefault(const NotificationScreen());
      default:
        return buildDefault(const AuthScreen());
    }
  }
}
