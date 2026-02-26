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
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.auth:
        return MaterialPageRoute(builder: (_) => const AuthScreen());
      case AppRoutes.onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case AppRoutes.sales:
        final args = settings.arguments;
        final salesArgs = args is SalesRouteArgs ? args : null;
        return MaterialPageRoute(
          builder: (_) => SalesScreen(routeArgs: salesArgs),
        );
      case AppRoutes.items:
        return MaterialPageRoute(builder: (_) => const ItemsScreen());
      case AppRoutes.newSale:
        return MaterialPageRoute(builder: (_) => const NewSaleScreen());
      case AppRoutes.shop:
        return MaterialPageRoute(builder: (_) => const ShopScreen());
      case AppRoutes.notification:
        return MaterialPageRoute(builder: (_) => const NotificationScreen());
      default:
        return MaterialPageRoute(builder: (_) => const AuthScreen());
    }
  }
}
