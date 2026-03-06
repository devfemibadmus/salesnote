import '../../data/models.dart';
import '../api_client.dart';
import 'local.dart';

class CachedSalesPage {
  const CachedSalesPage({
    required this.sales,
    required this.page,
    required this.hasMore,
  });

  final List<Sale> sales;
  final int page;
  final bool hasMore;
}

class CacheLoader {
  CacheLoader._();

  static Future<HomeSummary?> loadOrFetchHomeSummary(ApiClient api) async {
    final cached = loadHomeSummaryCache();
    if (cached != null) return cached;

    try {
      final fresh = await api.getHomeSummary();
      await saveHomeSummaryCache(fresh);
      return fresh;
    } catch (_) {
      return null;
    }
  }

  static Future<HomeSummary> fetchAndCacheHomeSummary(ApiClient api) async {
    final fresh = await api.getHomeSummary();
    await saveHomeSummaryCache(fresh);
    return fresh;
  }

  static HomeSummary? loadHomeSummaryCache() {
    final raw = LocalCache.loadHomeSummary();
    if (raw == null) return null;
    try {
      return HomeSummary.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveHomeSummaryCache(HomeSummary data) {
    return LocalCache.saveHomeSummary(data.toJson());
  }

  static Future<SettingsSummary?> loadOrFetchSettingsSummary(
    ApiClient api,
  ) async {
    final cached = loadSettingsSummaryCache();
    if (cached != null) return cached;

    try {
      final fresh = await api.getSettingsSummary();
      await saveSettingsSummaryCache(fresh);
      return fresh;
    } catch (_) {
      return null;
    }
  }

  static Future<SettingsSummary> fetchAndCacheSettingsSummary(
    ApiClient api,
  ) async {
    final fresh = await api.getSettingsSummary();
    await saveSettingsSummaryCache(fresh);
    return fresh;
  }

  static SettingsSummary? loadSettingsSummaryCache() {
    final raw = LocalCache.loadSettingsSummary();
    if (raw == null) return null;
    try {
      return SettingsSummary.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSettingsSummaryCache(SettingsSummary data) {
    return LocalCache.saveSettingsSummary(data.toJson());
  }

  static Future<List<SignatureItem>> loadOrFetchSignatures(
    ApiClient api,
  ) async {
    final cached = loadSignaturesCache();
    if (cached.isNotEmpty) return cached;

    try {
      final fresh = await api.listSignatures();
      await saveSignaturesCache(fresh);
      return fresh;
    } catch (_) {
      return const <SignatureItem>[];
    }
  }

  static Future<List<SignatureItem>> fetchAndCacheSignatures(
    ApiClient api,
  ) async {
    final fresh = await api.listSignatures();
    await saveSignaturesCache(fresh);
    return fresh;
  }

  static List<SignatureItem> loadSignaturesCache() {
    final raw = LocalCache.loadSignatures();
    if (raw.isEmpty) return const <SignatureItem>[];
    try {
      return raw.map(SignatureItem.fromJson).toList();
    } catch (_) {
      return const <SignatureItem>[];
    }
  }

  static Future<void> saveSignaturesCache(List<SignatureItem> signatures) {
    return LocalCache.saveSignatures(
      signatures.map((e) => e.toJson()).toList(),
    );
  }

  static Future<CachedSalesPage?> loadOrFetchSalesPage(
    ApiClient api, {
    required bool includeItems,
    required int perPage,
  }) async {
    final cached = loadSalesPageCache(includeItems: includeItems);
    if (cached != null) return cached;

    try {
      final sales = await api.listSales(
        page: 1,
        perPage: perPage,
        includeItems: includeItems,
      );
      final pageData = CachedSalesPage(
        sales: sales,
        page: 1,
        hasMore: sales.length == perPage,
      );
      await saveSalesPageCache(includeItems: includeItems, data: pageData);
      return pageData;
    } catch (_) {
      return null;
    }
  }

  static Future<CachedSalesPage> fetchAndCacheSalesPage(
    ApiClient api, {
    required bool includeItems,
    required int page,
    required int perPage,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final sales = await api.listSales(
      page: page,
      perPage: perPage,
      includeItems: includeItems,
      searchQuery: searchQuery,
      startDate: startDate,
      endDate: endDate,
    );
    final pageData = CachedSalesPage(
      sales: sales,
      page: page,
      hasMore: sales.length == perPage,
    );

    final shouldCacheFirstPage = page == 1 &&
        (searchQuery == null || searchQuery.trim().isEmpty) &&
        startDate == null &&
        endDate == null;
    if (shouldCacheFirstPage) {
      await saveSalesPageCache(includeItems: includeItems, data: pageData);
    }

    return pageData;
  }

  static CachedSalesPage? loadSalesPageCache({required bool includeItems}) {
    final raw = LocalCache.loadSalesPage(includeItems: includeItems);
    if (raw == null) return null;
    try {
      final salesRaw = (raw['sales'] as List).cast<dynamic>();
      final sales = salesRaw.map((e) => Sale.fromJson(e)).toList();
      return CachedSalesPage(
        sales: sales,
        page: (raw['page'] as num?)?.toInt() ?? 1,
        hasMore: raw['has_more'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSalesPageCache({
    required bool includeItems,
    required CachedSalesPage data,
  }) {
    return LocalCache.saveSalesPage(
      includeItems: includeItems,
      sales: data.sales.map((e) => e.toJson()).toList(),
      page: data.page,
      hasMore: data.hasMore,
    );
  }

  static Future<Sale?> loadOrFetchSalePreview(
    ApiClient api,
    String saleId,
  ) async {
    final cached = loadSalePreviewCache(saleId);
    if (cached != null) return cached;

    try {
      final fresh = await api.getSale(saleId);
      await saveSalePreviewCache(fresh);
      return fresh;
    } catch (_) {
      return null;
    }
  }

  static Sale? loadSalePreviewCache(String saleId) {
    final raw = LocalCache.loadSalePreview(saleId);
    if (raw == null) return null;
    try {
      return Sale.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSalePreviewCache(Sale sale) {
    return LocalCache.saveSalePreview(sale.id, sale.toJson());
  }

  static List<String> loadItemSuggestionsCache() {
    return LocalCache.loadItemSuggestions();
  }

  static Future<void> saveItemSuggestionsCache(List<String> names) {
    return LocalCache.saveItemSuggestions(names);
  }

  static List<Map<String, dynamic>> loadNotificationsCacheRaw() {
    return LocalCache.loadNotifications();
  }

  static Future<void> saveNotificationsCacheRaw(
    List<Map<String, dynamic>> data,
  ) {
    return LocalCache.saveNotifications(data);
  }
}
