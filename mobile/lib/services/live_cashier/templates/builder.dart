part of '../../live_cashier.dart';

extension _LiveCashierOverlayTemplates on _LiveCashierOverlayState {
  _TemplateCardData? _buildResponseTemplateCard(
    String name,
    Map<String, dynamic> response,
  ) {
    return _buildDraftTemplateCard(name, response) ??
        _buildForecastTemplateCard(name, response) ??
        _buildTrendTemplateCard(name, response) ??
        _buildSaleReportTemplateCard(name, response) ??
        _buildListTemplateCard(name, response);
  }

  _TemplateCardData? _buildDraftTemplateCard(
    String name,
    Map<String, dynamic> response,
  ) {
    final summary = _templateMap(response['draft_summary']);
    if (summary == null) {
      return null;
    }

    final items = _templateMapList(summary['items']);
    final missingLabels = _templateStringList(response['missing_labels']);
    final signatures = _templateMapList(response['available_signatures']);
    final bankAccounts = _templateMapList(response['available_bank_accounts']);
    final kind =
        (summary['kind']?.toString() ?? '').trim().toLowerCase() == 'invoice'
        ? 'Invoice draft'
        : 'Receipt draft';
    final customerName = (summary['customer_name']?.toString() ?? '').trim();
    final customerContact = (summary['customer_contact']?.toString() ?? '')
        .trim();
    final statusText = response['message']?.toString().trim();
    final rows = <_TemplateRow>[
      for (final item in items.take(4))
        _TemplateRow(
          title: (item['product_name']?.toString() ?? '').trim().isEmpty
              ? 'Item'
              : item['product_name']!.toString().trim(),
          subtitle: _joinTemplateParts(<String>[
            if ((item['quantity']?.toString() ?? '').trim().isNotEmpty)
              'Qty ${item['quantity']}',
            if ((item['unit_price_display']?.toString() ?? '')
                .trim()
                .isNotEmpty)
              item['unit_price_display']!.toString().trim(),
          ]),
          trailing: (item['line_total_display']?.toString() ?? '').trim(),
        ),
      for (final option in signatures.take(2))
        _TemplateRow(
          title: 'Signature: ${(option['name']?.toString() ?? '').trim()}',
          subtitle: 'Available to use',
        ),
      for (final option in bankAccounts.take(2))
        _TemplateRow(
          title:
              '${(option['bank_name']?.toString() ?? '').trim()} ${(option['account_number']?.toString() ?? '').trim()}'
                  .trim(),
          subtitle: (option['account_name']?.toString() ?? '').trim().isEmpty
              ? 'Available bank account'
              : option['account_name']!.toString().trim(),
        ),
    ];

    return _TemplateCardData(
      kind: _TemplateKind.draft,
      signature: _templateSignature(name, <Object?>[
        summary['draft_id'],
        summary['total_display'],
        customerName,
        customerContact,
        items.length,
        missingLabels.join('|'),
        signatures.length,
        bankAccounts.length,
      ]),
      eyebrow: 'Draft',
      title: customerName.isEmpty ? kind : '$kind for $customerName',
      subtitle: _joinTemplateParts(<String>[
        if (customerContact.isNotEmpty) customerContact,
        if (statusText != null && statusText.isNotEmpty) statusText,
      ]),
      badges: <String>[
        kind,
        if (missingLabels.isEmpty) 'Ready' else 'Needs input',
      ],
      metrics: <_TemplateMetric>[
        _TemplateMetric(
          label: 'Total',
          value: (summary['total_display']?.toString() ?? '').trim().isEmpty
              ? '--'
              : summary['total_display']!.toString().trim(),
        ),
        _TemplateMetric(label: 'Items', value: items.length.toString()),
      ],
      rows: rows,
      footer: missingLabels.isEmpty
          ? 'Draft is ready for preview.'
          : 'Still needed: ${missingLabels.join(', ')}',
    );
  }

  _TemplateCardData? _buildForecastTemplateCard(
    String name,
    Map<String, dynamic> response,
  ) {
    if (name != 'forecast_sales' && response['forecast_scope'] == null) {
      return null;
    }
    final scope = (response['forecast_scope']?.toString() ?? 'shop').trim();
    final scopeLabel = (response['scope_label']?.toString() ?? '').trim();
    final points = _templateMapList(response['forecast_points']);
    final matchedCustomers = _templateStringList(response['matched_customers']);
    final result = (response['result']?.toString() ?? '').trim();
    return _TemplateCardData(
      kind: _TemplateKind.forecast,
      signature: _templateSignature(name, <Object?>[
        scope,
        scopeLabel,
        response['forecast_total_display'],
        response['forecast_orders_total'],
        response['trend_direction'],
        response['confidence'],
        points.length,
        matchedCustomers.join('|'),
        result,
      ]),
      eyebrow: 'Forecast',
      title: switch (scope) {
        'customer' => 'Customer forecast',
        'item' => 'Item forecast',
        _ => 'Sales forecast',
      },
      subtitle: scopeLabel.isEmpty ? null : scopeLabel,
      badges: <String>[
        if ((response['confidence']?.toString() ?? '').trim().isNotEmpty)
          'Confidence ${(response['confidence']?.toString() ?? '').trim()}',
        if ((response['trend_direction']?.toString() ?? '').trim().isNotEmpty)
          'Trend ${(response['trend_direction']?.toString() ?? '').trim()}',
      ],
      metrics: <_TemplateMetric>[
        _TemplateMetric(
          label: 'Forecast total',
          value: _templateMetricValue(response['forecast_total_display']),
        ),
        _TemplateMetric(
          label: 'Avg / day',
          value: _templateMetricValue(
            response['forecast_average_per_day_display'],
          ),
        ),
        _TemplateMetric(
          label: 'Orders',
          value: _templateMetricValue(response['forecast_orders_total']),
        ),
      ],
      rows: <_TemplateRow>[
        for (final customer in matchedCustomers.take(3))
          _TemplateRow(title: customer, subtitle: 'Matched customer'),
        for (final point in points.take(4))
          _TemplateRow(
            title: (point['period']?.toString() ?? '').trim(),
            subtitle:
                (point['projected_orders']?.toString() ?? '').trim().isEmpty
                ? null
                : '${point['projected_orders']} projected orders',
            trailing: (point['projected_total_display']?.toString() ?? '')
                .trim(),
          ),
      ],
      footer: (response['message']?.toString().trim().isNotEmpty ?? false)
          ? response['message']!.toString().trim()
          : (response['forecast_basis']?.toString() ?? '').trim(),
    );
  }

  _TemplateCardData? _buildTrendTemplateCard(
    String name,
    Map<String, dynamic> response,
  ) {
    if (name == 'query_dashboard_summary' ||
        response.containsKey('daily_points') ||
        name == 'get_fast_moving_items' ||
        name == 'get_slow_moving_items') {
      final dailyPoints = _templateMapList(response['daily_points']);
      final items = _templateMapList(response['items']);
      final fastMoving = _templateMapList(response['fast_moving']);
      final slowMoving = _templateMapList(response['slow_moving']);
      final rows = <_TemplateRow>[
        for (final point in dailyPoints.take(5))
          _TemplateRow(
            title: (point['period']?.toString() ?? '').trim(),
            subtitle: (point['units']?.toString() ?? '').trim().isEmpty
                ? null
                : '${point['units']} units',
            trailing: (point['total_display']?.toString() ?? '').trim(),
          ),
        for (final item in (items.isNotEmpty ? items : fastMoving).take(3))
          _TemplateRow(
            title: (item['product_name']?.toString() ?? '').trim(),
            subtitle: (item['sold_30_days']?.toString() ?? '').trim().isNotEmpty
                ? '${item['sold_30_days']} sold in 30 days'
                : null,
            trailing: (item['quantity']?.toString() ?? '').trim(),
          ),
        for (final item in slowMoving.take(2))
          _TemplateRow(
            title: '${(item['product_name']?.toString() ?? '').trim()}',
            subtitle: 'Slow moving',
            trailing: (item['quantity']?.toString() ?? '').trim(),
          ),
      ];
      final title = switch (name) {
        'get_fast_moving_items' => 'Fast moving trend',
        'get_slow_moving_items' => 'Slow moving trend',
        _ => 'Sales trend',
      };
      return _TemplateCardData(
        kind: _TemplateKind.trend,
        signature: _templateSignature(name, <Object?>[
          response['today_total_display'],
          response['yesterday_total_display'],
          rows.length,
          items.length,
          fastMoving.length,
          slowMoving.length,
        ]),
        eyebrow: 'Trend',
        title: title,
        subtitle: (response['shop_timezone']?.toString() ?? '').trim().isEmpty
            ? null
            : 'Timezone ${(response['shop_timezone']?.toString() ?? '').trim()}',
        badges: <String>[
          if ((response['today_period']?.toString() ?? '').trim().isNotEmpty)
            'Today ${(response['today_period']?.toString() ?? '').trim()}',
        ],
        metrics: <_TemplateMetric>[
          if (response.containsKey('today_total_display'))
            _TemplateMetric(
              label: 'Today',
              value: _templateMetricValue(response['today_total_display']),
            ),
          if (response.containsKey('yesterday_total_display'))
            _TemplateMetric(
              label: 'Yesterday',
              value: _templateMetricValue(response['yesterday_total_display']),
            ),
          if (items.isNotEmpty)
            _TemplateMetric(label: 'Items', value: items.length.toString()),
        ],
        rows: rows,
        footer: rows.isEmpty ? 'Trend data is available.' : null,
      );
    }
    return null;
  }

  _TemplateCardData? _buildSaleReportTemplateCard(
    String name,
    Map<String, dynamic> response,
  ) {
    final sale = _templateMap(response['sale']);
    final matches = _templateMapList(response['matches']);
    final reportMetrics =
        response.containsKey('all_total_display') ||
        response.containsKey('invoice_total_display') ||
        response.containsKey('paid_receipts_total_display');
    final saleData = sale ?? (matches.length == 1 ? matches.first : null);
    if (saleData != null) {
      final items = _templateMapList(saleData['items']);
      final status = (saleData['status']?.toString() ?? '').trim();
      final titleLabel = status.toLowerCase() == 'invoice'
          ? 'Invoice'
          : 'Receipt';
      return _TemplateCardData(
        kind: _TemplateKind.saleReport,
        signature: _templateSignature(name, <Object?>[
          saleData['id'],
          saleData['total_display'],
          items.length,
          status,
        ]),
        eyebrow: 'Sale report',
        title: '$titleLabel ${(saleData['id']?.toString() ?? '').trim()}'
            .trim(),
        subtitle: _joinTemplateParts(<String>[
          (saleData['customer_name']?.toString() ?? '').trim(),
          (saleData['customer_contact']?.toString() ?? '').trim(),
          _compactTemplateDate(saleData['created_at']?.toString()),
        ]),
        badges: <String>[if (status.isNotEmpty) status],
        metrics: <_TemplateMetric>[
          _TemplateMetric(
            label: 'Total',
            value: _templateMetricValue(saleData['total_display']),
          ),
          _TemplateMetric(label: 'Items', value: items.length.toString()),
        ],
        rows: <_TemplateRow>[
          for (final item in items.take(4))
            _TemplateRow(
              title: (item['product_name']?.toString() ?? '').trim(),
              subtitle: _joinTemplateParts(<String>[
                if ((item['quantity']?.toString() ?? '').trim().isNotEmpty)
                  'Qty ${item['quantity']}',
                (item['unit_price_display']?.toString() ?? '').trim(),
              ]),
              trailing: (item['line_total_display']?.toString() ?? '').trim(),
            ),
        ],
      );
    }

    if (!reportMetrics) {
      return null;
    }
    final breakdown = _templateMapList(response['item_breakdown']);
    final salesMatches = _templateMapList(response['matches']);
    return _TemplateCardData(
      kind: _TemplateKind.saleReport,
      signature: _templateSignature(name, <Object?>[
        response['all_total_display'],
        response['paid_receipts_total_display'],
        response['invoice_total_display'],
        response['count'],
        breakdown.length,
        salesMatches.length,
      ]),
      eyebrow: 'Report',
      title: 'Sales report',
      subtitle: _joinTemplateParts(<String>[
        if ((response['customer_query']?.toString() ?? '').trim().isNotEmpty)
          'Customer ${(response['customer_query']?.toString() ?? '').trim()}',
        if ((response['item_query']?.toString() ?? '').trim().isNotEmpty)
          'Item ${(response['item_query']?.toString() ?? '').trim()}',
        if ((response['status_filter']?.toString() ?? '').trim().isNotEmpty &&
            (response['status_filter']?.toString() ?? '').trim() != 'all')
          'Filter ${(response['status_filter']?.toString() ?? '').trim()}',
      ]),
      metrics: <_TemplateMetric>[
        _TemplateMetric(
          label: 'Total',
          value: _templateMetricValue(response['all_total_display']),
        ),
        _TemplateMetric(
          label: 'Receipts',
          value: _templateMetricValue(response['paid_receipts_total_display']),
        ),
        _TemplateMetric(
          label: 'Invoices',
          value: _templateMetricValue(response['invoice_total_display']),
        ),
        _TemplateMetric(
          label: 'Sales',
          value: _templateMetricValue(response['count']),
        ),
      ],
      rows: <_TemplateRow>[
        for (final item in breakdown.take(4))
          _TemplateRow(
            title: (item['product_name']?.toString() ?? '').trim(),
            subtitle: (item['quantity']?.toString() ?? '').trim().isEmpty
                ? null
                : '${item['quantity']} sold',
            trailing: (item['revenue_display']?.toString() ?? '').trim(),
          ),
        for (final match in salesMatches.take(breakdown.isEmpty ? 3 : 0))
          _TemplateRow(
            title: (match['customer_name']?.toString() ?? '').trim().isEmpty
                ? (match['id']?.toString() ?? '').trim()
                : (match['customer_name']?.toString() ?? '').trim(),
            subtitle: _compactTemplateDate(match['created_at']?.toString()),
            trailing: (match['total_display']?.toString() ?? '').trim(),
          ),
      ],
      footer: (response['customer_count']?.toString() ?? '').trim().isEmpty
          ? null
          : '${response['customer_count']} customers in this report',
    );
  }

  _TemplateCardData? _buildListTemplateCard(
    String name,
    Map<String, dynamic> response,
  ) {
    final drafts = _templateMapList(response['drafts']);
    final signatures = _templateMapList(response['available_signatures']);
    final bankAccounts = _templateMapList(response['available_bank_accounts']);
    final matches = _templateMapList(response['matches']);
    final items = _templateMapList(response['items']);

    late final String title;
    late final List<_TemplateRow> rows;
    late final String eyebrow;
    final badges = <String>[];

    if (drafts.isNotEmpty) {
      title = 'Saved drafts';
      eyebrow = 'List';
      rows = drafts
          .take(5)
          .map((draft) {
            final label = (draft['label']?.toString() ?? '').trim();
            final customerName = (draft['customer_name']?.toString() ?? '')
                .trim();
            final kind = (draft['kind']?.toString() ?? '').trim();
            return _TemplateRow(
              title: label.isEmpty
                  ? (customerName.isEmpty ? 'Draft' : customerName)
                  : label,
              subtitle: _joinTemplateParts(<String>[
                if (kind.isNotEmpty) kind,
                (draft['customer_contact']?.toString() ?? '').trim(),
              ]),
              trailing: (draft['item_count']?.toString() ?? '').trim().isEmpty
                  ? null
                  : '${draft['item_count']} items',
            );
          })
          .toList(growable: false);
    } else if (signatures.isNotEmpty) {
      title = 'Signature options';
      eyebrow = 'List';
      rows = signatures
          .take(5)
          .map(
            (item) => _TemplateRow(
              title: (item['name']?.toString() ?? '').trim(),
              subtitle: 'Available signature',
            ),
          )
          .toList(growable: false);
    } else if (bankAccounts.isNotEmpty) {
      title = 'Bank options';
      eyebrow = 'List';
      rows = bankAccounts
          .take(5)
          .map(
            (item) => _TemplateRow(
              title: (item['bank_name']?.toString() ?? '').trim(),
              subtitle: _joinTemplateParts(<String>[
                (item['account_name']?.toString() ?? '').trim(),
                (item['account_number']?.toString() ?? '').trim(),
              ]),
            ),
          )
          .toList(growable: false);
    } else if (matches.length > 1) {
      title = switch (name) {
        'search_receipts' => 'Receipts',
        'search_invoices' => 'Invoices',
        _ => 'Matching results',
      };
      eyebrow = 'List';
      rows = matches
          .take(5)
          .map((match) {
            final titleText = (match['customer_name']?.toString() ?? '').trim();
            return _TemplateRow(
              title: titleText.isEmpty
                  ? (match['id']?.toString() ?? '').trim()
                  : titleText,
              subtitle: _joinTemplateParts(<String>[
                _compactTemplateDate(match['created_at']?.toString()),
                (match['status']?.toString() ?? '').trim(),
              ]),
              trailing: (match['total_display']?.toString() ?? '').trim(),
            );
          })
          .toList(growable: false);
    } else if (items.isNotEmpty) {
      title = switch (name) {
        'search_item_sales' => 'Item sales',
        'get_fast_moving_items' => 'Fast moving items',
        'get_slow_moving_items' => 'Slow moving items',
        _ => 'Items',
      };
      eyebrow = name == 'search_item_sales' ? 'List' : 'Trend';
      rows = items
          .take(5)
          .map((item) {
            return _TemplateRow(
              title: (item['product_name']?.toString() ?? '').trim(),
              subtitle: _joinTemplateParts(<String>[
                if ((item['quantity']?.toString() ?? '').trim().isNotEmpty)
                  '${item['quantity']} units',
                (item['account_name']?.toString() ?? '').trim(),
              ]),
              trailing:
                  (item['revenue_display']?.toString() ?? '').trim().isEmpty
                  ? (item['line_total_display']?.toString() ?? '').trim()
                  : (item['revenue_display']?.toString() ?? '').trim(),
            );
          })
          .toList(growable: false);
    } else {
      return null;
    }

    final count = drafts.isNotEmpty
        ? drafts.length
        : signatures.isNotEmpty
        ? signatures.length
        : bankAccounts.isNotEmpty
        ? bankAccounts.length
        : matches.isNotEmpty
        ? matches.length
        : items.length;
    if (count > rows.length) {
      badges.add('$count total');
    }

    return _TemplateCardData(
      kind: eyebrow == 'Trend' ? _TemplateKind.trend : _TemplateKind.list,
      signature: _templateSignature(name, <Object?>[
        title,
        count,
        rows.length,
        rows.map((row) => row.title).join('|'),
      ]),
      eyebrow: eyebrow,
      title: title,
      subtitle: count <= 0 ? null : '$count results',
      badges: badges,
      rows: rows,
    );
  }

  Map<String, dynamic>? _templateMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return null;
  }

  List<Map<String, dynamic>> _templateMapList(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    return value
        .map(_templateMap)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  List<String> _templateStringList(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _templateMetricValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '--' : text;
  }

  String _compactTemplateDate(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) {
      return '';
    }
    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      return text;
    }
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }

  String? _joinTemplateParts(List<String> values) {
    final filtered = values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (filtered.isEmpty) {
      return null;
    }
    return filtered.join(' • ');
  }

  String _templateSignature(String name, List<Object?> parts) {
    final buffer = StringBuffer(name);
    for (final part in parts) {
      buffer.write('|');
      buffer.write(part?.toString() ?? '');
    }
    return buffer.toString();
  }
}
