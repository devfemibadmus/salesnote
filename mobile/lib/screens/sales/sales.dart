import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/routes.dart';
import '../../data/models.dart';
import '../../services/api_client.dart';
import '../../services/cache/loader.dart';
import '../../services/currency.dart';
import '../../services/notice.dart';
import '../../services/preview.dart';
import '../../services/token_store.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/history.dart';

part 'states.dart';
part 'widgets.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key, this.routeArgs});

  final SalesRouteArgs? routeArgs;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final ApiClient _api = ApiClient(TokenStore());
  final TextEditingController _searchController = TextEditingController();
  static const int _perPage = 20;
  static const int _filteredPerPage = 200;
  late final String _salesCurrencySymbol;
  late final String _salesLocale;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _baseDataKnownEmpty = true;
  String? _error;
  List<Sale> _sales = [];
  String _query = '';
  int _page = 1;
  int _searchRequestId = 0;
  bool _openingPreview = false;
  bool _launchIntentHandled = false;
  bool _launchIntentScheduled = false;
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
    _salesLocale = ctx.locale;
    _salesCurrencySymbol = ctx.symbol;
    _searchController.addListener(_onSearchChanged);
    _loadSalesFromCacheOrApi();
  }

  String _formatSalesAmount(num amount) {
    return NumberFormat.currency(
      locale: _salesLocale,
      symbol: _salesCurrencySymbol,
      decimalDigits: 2,
    ).format(amount);
  }

  Future<void> _loadSalesFromCacheOrApi() async {
    final cached = CacheLoader.loadSalesPageCache(includeItems: false);
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
        unawaited(_refreshSalesInBackground());
      }
      _scheduleLaunchIntent();
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
    unawaited(_refreshSalesInBackground());
    _scheduleLaunchIntent();
  }

  void _scheduleLaunchIntent() {
    if (_launchIntentScheduled || _launchIntentHandled) return;
    _launchIntentScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchIntentScheduled = false;
      if (!mounted || _launchIntentHandled) return;
      unawaited(_handleLaunchIntent());
    });
  }

  Future<void> _handleLaunchIntent() async {
    if (_launchIntentHandled) return;
    final saleId = widget.routeArgs?.openSaleId?.trim() ?? '';
    if (saleId.isEmpty) {
      _launchIntentHandled = true;
      return;
    }
    _launchIntentHandled = true;

    if (widget.routeArgs?.refreshFirst == true) {
      try {
        final loaded = await CacheLoader.fetchAndCacheSalesPage(
          _api,
          includeItems: false,
          page: 1,
          perPage: _perPage,
        );
        if (mounted) {
          setState(() {
            _sales = loaded.sales;
            _page = loaded.page;
            _hasMore = loaded.hasMore;
            _error = null;
            _loading = false;
          });
        }
      } catch (_) {}
    }

    if (!mounted) return;
    await _openSalePreviewById(saleId);
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
      unawaited(_refreshSalesInBackground(searchQuery: next));
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
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF007AFF),
              ),
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
      unawaited(_refreshSalesInBackground());
    } else if (_startDate != null || _endDate != null) {
      // Clear filter if they cancel and a filter was active? 
      // Actually, usually cancel means "don't change anything".
      // Let's provide a way to clear if needed, or if picked is null we just keep current.
    }
  }

  void _clearDateFilter() {
    if (_startDate == null && _endDate == null) return;
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    unawaited(_refreshSalesInBackground());
  }

  Future<void> _refreshSales() async {
    final activeQuery = _query.trim();
    final hasActiveFilters = _hasActiveFiltersForQuery(activeQuery);
    final perPage = hasActiveFilters ? _filteredPerPage : _perPage;
    try {
      final loaded = await CacheLoader.fetchAndCacheSalesPage(
        _api,
        includeItems: false,
        page: 1,
        perPage: perPage,
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
          : 'Unable to refresh sales.';
      AppNotice.show(context, message);
    }
  }

  Future<void> _refreshSalesInBackground({String? searchQuery}) async {
    final activeQuery = (searchQuery ?? _query).trim();
    final requestId = _searchRequestId;
    final hasActiveFilters = _hasActiveFiltersForQuery(activeQuery);
    final perPage = hasActiveFilters ? _filteredPerPage : _perPage;
    try {
      final loaded = await CacheLoader.fetchAndCacheSalesPage(
        _api,
        includeItems: false,
        page: 1,
        perPage: perPage,
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

  Future<void> _loadMoreSales() async {
    if (_loadingMore || !_hasMore || _loading || _hasActiveFiltersForQuery(_query.trim())) {
      return;
    }
    final activeQuery = _query.trim();
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final loaded = await CacheLoader.fetchAndCacheSalesPage(
        _api,
        includeItems: false,
        page: nextPage,
        perPage: _perPage,
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
          includeItems: false,
          data: CachedSalesPage(sales: _sales, page: _page, hasMore: _hasMore),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Unable to load more sales.';
      AppNotice.show(context, message);
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  List<Sale> get _filteredSales {
    final normalized = _query.trim().toLowerCase();
    final hasSearch = normalized.isNotEmpty;
    final hasDates = _startDate != null || _endDate != null;

    if (!hasSearch && !hasDates) return _sales;

    return _sales.where((sale) {
      if (hasSearch) {
        final customer = (sale.customerName ?? '').toLowerCase();
        final idText = sale.id.toLowerCase();
        if (!customer.contains(normalized) && !idText.contains(normalized)) {
          return false;
        }
      }

      if (hasDates) {
        final saleDate = DateTime.tryParse(sale.createdAt)?.toLocal();
        if (saleDate == null) return false;
        if (_startDate != null && saleDate.isBefore(_startDate!)) return false;
        if (_endDate != null && saleDate.isAfter(_endDate!)) return false;
      }

      return true;
    }).toList();
  }

  bool _hasActiveFiltersForQuery(String query) {
    return query.isNotEmpty || _startDate != null || _endDate != null;
  }

  bool get _isDataEmpty => !_loading && _sales.isEmpty;

  bool get _shouldShowFullEmptyState =>
      _isDataEmpty && _query.trim().isEmpty && _startDate == null && _endDate == null && _baseDataKnownEmpty;

  Future<void> _openSalePreviewById(String saleId) async {
    if (_openingPreview) return;
    setState(() => _openingPreview = true);
    try {
      await PreviewService.openById(saleId);
    } finally {
      if (mounted) {
        setState(() => _openingPreview = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const _SalesLoadingState();
    } else if (_shouldShowFullEmptyState) {
      body = _SalesEmptyState(
        message: _error,
        onAddSale: () => _goTo(AppRoutes.newSale),
      );
    } else {
      body = _SalesMainState(
        queryController: _searchController,
        sales: _filteredSales,
        loadingMore: _loadingMore,
        hasMore: _hasMore,
        formatAmount: _formatSalesAmount,
        onLoadMore: _loadMoreSales,
        onOpenSale: (sale) => _openSalePreviewById(sale.id),
        onDateTap: _selectDateRange,
        onClearDate: _clearDateFilter,
        hasDateFilter: _startDate != null || _endDate != null,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _refreshSales, child: body),
      ),
      bottomNavigationBar: AppBottomNav(
        activeTab: AppBottomTab.sales,
        onHome: () => _goTo(AppRoutes.home, reset: true),
        onSales: () {},
        onAdd: () => _goTo(AppRoutes.newSale),
        onItems: () => _goTo(AppRoutes.items, reset: true),
        onSettings: () => _goTo(AppRoutes.shop, reset: true),
      ),
    );
  }
}
