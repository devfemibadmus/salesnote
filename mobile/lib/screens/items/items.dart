import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../data/models.dart';
import '../../services/api_client.dart';
import '../../services/cache/loader.dart';
import '../../services/currency.dart';
import '../../services/token_store.dart';
import '../../widgets/app_bottom_nav.dart';

part 'states.dart';
part 'widgets.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final ApiClient _api = ApiClient(TokenStore());
  final TextEditingController _searchController = TextEditingController();
  static const int _perPage = 20;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  List<Sale> _sales = [];
  String _query = '';
  int _page = 1;
  late final String _currencySymbol;
  late final String _currencyLocale;

  void _goTo(String route, {bool reset = false}) {
    _api.cancelInFlight();
    if (!mounted) return;
    if (reset) {
      Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
      return;
    }
    Navigator.pushNamed(context, route);
  }

  @override
  void initState() {
    super.initState();
    final ctx = CurrencyService.resolveContext();
    _currencyLocale = ctx.locale;
    _currencySymbol = ctx.symbol;
    _searchController.addListener(_onSearchChanged);
    _loadItemsFromCacheOrApi();
  }

  String _formatAmount(num amount, {int decimalDigits = 2}) {
    return NumberFormat.currency(
      locale: _currencyLocale,
      symbol: _currencySymbol,
      decimalDigits: decimalDigits,
    ).format(amount);
  }

  Future<void> _loadItemsFromCacheOrApi() async {
    final cached = CacheLoader.loadSalesPageCache(includeItems: true);
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _sales = cached.sales;
        _page = cached.page;
        _hasMore = cached.hasMore;
        _error = null;
        _loading = false;
      });
      if (_sales.isEmpty) {
        unawaited(_refreshItemsInBackground());
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _sales = [];
      _page = 1;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    unawaited(_refreshItemsInBackground());
  }

  @override
  void dispose() {
    _api.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _query) return;
    setState(() => _query = next);
  }

  Future<void> _refreshItems() async {
    try {
      final loaded = await CacheLoader.fetchAndCacheSalesPage(
        _api,
        includeItems: true,
        page: 1,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _sales = loaded.sales;
        _page = loaded.page;
        _hasMore = loaded.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Unable to refresh items.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _refreshItemsInBackground() async {
    try {
      final loaded = await CacheLoader.fetchAndCacheSalesPage(
        _api,
        includeItems: true,
        page: 1,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _sales = loaded.sales;
        _page = loaded.page;
        _hasMore = loaded.hasMore;
        _error = null;
      });
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final loaded = await CacheLoader.fetchAndCacheSalesPage(
        _api,
        includeItems: true,
        page: nextPage,
        perPage: _perPage,
      );
      final next = loaded.sales;
      if (!mounted) return;
      final existingIds = _sales.map((sale) => sale.id).toSet();
      final deduped = next
          .where((sale) => !existingIds.contains(sale.id))
          .toList();
      setState(() {
        _sales = [..._sales, ...deduped];
        _page = nextPage;
        _hasMore = next.length == _perPage;
      });
      await CacheLoader.saveSalesPageCache(
        includeItems: true,
        data: CachedSalesPage(sales: _sales, page: _page, hasMore: _hasMore),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Unable to load more items.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  List<_ItemRow> get _itemRows {
    final byNameAndPrice = <String, _ItemRow>{};
    for (final sale in _sales) {
      for (final item in sale.items) {
        final raw = item.productName.trim();
        final name = raw.isEmpty ? 'Unnamed item' : raw;
        final unitPrice = item.unitPrice;
        final key = '$name|${unitPrice.toStringAsFixed(2)}';
        final existing = byNameAndPrice[key];
        if (existing == null) {
          byNameAndPrice[key] = _ItemRow(
            name: name,
            unitPrice: unitPrice,
            quantity: item.quantity,
            total: item.lineTotal,
          );
        } else {
          byNameAndPrice[key] = _ItemRow(
            name: existing.name,
            unitPrice: existing.unitPrice,
            quantity: existing.quantity + item.quantity,
            total: existing.total + item.lineTotal,
          );
        }
      }
    }

    var rows = byNameAndPrice.values.toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      rows = rows.where((row) => row.name.toLowerCase().contains(q)).toList();
    }
    rows.sort((a, b) => b.quantity.compareTo(a.quantity));
    return rows;
  }

  bool get _isDataEmpty => !_loading && _sales.isEmpty;

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const _ItemsLoadingState();
    } else if (_isDataEmpty) {
      body = _ItemsEmptyState(
        message: _error,
        onAddSale: () => _goTo(AppRoutes.newSale),
      );
    } else {
      body = _ItemsMainState(
        queryController: _searchController,
        rows: _itemRows,
        formatAmount: _formatAmount,
        loadingMore: _loadingMore,
        hasMore: _hasMore,
        onLoadMore: _loadMore,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _refreshItems, child: body),
      ),
      bottomNavigationBar: AppBottomNav(
        activeTab: AppBottomTab.items,
        onHome: () => _goTo(AppRoutes.home, reset: true),
        onSales: () => _goTo(AppRoutes.sales, reset: true),
        onAdd: () => _goTo(AppRoutes.newSale),
        onItems: () {},
        onSettings: () => _goTo(AppRoutes.shop, reset: true),
      ),
    );
  }
}

class _ItemRow {
  const _ItemRow({
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.total,
  });

  final String name;
  final double unitPrice;
  final double quantity;
  final double total;
}
