class AppRoutes {
  static const auth = '/auth';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const sales = '/sales';
  static const items = '/items';
  static const newSale = '/sales/new';
  static const shop = '/shop';
  static const notification = '/notification';
}

class SalesRouteArgs {
  const SalesRouteArgs({this.openSaleId, this.refreshFirst = false});

  final String? openSaleId;
  final bool refreshFirst;
}
