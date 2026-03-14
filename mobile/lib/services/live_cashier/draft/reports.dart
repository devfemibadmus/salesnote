part of '../../live_cashier.dart';

extension _LiveCashierOverlayDraftReports on _LiveCashierOverlayState {
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
          .map((item) => {
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
              })
          .toList(growable: false),
    };
  }

  Future<Map<String, dynamic>> _searchSalesTool(
    Map<String, dynamic> args,
    SaleStatus status,
  ) async {
    final limit = _toolLimit(args['limit'], fallback: 5, max: 25);
    final date = _toolDate(args['date']?.toString());
    final query = (args['customer_query']?.toString() ??
            args['query']?.toString() ??
            '')
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
    final matches = sales.take(limit).map(_saleSummary).toList(growable: false);
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
    return results;
  }

  Future<Map<String, dynamic>> _salesMetricsTool(Map<String, dynamic> args) async {
    final limit = _toolLimit(args['limit'], fallback: 10, max: 50);
    final startDate = _toolDate(
      args['start_date']?.toString() ?? args['date']?.toString(),
    );
    final endDate = _toolDate(
      args['end_date']?.toString() ?? args['date']?.toString(),
    );
    final customerQuery = (args['customer_query']?.toString() ??
            args['query']?.toString() ??
            '')
        .trim();
    final itemQuery = (args['item_query']?.toString() ?? '').trim();
    final statusRaw = (args['status']?.toString() ?? '').trim().toLowerCase();
    final status = switch (statusRaw) {
      'receipt' || 'paid' => SaleStatus.paid,
      'invoice' => SaleStatus.invoice,
      _ => null,
    };
    final searchQuery = (customerQuery.isNotEmpty ? customerQuery : itemQuery).trim();
    final sales = await _listSalesWindow(
      status: status,
      searchQuery: searchQuery.isEmpty ? null : searchQuery,
      startDate: startDate,
      endDate: endDate,
    );

    final loweredItemQuery = itemQuery.toLowerCase();
    final filteredSales = itemQuery.isEmpty
        ? sales
        : sales.where((sale) {
            return sale.items.any(
              (item) => item.productName.toLowerCase().contains(loweredItemQuery),
            );
          }).toList(growable: false);

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
    final allTotal = filteredSales.fold<double>(0, (sum, sale) => sum + sale.total);
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
      'matches': filteredSales.take(limit).map(_saleSummary).toList(growable: false),
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
          .map((point) => {
                'period': point.period,
                'total': point.total,
                'total_display': _formatToolMoney(
                  point.total,
                  currencyCode: currencyCode,
                ),
                'units': point.units,
              })
          .toList(growable: false),
      'recent_receipts': home.recentSales.take(5).map(_saleSummary).toList(growable: false),
      'recent_sales': home.recentSales.take(5).map(_saleSummary).toList(growable: false),
      'fast_moving': home.analytics.fastMoving
          .take(3)
          .map((item) => {
                'product_name': item.productName,
                'quantity': item.quantity,
              })
          .toList(growable: false),
      'slow_moving': home.analytics.slowMoving
          .take(3)
          .map((item) => {
                'product_name': item.productName,
                'quantity': item.quantity,
              })
          .toList(growable: false),
    };
  }

  Future<Map<String, dynamic>> _itemSalesTool(Map<String, dynamic> args) async {
    final query = (args['item_query']?.toString() ?? '').trim();
    if (query.isEmpty) {
      return const {
        'matches': <Map<String, dynamic>>[],
        'count': 0,
      };
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
        .map((item) => {
              'product_name': item.productName,
              'quantity': item.quantity,
              'sold_30_days': item.sold30Days,
            })
        .toList(growable: false);
    return items;
  }
}
