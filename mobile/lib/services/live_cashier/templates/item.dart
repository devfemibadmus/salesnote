part of '../../live_cashier.dart';

extension _LiveCashierOverlayItemTemplates on _LiveCashierOverlayState {
  _TemplateCardData? _buildItemTemplateCard(
    String name,
    Map<String, dynamic> response,
  ) {
    final itemQuery = _templateText(response['item_query']);
    final items = _templateMapList(response['items']);
    final matches = _templateMapList(response['matches']);
    final breakdown = _templateMapList(response['item_breakdown']);

    if (name == 'forecast_sales' &&
        _templateText(response['forecast_scope']).toLowerCase() == 'item') {
      final subject = itemQuery.isNotEmpty
          ? itemQuery
          : _templateText(response['scope_label']);
      final points = _templateMapList(response['forecast_points']);
      return _TemplateCardData(
        kind: _TemplateKind.forecast,
        signature: _templateSignature(name, <Object?>[
          'item',
          subject,
          response['forecast_total_display'],
          response['forecast_orders_total'],
          points.length,
        ]),
        eyebrow: 'Item',
        title: subject.isEmpty ? 'Item forecast' : 'Forecast for $subject',
        subtitle: _templateText(response['scope_label']).isEmpty
            ? null
            : _templateText(response['scope_label']),
        badges: <String>[
          if (_templateText(response['confidence']).isNotEmpty)
            'Confidence ${_templateText(response['confidence'])}',
          if (_templateText(response['trend_direction']).isNotEmpty)
            'Trend ${_templateText(response['trend_direction'])}',
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
        rows: _templateMapList(response['forecast_points'])
            .take(4)
            .map((point) {
              return _TemplateRow(
                title: _templateText(point['period']),
                subtitle: _templateText(point['projected_orders']).isEmpty
                    ? null
                    : '${_templateText(point['projected_orders'])} projected orders',
                trailing: _templateText(point['projected_total_display']),
              );
            })
            .toList(growable: false),
      );
    }

    if (name == 'get_fast_moving_items' || name == 'get_slow_moving_items') {
      final title = name == 'get_fast_moving_items'
          ? 'Fast moving items'
          : 'Slow moving items';
      return _TemplateCardData(
        kind: _TemplateKind.trend,
        signature: _templateSignature(name, <Object?>[
          items.length,
          items.map((item) => _templateText(item['product_name'])).join('|'),
        ]),
        eyebrow: 'Item',
        title: title,
        rows: items
            .take(5)
            .map((item) {
              return _TemplateRow(
                title: _templateText(item['product_name']),
                subtitle: _templateText(item['sold_30_days']).isEmpty
                    ? null
                    : '${_templateText(item['sold_30_days'])} sold in 30 days',
                trailing: _templateText(item['quantity']),
              );
            })
            .toList(growable: false),
      );
    }

    if (name == 'search_item_sales' ||
        (name == 'query_sales_metrics' && itemQuery.isNotEmpty)) {
      final rows = (breakdown.isNotEmpty ? breakdown : matches)
          .take(5)
          .map((item) {
            final revenueDisplay = _templateMoney(
              item['revenue_display'],
              item['revenue'],
              currencyCode: _templateText(response['currency_code']),
            );
            return _TemplateRow(
              title: _templateText(item['product_name']).isEmpty
                  ? 'Item'
                  : _templateText(item['product_name']),
              subtitle: _templateText(item['quantity']).isEmpty
                  ? null
                  : '${_templateText(item['quantity'])} units',
              trailing: revenueDisplay == '--' ? null : revenueDisplay,
            );
          })
          .toList(growable: false);

      return _TemplateCardData(
        kind: _TemplateKind.saleReport,
        signature: _templateSignature(name, <Object?>[
          itemQuery,
          response['all_total_display'],
          response['count'],
          rows.length,
        ]),
        eyebrow: 'Item',
        title: itemQuery.isEmpty ? 'Item report' : 'Item report for $itemQuery',
        subtitle: _joinTemplateParts(<String>[
          if (_templateText(response['status_filter']).isNotEmpty &&
              _templateText(response['status_filter']).toLowerCase() != 'all')
            'Filter ${_templateText(response['status_filter'])}',
          if (_templateText(response['start_date']).isNotEmpty &&
              _templateText(response['end_date']).isNotEmpty)
            '${_templateText(response['start_date'])} to ${_templateText(response['end_date'])}',
        ]),
        metrics: <_TemplateMetric>[
          if (_templateText(response['all_total_display']).isNotEmpty)
            _TemplateMetric(
              label: 'Total',
              value: _templateMetricValue(response['all_total_display']),
            ),
          _TemplateMetric(
            label: 'Matches',
            value: _templateMetricValue(response['count']),
          ),
        ],
        rows: rows,
      );
    }

    return null;
  }
}
