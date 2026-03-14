import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../data/models.dart';
import '../../services/api_client.dart';
import '../../services/cache/loader.dart';
import '../../services/currency.dart';
import '../../services/live_cashier.dart';
import '../../services/notice.dart';
import '../../services/token_store.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/history.dart';

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
  static const int _filteredPerPage = 200;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _baseDataKnownEmpty = true;
  String? _error;
  List<Sale> _sales = [];
  String _query = '';
  int _page = 1;
  int _searchRequestId = 0;
  late final String _currencySymbol;
  late final String _currencyLocale;
  DateTime? _startDate;
  DateTime? _endDate;
  Timer? _searchDebounce;

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
    final cached = CacheLoader.loadSalesPageCache(
      includeItems: true,
      status: SaleStatus.paid,
    );
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _sales = cached.sales;
        _page = cached.page;
        _hasMore = cached.hasMore;
        _baseDataKnownEmpty = cached.sales.isEmpty;
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
      _baseDataKnownEmpty = true;
      _error = null;
      _loading = false;
    });
    unawaited(_refreshItemsInBackground());
  }

  @override
  void dispose() {
    _api.dispose();
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _query) return;
    _searchRequestId += 1;
    setState(() {
      _query = next;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      unawaited(_refreshItemsInBackground(searchQuery: next));
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF007AFF),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      });
      unawaited(_refreshItemsInBackground());
    }
  }

  void _clearDateFilter() {
    if (_startDate == null && _endDate == null) return;
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    unawaited(_refreshItemsInBackground());
  }

  Future<void> _refreshItems() async {
    final activeQuery = _query.trim();
    final hasActiveFilters = _hasActiveFiltersForQuery(activeQuery);
    final perPage = hasActiveFilters ? _filteredPerPage : _perPage;
    try {
      final loaded = await CacheLoader.fetchAndCacheSalesPage(
        _api,
        includeItems: true,
        page: 1,
        perPage: perPage,
        status: SaleStatus.paid,
        searchQuery: activeQuery.isEmpty ? null : activeQuery,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      if (activeQuery != _query.trim()) return;
      setState(() {
        _sales = loaded.sales;
        _page = loaded.page;
        _hasMore = !hasActiveFilters && loaded.hasMore;
        if (!hasActiveFilters) {
          _baseDataKnownEmpty = loaded.sales.isEmpty;
        }
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Unable to refresh items.';
      AppNotice.show(context, message);
    }
  }

  Future<void> _refreshItemsInBackground({String? searchQuery}) async {
    final activeQuery = (searchQuery ?? _query).trim();
    final requestId = _searchRequestId;
    final hasActiveFilters = _hasActiveFiltersForQuery(activeQuery);
    final perPage = hasActiveFilters ? _filteredPerPage : _perPage;
    try {
      final loaded = await CacheLoader.fetchAndCacheSalesPage(
        _api,
        includeItems: true,
        page: 1,
        perPage: perPage,
        status: SaleStatus.paid,
        searchQuery: activeQuery.isEmpty ? null : activeQuery,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      if (requestId != _searchRequestId || activeQuery != _query.trim()) return;
      setState(() {
        _sales = loaded.sales;
        _page = loaded.page;
        _hasMore = !hasActiveFilters && loaded.hasMore;
        if (!hasActiveFilters) {
          _baseDataKnownEmpty = loaded.sales.isEmpty;
        }
        _error = null;
      });
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading || _hasActiveFiltersForQuery(_query.trim())) {
      return;
    }
    final activeQuery = _query.trim();
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final loaded = await CacheLoader.fetchAndCacheSalesPage(
        _api,
        includeItems: true,
        page: nextPage,
        perPage: _perPage,
        status: SaleStatus.paid,
        searchQuery: activeQuery.isEmpty ? null : activeQuery,
        startDate: _startDate,
        endDate: _endDate,
      );
      final next = loaded.sales;
      if (!mounted) return;
      if (activeQuery != _query.trim()) return;
      final existingIds = _sales.map((sale) => sale.id).toSet();
      final deduped = next
          .where((sale) => !existingIds.contains(sale.id))
          .toList();
      setState(() {
        _sales = [..._sales, ...deduped];
        _page = nextPage;
        _hasMore = next.length == _perPage;
      });
      if (activeQuery.isEmpty) {
        await CacheLoader.saveSalesPageCache(
          includeItems: true,
          status: SaleStatus.paid,
          data: CachedSalesPage(sales: _sales, page: _page, hasMore: _hasMore),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Unable to load more items.';
      AppNotice.show(context, message);
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  List<_ItemRow> get _itemRows {
    final normalized = _query.trim().toLowerCase();
    final hasSearch = normalized.isNotEmpty;
    final hasDates = _startDate != null || _endDate != null;

    final filteredSales = (hasSearch || hasDates)
        ? _sales.where((sale) {
            if (hasDates) {
              final saleDate = DateTime.tryParse(sale.createdAt)?.toLocal();
              if (saleDate == null) return false;
              if (_startDate != null && saleDate.isBefore(_startDate!)) {
                return false;
              }
              if (_endDate != null && saleDate.isAfter(_endDate!)) return false;
            }
            if (hasSearch) {
              final customer = (sale.customerName ?? '').toLowerCase();
              final idText = sale.id.toLowerCase();
              final matchesCustomerOrId =
                  customer.contains(normalized) || idText.contains(normalized);

              final matchesAnyItem = sale.items.any(
                (item) => item.productName.toLowerCase().contains(normalized),
              );

              if (!matchesCustomerOrId && !matchesAnyItem) return false;
            }
            return true;
          }).toList()
        : _sales;

    final byNameAndPrice = <String, _ItemRow>{};
    for (final sale in filteredSales) {
      for (final item in sale.items) {
        final raw = item.productName.trim();
        final name = raw.isEmpty ? 'Unnamed item' : raw;

        // If we are searching, we should also filter at the item level 
        // to show only matching items if the sale matched via items
        if (hasSearch && !name.toLowerCase().contains(normalized)) {
          // Check if sale matched via customer/id instead
          final customer = (sale.customerName ?? '').toLowerCase();
          final idText = sale.id.toLowerCase();
          final matchesCustomerOrId = 
              customer.contains(normalized) || idText.contains(normalized);
          
          if (!matchesCustomerOrId) continue;
        }

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
    rows.sort((a, b) => b.quantity.compareTo(a.quantity));
    return rows;
  }

  bool get _isDataEmpty => !_loading && _sales.isEmpty;

  bool _hasActiveFiltersForQuery(String query) {
    return query.isNotEmpty || _startDate != null || _endDate != null;
  }

  bool get _shouldShowFullEmptyState =>
      _isDataEmpty && _query.trim().isEmpty && _startDate == null && _endDate == null && _baseDataKnownEmpty;

  bool get _showBackButton => Navigator.of(context).canPop();

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = _ItemsLoadingState(showBackButton: _showBackButton);
    } else if (_shouldShowFullEmptyState) {
      body = _ItemsEmptyState(
        message: _error,
        onAddSale: () => _goTo(AppRoutes.newSale),
        showBackButton: _showBackButton,
      );
    } else {
      body = _ItemsMainState(
        queryController: _searchController,
        rows: _itemRows,
        formatAmount: _formatAmount,
        loadingMore: _loadingMore,
        hasMore: _hasMore,
        onLoadMore: _loadMore,
        onDateTap: _selectDateRange,
        onClearDate: _clearDateFilter,
        showBackButton: _showBackButton,
        hasDateFilter: _startDate != null || _endDate != null,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _refreshItems, child: body),
      ),
      bottomNavigationBar: AppBottomNav(
          activeTab: AppBottomTab.none,
          onHome: () => _goTo(AppRoutes.home, reset: true),
          onSales: () => _goTo(AppRoutes.sales, reset: true),
          onAdd: () => _goTo(AppRoutes.newSale),
          onAddLongPress: () => LiveCashierService.show(context),
          onItems: () => _goTo(AppRoutes.invoices, reset: true),
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
