part of '../../live_cashier.dart';

const Duration _salesWindowCacheTtl = Duration(seconds: 12);
const int _salesWindowCacheMaxEntries = 12;

class _SalesWindowCacheEntry {
  const _SalesWindowCacheEntry({required this.createdAt, required this.sales});

  final DateTime createdAt;
  final List<Sale> sales;
}

extension _LiveCashierOverlayDraftReports on _LiveCashierOverlayState {
  DateTime _toolDayStart(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String _toolDayKey(DateTime value) {
    final day = _toolDayStart(value);
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }

  DateTime? _toolSaleDay(Sale sale) {
    final parsed = DateTime.tryParse(sale.createdAt);
    if (parsed == null) {
      return null;
    }
    return _toolDayStart(parsed);
  }

  double _toolAverage(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    return values.reduce((sum, value) => sum + value) / values.length;
  }

  double _toolSlope(List<double> values) {
    final count = values.length;
    if (count < 2) {
      return 0;
    }
    final meanX = (count - 1) / 2;
    final meanY = _toolAverage(values);
    var numerator = 0.0;
    var denominator = 0.0;
    for (var index = 0; index < count; index++) {
      final x = index.toDouble() - meanX;
      final y = values[index] - meanY;
      numerator += x * y;
      denominator += x * x;
    }
    if (denominator == 0) {
      return 0;
    }
    return numerator / denominator;
  }

  String _normalizedForecastCustomerText(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized.contains('@')) {
      return normalized;
    }
    final digits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits.isNotEmpty ? digits : normalized;
  }

  bool _saleMatchesCustomerQuery(Sale sale, String customerQuery) {
    final query = customerQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    final normalizedQuery = _normalizedForecastCustomerText(customerQuery);
    final customerName = (sale.customerName ?? '').trim().toLowerCase();
    final customerContact = _normalizedForecastCustomerText(
      sale.customerContact,
    );

    final nameMatches = customerName.isNotEmpty && customerName.contains(query);
    final contactMatches =
        normalizedQuery.isNotEmpty &&
        customerContact.isNotEmpty &&
        (customerContact.contains(normalizedQuery) ||
            customerContact.endsWith(normalizedQuery) ||
            normalizedQuery.endsWith(customerContact));
    return nameMatches || contactMatches;
  }

  String _customerAggregateKey(Sale sale) {
    final customerName = (sale.customerName ?? '').trim().toLowerCase();
    final customerContact = _normalizedForecastCustomerText(
      sale.customerContact,
    );
    if (customerContact.isNotEmpty) {
      return 'contact:$customerContact';
    }
    if (customerName.isNotEmpty) {
      return 'name:$customerName';
    }
    return '';
  }

  List<Map<String, dynamic>> _customerSummaries(
    Iterable<Sale> sales, {
    required String? currencyCode,
  }) {
    final summaries = <String, Map<String, dynamic>>{};
    for (final sale in sales) {
      final key = _customerAggregateKey(sale);
      if (key.isEmpty) {
        continue;
      }
      final existing = summaries[key];
      final saleDate = DateTime.tryParse(sale.createdAt);
      final customerName = (sale.customerName ?? '').trim();
      final customerContact = (sale.customerContact ?? '').trim();
      if (existing == null) {
        summaries[key] = {
          'customer_name': customerName,
          'customer_contact': customerContact,
          'sales_count': 1,
          'receipts_count': sale.status == SaleStatus.paid ? 1 : 0,
          'invoice_count': sale.status == SaleStatus.invoice ? 1 : 0,
          'total': sale.total,
          'last_sale_at': sale.createdAt,
          '_last_sale_sort': saleDate,
        };
        continue;
      }
      existing['sales_count'] = (existing['sales_count'] as int) + 1;
      existing['receipts_count'] =
          (existing['receipts_count'] as int) +
          (sale.status == SaleStatus.paid ? 1 : 0);
      existing['invoice_count'] =
          (existing['invoice_count'] as int) +
          (sale.status == SaleStatus.invoice ? 1 : 0);
      existing['total'] = (existing['total'] as double) + sale.total;
      if ((existing['customer_name'] as String).trim().isEmpty &&
          customerName.isNotEmpty) {
        existing['customer_name'] = customerName;
      }
      if ((existing['customer_contact'] as String).trim().isEmpty &&
          customerContact.isNotEmpty) {
        existing['customer_contact'] = customerContact;
      }
      final currentLastSale = existing['_last_sale_sort'] as DateTime?;
      if (saleDate != null &&
          (currentLastSale == null || saleDate.isAfter(currentLastSale))) {
        existing['last_sale_at'] = sale.createdAt;
        existing['_last_sale_sort'] = saleDate;
      }
    }

    final rows = summaries.values
        .map((entry) {
          return {
            'customer_name': entry['customer_name'],
            'customer_contact': entry['customer_contact'],
            'sales_count': entry['sales_count'],
            'receipts_count': entry['receipts_count'],
            'invoice_count': entry['invoice_count'],
            'total': entry['total'],
            'total_display': _formatToolMoney(
              (entry['total'] as num).toDouble(),
              currencyCode: currencyCode,
            ),
            'last_sale_at': entry['last_sale_at'],
            '_last_sale_sort': entry['_last_sale_sort'],
          };
        })
        .toList(growable: false);
    rows.sort((a, b) {
      final totalCompare = ((b['total'] as num?)?.toDouble() ?? 0).compareTo(
        (a['total'] as num?)?.toDouble() ?? 0,
      );
      if (totalCompare != 0) {
        return totalCompare;
      }
      final left = a['_last_sale_sort'] as DateTime?;
      final right = b['_last_sale_sort'] as DateTime?;
      if (left == null && right == null) {
        return 0;
      }
      if (left == null) {
        return 1;
      }
      if (right == null) {
        return -1;
      }
      return right.compareTo(left);
    });
    return rows
        .map(
          (entry) =>
              Map<String, dynamic>.from(entry)..remove('_last_sale_sort'),
        )
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _itemSummaries(
    Iterable<Sale> sales, {
    required String? currencyCode,
    String itemQuery = '',
  }) {
    final normalizedQuery = itemQuery.trim().toLowerCase();
    final summaries = <String, Map<String, dynamic>>{};
    for (final sale in sales) {
      final saleDate = DateTime.tryParse(sale.createdAt);
      for (final item in sale.items) {
        final productName = item.productName.trim();
        if (productName.isEmpty) {
          continue;
        }
        if (normalizedQuery.isNotEmpty &&
            !productName.toLowerCase().contains(normalizedQuery)) {
          continue;
        }
        final key = productName.toLowerCase();
        final existing = summaries[key];
        if (existing == null) {
          summaries[key] = {
            'product_name': productName,
            'quantity': item.quantity,
            'revenue': item.lineTotal,
            'sales_count': 1,
            'last_sold_at': sale.createdAt,
            '_last_sold_sort': saleDate,
          };
          continue;
        }
        existing['quantity'] = (existing['quantity'] as double) + item.quantity;
        existing['revenue'] = (existing['revenue'] as double) + item.lineTotal;
        existing['sales_count'] = (existing['sales_count'] as int) + 1;
        final currentLastSold = existing['_last_sold_sort'] as DateTime?;
        if (saleDate != null &&
            (currentLastSold == null || saleDate.isAfter(currentLastSold))) {
          existing['last_sold_at'] = sale.createdAt;
          existing['_last_sold_sort'] = saleDate;
        }
      }
    }

    final rows = summaries.values
        .map((entry) {
          return {
            'product_name': entry['product_name'],
            'quantity': entry['quantity'],
            'revenue': entry['revenue'],
            'revenue_display': _formatToolMoney(
              (entry['revenue'] as num).toDouble(),
              currencyCode: currencyCode,
            ),
            'sales_count': entry['sales_count'],
            'last_sold_at': entry['last_sold_at'],
            '_last_sold_sort': entry['_last_sold_sort'],
          };
        })
        .toList(growable: false);
    rows.sort((a, b) {
      final revenueCompare = ((b['revenue'] as num?)?.toDouble() ?? 0)
          .compareTo((a['revenue'] as num?)?.toDouble() ?? 0);
      if (revenueCompare != 0) {
        return revenueCompare;
      }
      return ((b['quantity'] as num?)?.toDouble() ?? 0).compareTo(
        (a['quantity'] as num?)?.toDouble() ?? 0,
      );
    });
    return rows
        .map(
          (entry) =>
              Map<String, dynamic>.from(entry)..remove('_last_sold_sort'),
        )
        .toList(growable: false);
  }

  String _toolTrendDirection(double slope, double baselineAverage) {
    final threshold = baselineAverage == 0 ? 1 : baselineAverage.abs() * 0.03;
    if (slope > threshold) {
      return 'up';
    }
    if (slope < -threshold) {
      return 'down';
    }
    return 'flat';
  }

  String _toolForecastConfidence({
    required int lookbackDays,
    required int nonZeroDays,
    required int totalSalesCount,
  }) {
    if (totalSalesCount <= 0 || nonZeroDays < 4 || lookbackDays < 7) {
      return 'low';
    }
    if (lookbackDays >= 60 && nonZeroDays >= 30) {
      return 'high';
    }
    if (lookbackDays >= 30 && nonZeroDays >= 14) {
      return 'medium';
    }
    return 'low';
  }

  Map<String, dynamic> _saleSummary(Sale sale) {
    final currencyCode = _toolCurrencyCode();
    final currencySymbol = _toolCurrencySymbol(currencyCode);
    return {
      'id': sale.id,
      'status': sale.status.name,
      'customer_name': sale.customerName,
      'customer_contact': sale.customerContact,
      'total': sale.total,
      'currency_code': currencyCode,
      'currency_symbol': currencySymbol,
      'total_display': _formatToolMoney(sale.total, currencyCode: currencyCode),
      'created_at': sale.createdAt,
      'items': sale.items
          .map(
            (item) => {
              'product_name': item.productName,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'unit_price_display': _formatToolMoney(
                item.unitPrice,
                currencyCode: currencyCode,
              ),
              'line_total_display': _formatToolMoney(
                item.lineTotal,
                currencyCode: currencyCode,
              ),
            },
          )
          .toList(growable: false),
    };
  }

  Future<Map<String, dynamic>> _searchSalesTool(
    Map<String, dynamic> args,
    SaleStatus status,
  ) async {
    final limit = _toolOptionalLimit(args['limit']);
    final date = _toolDate(args['date']?.toString());
    final query =
        (args['customer_query']?.toString() ?? args['query']?.toString() ?? '')
            .trim();
    final sales = await _api.listSales(
      page: 1,
      perPage: 50,
      includeItems: true,
      status: status,
      searchQuery: query.isEmpty ? null : query,
      startDate: date,
      endDate: date,
    );
    final matches = (limit == null ? sales : sales.take(limit))
        .map(_saleSummary)
        .toList(growable: false);
    final shouldOpen = args['open_first_match'] == true && sales.isNotEmpty;
    return {
      'matches': matches,
      'count': sales.length,
      if (shouldOpen) 'open_sale_id': sales.first.id,
    };
  }

  Future<List<Sale>> _listSalesWindow({
    SaleStatus? status,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    int perPage = 100,
    int maxPages = 15,
  }) async {
    final normalizedSearchQuery = (searchQuery ?? '').trim().toLowerCase();
    final cacheKey = [
      status?.name ?? 'all',
      normalizedSearchQuery,
      startDate?.toIso8601String() ?? '',
      endDate?.toIso8601String() ?? '',
      perPage,
      maxPages,
    ].join('|');
    final now = DateTime.now();
    final cached = _salesWindowCache[cacheKey];
    if (cached != null &&
        now.difference(cached.createdAt) <= _salesWindowCacheTtl) {
      return cached.sales;
    }

    final results = <Sale>[];
    for (var page = 1; page <= maxPages; page++) {
      final batch = await _api.listSales(
        page: page,
        perPage: perPage,
        includeItems: true,
        status: status,
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
      );
      results.addAll(batch);
      if (batch.length < perPage) {
        break;
      }
    }
    _salesWindowCache[cacheKey] = _SalesWindowCacheEntry(
      createdAt: now,
      sales: List<Sale>.unmodifiable(results),
    );
    _pruneSalesWindowCache(now);
    return _salesWindowCache[cacheKey]!.sales;
  }

  void _pruneSalesWindowCache([DateTime? referenceTime]) {
    final now = referenceTime ?? DateTime.now();
    final expiredKeys = _salesWindowCache.entries
        .where(
          (entry) =>
              now.difference(entry.value.createdAt) > _salesWindowCacheTtl,
        )
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in expiredKeys) {
      _salesWindowCache.remove(key);
    }
    if (_salesWindowCache.length <= _salesWindowCacheMaxEntries) {
      return;
    }
    final sortedEntries = _salesWindowCache.entries.toList(growable: false)
      ..sort(
        (left, right) => left.value.createdAt.compareTo(right.value.createdAt),
      );
    final overflow = _salesWindowCache.length - _salesWindowCacheMaxEntries;
    for (var index = 0; index < overflow; index++) {
      _salesWindowCache.remove(sortedEntries[index].key);
    }
  }

  void _clearSalesWindowCache() {
    _salesWindowCache.clear();
  }

  Future<Map<String, dynamic>> _salesMetricsTool(
    Map<String, dynamic> args,
  ) async {
    final limit = _toolOptionalLimit(args['limit']);
    final startDate = _toolDate(
      args['start_date']?.toString() ?? args['date']?.toString(),
    );
    final endDate = _toolDate(
      args['end_date']?.toString() ?? args['date']?.toString(),
    );
    final customerQuery =
        (args['customer_query']?.toString() ?? args['query']?.toString() ?? '')
            .trim();
    final itemQuery = (args['item_query']?.toString() ?? '').trim();
    final statusRaw = (args['status']?.toString() ?? '').trim().toLowerCase();
    final status = switch (statusRaw) {
      'receipt' || 'paid' => SaleStatus.paid,
      'invoice' => SaleStatus.invoice,
      _ => null,
    };
    final searchQuery = (customerQuery.isNotEmpty ? customerQuery : itemQuery)
        .trim();
    final sales = await _listSalesWindow(
      status: status,
      searchQuery: searchQuery.isEmpty ? null : searchQuery,
      startDate: startDate,
      endDate: endDate,
    );

    final loweredItemQuery = itemQuery.toLowerCase();
    final filteredSales = itemQuery.isEmpty
        ? sales
        : sales
              .where((sale) {
                return sale.items.any(
                  (item) =>
                      item.productName.toLowerCase().contains(loweredItemQuery),
                );
              })
              .toList(growable: false);

    final paidReceipts = filteredSales
        .where((sale) => sale.status == SaleStatus.paid)
        .toList(growable: false);
    final invoices = filteredSales
        .where((sale) => sale.status == SaleStatus.invoice)
        .toList(growable: false);
    final paidReceiptsTotal = paidReceipts.fold<double>(
      0,
      (sum, sale) => sum + sale.total,
    );
    final invoicesTotal = invoices.fold<double>(
      0,
      (sum, sale) => sum + sale.total,
    );
    final allTotal = filteredSales.fold<double>(
      0,
      (sum, sale) => sum + sale.total,
    );
    final customerNames = filteredSales
        .map((sale) => (sale.customerName ?? '').trim())
        .where((name) => name.isNotEmpty)
        .toSet();

    final itemBreakdown = <String, Map<String, dynamic>>{};
    for (final sale in filteredSales) {
      for (final item in sale.items) {
        if (itemQuery.isNotEmpty &&
            !item.productName.toLowerCase().contains(loweredItemQuery)) {
          continue;
        }
        final entry = itemBreakdown.putIfAbsent(
          item.productName,
          () => {
            'product_name': item.productName,
            'quantity': 0.0,
            'revenue': 0.0,
          },
        );
        entry['quantity'] = (entry['quantity'] as double) + item.quantity;
        entry['revenue'] = (entry['revenue'] as double) + item.lineTotal;
      }
    }

    final currencyCode = _toolCurrencyCode();
    final currencySymbol = _toolCurrencySymbol(currencyCode);
    return {
      'status_filter': statusRaw.isEmpty ? 'all' : statusRaw,
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'customer_query': customerQuery.isEmpty ? null : customerQuery,
      'item_query': itemQuery.isEmpty ? null : itemQuery,
      'count': filteredSales.length,
      'customer_count': customerNames.length,
      'paid_receipts_count': paidReceipts.length,
      'invoice_count': invoices.length,
      'currency_code': currencyCode,
      'currency_symbol': currencySymbol,
      'paid_receipts_total': paidReceiptsTotal,
      'paid_receipts_total_display': _formatToolMoney(
        paidReceiptsTotal,
        currencyCode: currencyCode,
      ),
      'invoice_total': invoicesTotal,
      'invoice_total_display': _formatToolMoney(
        invoicesTotal,
        currencyCode: currencyCode,
      ),
      'all_total': allTotal,
      'all_total_display': _formatToolMoney(
        allTotal,
        currencyCode: currencyCode,
      ),
      'matches': (limit == null ? filteredSales : filteredSales.take(limit))
          .map(_saleSummary)
          .toList(growable: false),
      'item_breakdown': itemBreakdown.values
          .map(
            (item) => {
              ...item,
              'revenue_display': _formatToolMoney(
                item['revenue'] as double,
                currencyCode: currencyCode,
              ),
            },
          )
          .toList(growable: false),
    };
  }

  Future<Map<String, dynamic>> _listCustomersTool(
    Map<String, dynamic> args,
  ) async {
    final limit = _toolOptionalLimit(args['limit']);
    final startDate = _toolDate(
      args['start_date']?.toString() ?? args['date']?.toString(),
    );
    final endDate = _toolDate(
      args['end_date']?.toString() ?? args['date']?.toString(),
    );
    final customerQuery =
        (args['customer_query']?.toString() ?? args['query']?.toString() ?? '')
            .trim();
    final statusRaw = (args['status']?.toString() ?? '').trim().toLowerCase();
    final status = switch (statusRaw) {
      'receipt' || 'paid' => SaleStatus.paid,
      'invoice' => SaleStatus.invoice,
      _ => null,
    };
    final sales = await _listSalesWindow(
      status: status,
      searchQuery: customerQuery.isEmpty ? null : customerQuery,
      startDate: startDate,
      endDate: endDate,
    );
    final filteredSales = customerQuery.isEmpty
        ? sales
        : sales
              .where((sale) => _saleMatchesCustomerQuery(sale, customerQuery))
              .toList(growable: false);
    final currencyCode = _toolCurrencyCode();
    final customers = _customerSummaries(
      filteredSales,
      currencyCode: currencyCode,
    );
    final itemBreakdown = <String, Map<String, dynamic>>{};
    for (final sale in filteredSales) {
      for (final item in sale.items) {
        final entry = itemBreakdown.putIfAbsent(
          item.productName,
          () => {
            'product_name': item.productName,
            'quantity': 0.0,
            'revenue': 0.0,
          },
        );
        entry['quantity'] = (entry['quantity'] as double) + item.quantity;
        entry['revenue'] = (entry['revenue'] as double) + item.lineTotal;
      }
    }
    final total = customers.fold<double>(
      0,
      (sum, customer) => sum + ((customer['total'] as num?)?.toDouble() ?? 0),
    );
    return {
      'status_filter': statusRaw.isEmpty ? 'all' : statusRaw,
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'customer_query': customerQuery.isEmpty ? null : customerQuery,
      'count': customers.length,
      'matched_customer_count': customers.length,
      'currency_code': currencyCode,
      'currency_symbol': _toolCurrencySymbol(currencyCode),
      'all_total': total,
      'all_total_display': _formatToolMoney(total, currencyCode: currencyCode),
      'customers': (limit == null ? customers : customers.take(limit)).toList(
        growable: false,
      ),
      'matches': (limit == null ? filteredSales : filteredSales.take(limit))
          .map(_saleSummary)
          .toList(growable: false),
      'item_breakdown': itemBreakdown.values
          .map(
            (item) => {
              ...item,
              'revenue_display': _formatToolMoney(
                item['revenue'] as double,
                currencyCode: currencyCode,
              ),
            },
          )
          .toList(growable: false),
    };
  }

  Future<Map<String, dynamic>> _listItemsTool(Map<String, dynamic> args) async {
    final limit = _toolOptionalLimit(args['limit']);
    final startDate = _toolDate(
      args['start_date']?.toString() ?? args['date']?.toString(),
    );
    final endDate = _toolDate(
      args['end_date']?.toString() ?? args['date']?.toString(),
    );
    final itemQuery =
        (args['item_query']?.toString() ?? args['query']?.toString() ?? '')
            .trim();
    final statusRaw = (args['status']?.toString() ?? '').trim().toLowerCase();
    final status = switch (statusRaw) {
      'receipt' || 'paid' => SaleStatus.paid,
      'invoice' => SaleStatus.invoice,
      _ => null,
    };
    final sales = await _listSalesWindow(
      status: status,
      searchQuery: itemQuery.isEmpty ? null : itemQuery,
      startDate: startDate,
      endDate: endDate,
    );
    final currencyCode = _toolCurrencyCode();
    final items = _itemSummaries(
      sales,
      currencyCode: currencyCode,
      itemQuery: itemQuery,
    );
    final totalRevenue = items.fold<double>(
      0,
      (sum, item) => sum + ((item['revenue'] as num?)?.toDouble() ?? 0),
    );
    final totalQuantity = items.fold<double>(
      0,
      (sum, item) => sum + ((item['quantity'] as num?)?.toDouble() ?? 0),
    );
    return {
      'status_filter': statusRaw.isEmpty ? 'all' : statusRaw,
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'item_query': itemQuery.isEmpty ? null : itemQuery,
      'count': items.length,
      'currency_code': currencyCode,
      'currency_symbol': _toolCurrencySymbol(currencyCode),
      'all_total': totalRevenue,
      'all_total_display': _formatToolMoney(
        totalRevenue,
        currencyCode: currencyCode,
      ),
      'total_quantity': totalQuantity,
      'items': (limit == null ? items : items.take(limit)).toList(
        growable: false,
      ),
    };
  }

  Future<Map<String, dynamic>> _forecastSalesTool(
    Map<String, dynamic> args,
  ) async {
    final now = _toolDayStart(DateTime.now());
    final horizonDays = _toolLimit(
      args['horizon_days'] ?? args['days'],
      fallback: 7,
      max: 31,
    );
    final lookbackDays = _toolLimit(
      args['lookback_days'],
      fallback: 30,
      max: 180,
    );
    final explicitStartDate = _toolDate(args['start_date']?.toString());
    final explicitEndDate = _toolDate(args['end_date']?.toString());
    var startDate = explicitStartDate == null
        ? now.subtract(Duration(days: lookbackDays - 1))
        : _toolDayStart(explicitStartDate);
    var endDate = explicitEndDate == null
        ? now
        : _toolDayStart(explicitEndDate);
    if (startDate.isAfter(endDate)) {
      final swap = startDate;
      startDate = endDate;
      endDate = swap;
    }

    final customerQuery =
        (args['customer_query']?.toString() ?? args['query']?.toString() ?? '')
            .trim();
    final itemQuery = (args['item_query']?.toString() ?? '').trim();
    final statusRaw = (args['status']?.toString() ?? '').trim().toLowerCase();
    final status = switch (statusRaw) {
      'receipt' || 'paid' => SaleStatus.paid,
      'invoice' => SaleStatus.invoice,
      _ => null,
    };
    final searchQuery = (customerQuery.isNotEmpty ? customerQuery : itemQuery)
        .trim();
    final sales = await _listSalesWindow(
      status: status,
      searchQuery: searchQuery.isEmpty ? null : searchQuery,
      startDate: startDate,
      endDate: endDate,
    );
    final loweredItemQuery = itemQuery.toLowerCase();
    final customerFilteredSales = customerQuery.isEmpty
        ? sales
        : sales
              .where((sale) => _saleMatchesCustomerQuery(sale, customerQuery))
              .toList(growable: false);
    final filteredSales = itemQuery.isEmpty
        ? customerFilteredSales
        : customerFilteredSales
              .where((sale) {
                return sale.items.any(
                  (item) =>
                      item.productName.toLowerCase().contains(loweredItemQuery),
                );
              })
              .toList(growable: false);
    final forecastScope = customerQuery.isNotEmpty
        ? 'customer'
        : itemQuery.isNotEmpty
        ? 'item'
        : 'shop';
    final scopeLabel = customerQuery.isNotEmpty
        ? 'customer "$customerQuery"'
        : itemQuery.isNotEmpty
        ? 'item "$itemQuery"'
        : 'overall shop sales';
    final matchedCustomerNames = filteredSales
        .map((sale) => (sale.customerName ?? '').trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final totalDays = endDate.difference(startDate).inDays + 1;
    final dayRange = List<DateTime>.generate(
      totalDays,
      (index) => startDate.add(Duration(days: index)),
      growable: false,
    );
    final dailyRevenue = <String, double>{};
    final dailyOrders = <String, int>{};

    for (final sale in filteredSales) {
      final saleDay = _toolSaleDay(sale);
      if (saleDay == null) {
        continue;
      }
      final key = _toolDayKey(saleDay);
      dailyRevenue[key] = (dailyRevenue[key] ?? 0) + sale.total;
      dailyOrders[key] = (dailyOrders[key] ?? 0) + 1;
    }

    final revenueSeries = dayRange
        .map((day) => dailyRevenue[_toolDayKey(day)] ?? 0)
        .toList(growable: false);
    final orderSeries = dayRange
        .map((day) => (dailyOrders[_toolDayKey(day)] ?? 0).toDouble())
        .toList(growable: false);
    final baselineRevenueAverage = _toolAverage(revenueSeries);
    final recentRevenueSeries = revenueSeries.length <= 7
        ? revenueSeries
        : revenueSeries.sublist(revenueSeries.length - 7);
    final recentOrderSeries = orderSeries.length <= 7
        ? orderSeries
        : orderSeries.sublist(orderSeries.length - 7);
    final recentRevenueAverage = _toolAverage(recentRevenueSeries);
    final recentOrderAverage = _toolAverage(recentOrderSeries);
    final revenueSlope = _toolSlope(revenueSeries);
    final orderSlope = _toolSlope(orderSeries);
    final trendDirection = _toolTrendDirection(
      revenueSlope,
      baselineRevenueAverage,
    );
    final nonZeroDays = revenueSeries.where((value) => value > 0).length;
    final confidence = _toolForecastConfidence(
      lookbackDays: totalDays,
      nonZeroDays: nonZeroDays,
      totalSalesCount: filteredSales.length,
    );
    final forecastPoints = <Map<String, dynamic>>[];
    var forecastRevenueTotal = 0.0;
    var forecastOrdersTotal = 0.0;

    for (var dayIndex = 1; dayIndex <= horizonDays; dayIndex++) {
      final forecastDate = endDate.add(Duration(days: dayIndex));
      final projectedRevenue =
          (recentRevenueAverage + (revenueSlope * dayIndex)).clamp(
            0,
            double.infinity,
          );
      final projectedOrders = (recentOrderAverage + (orderSlope * dayIndex))
          .clamp(0, double.infinity);
      forecastRevenueTotal += projectedRevenue;
      forecastOrdersTotal += projectedOrders;
      forecastPoints.add({
        'period': _toolDayKey(forecastDate),
        'projected_total': projectedRevenue,
        'projected_total_display': _formatToolMoney(
          projectedRevenue,
          currencyCode: _toolCurrencyCode(),
        ),
        'projected_orders': projectedOrders.round(),
      });
    }

    final currencyCode = _toolCurrencyCode();
    final currencySymbol = _toolCurrencySymbol(currencyCode);
    if (filteredSales.isEmpty) {
      final missingMessage = customerQuery.isNotEmpty
          ? 'Not enough sales data to forecast this customer yet.'
          : itemQuery.isNotEmpty
          ? 'Not enough sales data to forecast this item yet.'
          : 'Not enough sales data to forecast yet.';
      return {
        'result': 'insufficient_data',
        'message': missingMessage,
        'forecast_scope': forecastScope,
        'scope_label': scopeLabel,
        'status_filter': statusRaw.isEmpty ? 'all' : statusRaw,
        'start_date': _toolDayKey(startDate),
        'end_date': _toolDayKey(endDate),
        'forecast_horizon_days': horizonDays,
        'customer_query': customerQuery.isEmpty ? null : customerQuery,
        'item_query': itemQuery.isEmpty ? null : itemQuery,
        'currency_code': currencyCode,
        'currency_symbol': currencySymbol,
      };
    }

    return {
      'result': 'ok',
      'forecast_scope': forecastScope,
      'scope_label': scopeLabel,
      'status_filter': statusRaw.isEmpty ? 'all' : statusRaw,
      'start_date': _toolDayKey(startDate),
      'end_date': _toolDayKey(endDate),
      'lookback_days': totalDays,
      'forecast_horizon_days': horizonDays,
      'customer_query': customerQuery.isEmpty ? null : customerQuery,
      'item_query': itemQuery.isEmpty ? null : itemQuery,
      'matched_customer_count': matchedCustomerNames.length,
      'matched_customers': matchedCustomerNames
          .take(10)
          .toList(growable: false),
      'currency_code': currencyCode,
      'currency_symbol': currencySymbol,
      'historical_sales_count': filteredSales.length,
      'historical_daily_average': baselineRevenueAverage,
      'historical_daily_average_display': _formatToolMoney(
        baselineRevenueAverage,
        currencyCode: currencyCode,
      ),
      'recent_daily_average': recentRevenueAverage,
      'recent_daily_average_display': _formatToolMoney(
        recentRevenueAverage,
        currencyCode: currencyCode,
      ),
      'forecast_total': forecastRevenueTotal,
      'forecast_total_display': _formatToolMoney(
        forecastRevenueTotal,
        currencyCode: currencyCode,
      ),
      'forecast_average_per_day': horizonDays <= 0
          ? 0
          : forecastRevenueTotal / horizonDays,
      'forecast_average_per_day_display': _formatToolMoney(
        horizonDays <= 0 ? 0 : forecastRevenueTotal / horizonDays,
        currencyCode: currencyCode,
      ),
      'forecast_orders_total': forecastOrdersTotal.round(),
      'trend_direction': trendDirection,
      'confidence': confidence,
      'forecast_basis':
          'Estimated for $scopeLabel from $totalDays days of historical sales using recent daily average and trend.',
      'historical_daily_points': dayRange
          .map((day) {
            final key = _toolDayKey(day);
            final total = dailyRevenue[key] ?? 0;
            return {
              'period': key,
              'total': total,
              'total_display': _formatToolMoney(
                total,
                currencyCode: currencyCode,
              ),
              'orders': dailyOrders[key] ?? 0,
            };
          })
          .toList(growable: false),
      'forecast_points': forecastPoints,
    };
  }

  Future<Map<String, dynamic>> _dashboardSummaryTool() async {
    final home = await _api.getHomeSummary();
    final daily = home.analytics.daily;
    final today = daily.isNotEmpty ? daily.first : null;
    final yesterday = daily.length > 1 ? daily[1] : null;
    final currencyCode = home.shop.currencyCode.trim().toUpperCase();
    final currencySymbol = _toolCurrencySymbol(currencyCode);
    return {
      'currency_code': currencyCode,
      'currency_symbol': currencySymbol,
      'shop_timezone': home.shop.timezone,
      'today_period': today?.period,
      'today_total': today?.total ?? 0,
      'today_total_display': _formatToolMoney(
        today?.total ?? 0,
        currencyCode: currencyCode,
      ),
      'today_units': today?.units ?? 0,
      'yesterday_period': yesterday?.period,
      'yesterday_total': yesterday?.total ?? 0,
      'yesterday_total_display': _formatToolMoney(
        yesterday?.total ?? 0,
        currencyCode: currencyCode,
      ),
      'yesterday_units': yesterday?.units ?? 0,
      'daily_points': daily
          .take(7)
          .map(
            (point) => {
              'period': point.period,
              'total': point.total,
              'total_display': _formatToolMoney(
                point.total,
                currencyCode: currencyCode,
              ),
              'units': point.units,
            },
          )
          .toList(growable: false),
      'recent_receipts': home.recentSales
          .take(5)
          .map(_saleSummary)
          .toList(growable: false),
      'recent_sales': home.recentSales
          .take(5)
          .map(_saleSummary)
          .toList(growable: false),
      'fast_moving': home.analytics.fastMoving
          .take(3)
          .map(
            (item) => {
              'product_name': item.productName,
              'quantity': item.quantity,
            },
          )
          .toList(growable: false),
      'slow_moving': home.analytics.slowMoving
          .take(3)
          .map(
            (item) => {
              'product_name': item.productName,
              'quantity': item.quantity,
            },
          )
          .toList(growable: false),
    };
  }

  Future<Map<String, dynamic>> _itemSalesTool(Map<String, dynamic> args) async {
    final query = (args['item_query']?.toString() ?? '').trim();
    if (query.isEmpty) {
      return const {'matches': <Map<String, dynamic>>[], 'count': 0};
    }
    final date = _toolDate(args['date']?.toString());
    final sales = await _api.listSales(
      page: 1,
      perPage: 100,
      includeItems: true,
      status: SaleStatus.paid,
      searchQuery: query,
      startDate: date,
      endDate: date,
    );
    final totals = <String, Map<String, dynamic>>{};
    final lowered = query.toLowerCase();
    for (final sale in sales) {
      for (final item in sale.items) {
        if (!item.productName.toLowerCase().contains(lowered)) continue;
        final entry = totals.putIfAbsent(
          item.productName,
          () => {
            'product_name': item.productName,
            'quantity': 0.0,
            'revenue': 0.0,
          },
        );
        entry['quantity'] = (entry['quantity'] as double) + item.quantity;
        entry['revenue'] = (entry['revenue'] as double) + item.lineTotal;
      }
    }
    return {
      'matches': totals.values.toList(growable: false),
      'count': totals.length,
    };
  }

  Future<List<Map<String, dynamic>>> _movementItemsTool({
    required bool fast,
    dynamic limit,
  }) async {
    final analytics = await _api.getAnalytics();
    final items = (fast ? analytics.fastMoving : analytics.slowMoving)
        .take(_toolLimit(limit))
        .map(
          (item) => {
            'product_name': item.productName,
            'quantity': item.quantity,
            'sold_30_days': item.sold30Days,
          },
        )
        .toList(growable: false);
    return items;
  }
}
