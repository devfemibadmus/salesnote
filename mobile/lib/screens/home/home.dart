import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/config.dart';
import '../../app/routes.dart';
import '../../data/models.dart';
import '../preview/preview.dart';
import '../../services/api_client.dart';
import '../../services/cache/loader.dart';
import '../../services/currency.dart';
import '../../services/cache/local.dart';
import '../../services/notification.dart';
import '../../services/token_store.dart';
import '../../widgets/app_bottom_nav.dart';

part 'states.dart';
part 'widgets.dart';

String _homeCurrencySymbol = ' ';
String _homeCurrencyLocale = 'en_US';

String _homeFormatAmount(num amount, {int decimalDigits = 2}) {
  return NumberFormat.currency(
    locale: _homeCurrencyLocale,
    symbol: _homeCurrencySymbol,
    decimalDigits: decimalDigits,
  ).format(amount);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _api = ApiClient(TokenStore());
  bool _loading = true;
  String? _error;
  ShopProfile? _shop;
  AnalyticsSummary? _analytics;
  List<Sale> _sales = [];
  int _trendTab = 0;

  void _syncHomeCurrencyFormatter() {
    final ctx = CurrencyService.resolveContext();
    _homeCurrencyLocale = ctx.locale;
    _homeCurrencySymbol = ctx.symbol;
  }

  void _goTo(String route, {bool reset = false}) {
    _api.cancelInFlight();
    if (!mounted) return;
    if (reset) {
      Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
      return;
    }
    Navigator.pushNamed(context, route);
  }

  bool _openingPreview = false;

  Future<void> _openSalePreviewById(String saleId) async {
    if (_openingPreview) return;
    setState(() => _openingPreview = true);
    try {
      final loadingRoute = MaterialPageRoute<void>(
        builder: (_) => const SalePreviewLoadingScreen(),
      );
      if (mounted) {
        Navigator.of(context).push(loadingRoute);
      }

      final saleDetail = await CacheLoader.loadOrFetchSalePreview(_api, saleId);
      if (saleDetail == null) {
        if (loadingRoute.isActive && mounted) {
          Navigator.of(context).pop();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open sale preview.')),
          );
        }
        return;
      }

      if (!mounted) return;

      if (!loadingRoute.isActive) {
        return;
      }

      final settings = await CacheLoader.loadOrFetchSettingsSummary(_api);
      final signatures = await CacheLoader.loadOrFetchSignatures(_api);
      if (!mounted) return;

      final shop = settings?.shop;
      final detail = saleDetail;
      SignatureItem? signature;
      for (final sig in signatures) {
        if (sig.id == detail.signatureId) {
          signature = sig;
          break;
        }
      }

      final previewItems = detail.items
          .map(
            (item) => PreviewSaleItem(
              productName: item.productName,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
            ),
          )
          .toList();
      final total = detail.total;
      final createdAtText = detail.createdAt;
      final createdAt = DateTime.tryParse(createdAtText)?.toLocal();

      final previewRoute = MaterialPageRoute<void>(
        builder: (_) => SalePreviewScreen(
          isCreatedSale: true,
          shop: shop,
          signature: signature,
          customerName: detail.customerName ?? '',
          customerContact: detail.customerContact ?? '',
          items: previewItems,
          subtotal: detail.subtotal,
          discountAmount: detail.discountAmount,
          vatAmount: detail.vatAmount,
          serviceFeeAmount: detail.serviceFeeAmount,
          deliveryFeeAmount: detail.deliveryFeeAmount,
          roundingAmount: detail.roundingAmount,
          otherAmount: detail.otherAmount,
          otherLabel: detail.otherLabel,
          total: total,
          receiptNumber: '#REC-$saleId',
          createdAt: createdAt,
        ),
      );

      if (loadingRoute.isActive) {
        await Navigator.of(context).pushReplacement(previewRoute);
      } else {
        await Navigator.of(context).push(previewRoute);
      }
    } finally {
      if (mounted) {
        setState(() => _openingPreview = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _syncHomeCurrencyFormatter();
    WidgetsBinding.instance.addObserver(this);
    _loadHomeFromCacheOrApi();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupNotifications());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;

    // Force lightweight rebuild on resume so locale/region currency formatting
    // re-runs even when no API refresh is triggered.
    _syncHomeCurrencyFormatter();
    setState(() {
      if (_shop != null) {
        _shop = _mergeShopWithSettingsCache(_shop!);
      }
    });
  }

  Future<void> _loadHomeFromCacheOrApi() async {
    final data = CacheLoader.loadHomeSummaryCache();
    if (data == null) {
      if (!mounted) return;
      setState(() {
        _shop = null;
        _analytics = null;
        _sales = [];
        _error = null;
        _loading = false;
      });
      unawaited(_refreshHomeInBackground());
      return;
    }

    final mergedShop = _mergeShopWithSettingsCache(data.shop);
    if (!mounted) return;
    setState(() {
      _shop = mergedShop;
      _analytics = data.analytics;
      _sales = data.recentSales;
      _error = null;
      _loading = false;
    });
    if (_isEmpty) {
      unawaited(_refreshHomeInBackground());
    }
  }

  Future<void> _loadHome({bool refresh = false}) async {
    final hasCurrentUi = _shop != null && _analytics != null;
    if (refresh && hasCurrentUi) {
      if (!mounted) return;
    } else {
      if (!mounted) return;
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await CacheLoader.fetchAndCacheHomeSummary(_api);
      final mergedShop = _mergeShopWithSettingsCache(data.shop);
      if (!mounted) return;
      setState(() {
        _shop = mergedShop;
        _analytics = data.analytics;
        _sales = data.recentSales;
        _error = null;
      });
      await CacheLoader.saveHomeSummaryCache(
        HomeSummary(
          shop: mergedShop,
          analytics: data.analytics,
          recentSales: data.recentSales,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Unable to load dashboard.';

      // Keep current home UI during pull-to-refresh failures.
      if (refresh && hasCurrentUi) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } else {
        setState(() => _error = message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshHomeInBackground() async {
    try {
      final data = await CacheLoader.fetchAndCacheHomeSummary(_api);
      final mergedShop = _mergeShopWithSettingsCache(data.shop);
      if (!mounted) return;
      setState(() {
        _shop = mergedShop;
        _analytics = data.analytics;
        _sales = data.recentSales;
        _error = null;
      });
    } catch (_) {}
  }

  Future<void> _setupNotifications() async {
    try {
      final optedOut = await LocalCache.isNotificationOptedOut();
      if (optedOut) return;

      await NotificationService.init();
      final status = await NotificationService.getPermissionStatus();
      if (_isGranted(status)) {
        await LocalCache.setNotificationPromptCooldown(0);
        return;
      }
      final cooldown = await LocalCache.getNotificationPromptCooldown();
      if (cooldown > 0) {
        await LocalCache.setNotificationPromptCooldown(cooldown - 1);
        return;
      }
      if (!mounted) return;
      final allow = await NotificationService.showPermissionPrompt(context);
      if (!allow || !mounted) {
        await LocalCache.setNotificationPromptCooldown(2);
        return;
      }

      var permissionStatus = await NotificationService.getPermissionStatus();
      if (!_isGranted(permissionStatus)) {
        permissionStatus = await NotificationService.requestPermission();
      }

      if (_isGranted(permissionStatus)) {
        await LocalCache.setNotificationPromptCooldown(0);
      } else {
        await LocalCache.setNotificationPromptCooldown(2);
      }
    } catch (_) {}
  }

  bool _isGranted(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  bool get _isEmpty {
    final a = _analytics;
    if (a == null) return true;
    final hasChartData =
        _hasNonZeroAnalytics(a.daily) ||
        _hasNonZeroAnalytics(a.weekly) ||
        _hasNonZeroAnalytics(a.monthly);
    final hasMovementData = a.fastMoving.isNotEmpty || a.slowMoving.isNotEmpty;
    return _sales.isEmpty && !hasChartData && !hasMovementData;
  }

  bool _hasNonZeroAnalytics(List<AnalyticsPoint> points) {
    return points.any((point) => point.total != 0 || point.units != 0);
  }

  ShopProfile _mergeShopWithSettingsCache(ShopProfile homeShop) {
    final settings = CacheLoader.loadSettingsSummaryCache();
    if (settings == null) return homeShop;
    final settingsShop = settings.shop;
    return ShopProfile(
      id: homeShop.id,
      name: settingsShop.name.trim().isEmpty
          ? homeShop.name
          : settingsShop.name,
      phone: homeShop.phone,
      email: homeShop.email,
      address: homeShop.address,
      logoUrl: (settingsShop.logoUrl ?? '').trim().isEmpty
          ? homeShop.logoUrl
          : settingsShop.logoUrl,
      timezone: homeShop.timezone,
      createdAt: homeShop.createdAt,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const _LoadingState();
    } else if (_error != null) {
      body = _ErrorState(
        message: _error!,
        onRetry: _loadHome,
        onNotification: () => _goTo(AppRoutes.notification),
      );
    } else if (_isEmpty) {
      body = _EmptyState(
        onCreateSale: () => _goTo(AppRoutes.newSale),
        onNotification: () => _goTo(AppRoutes.notification),
      );
    } else {
      body = _MainState(
        shop: _shop!,
        analytics: _analytics!,
        sales: _sales,
        trendTab: _trendTab,
        onTabChanged: (i) => setState(() => _trendTab = i),
        onSettings: () => _goTo(AppRoutes.shop, reset: true),
        onNotification: () => _goTo(AppRoutes.notification),
        onOpenSale: (sale) => _openSalePreviewById(sale.id.toString()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadHome(refresh: true),
          child: body,
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        activeTab: AppBottomTab.home,
        onHome: () {},
        onSales: () => _goTo(AppRoutes.sales, reset: true),
        onAdd: () => _goTo(AppRoutes.newSale),
        onItems: () => _goTo(AppRoutes.items, reset: true),
        onSettings: () => _goTo(AppRoutes.shop, reset: true),
      ),
    );
  }
}
