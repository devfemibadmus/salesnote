part of '../../live_cashier.dart';

extension _LiveCashierOverlaySalesTemplates on _LiveCashierOverlayState {
  _TemplateCardData? _buildSalesTemplateCard(
    String name,
    Map<String, dynamic> response,
  ) {
    final sale = _templateResolvedSingleSale(response);
    if (sale != null) {
      return _buildSingleSalesCard(name, sale);
    }

    final matches = _templateMapList(response['matches']);
    if (matches.isNotEmpty) {
      return _buildSalesListCard(name, response, matches);
    }

    if (name == 'forecast_sales') {
      final points = _templateMapList(response['forecast_points']);
      if (points.isEmpty) {
        return null;
      }
      return _TemplateCardData(
        kind: _TemplateKind.forecast,
        signature: _templateSignature(name, <Object?>[
          'sales-forecast',
          response['forecast_total_display'],
          response['forecast_orders_total'],
          points.length,
        ]),
        eyebrow: 'Sales',
        title: 'Sales forecast',
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
        rows: points
            .map(
              (point) => _TemplateRow(
                title: _templateText(point['period']),
                subtitle: _templateText(point['projected_orders']).isEmpty
                    ? null
                    : '${_templateText(point['projected_orders'])} projected orders',
                trailing: _templateText(point['projected_total_display']),
              ),
            )
            .toList(growable: false),
        footer: _templateText(response['forecast_basis']).isEmpty
            ? null
            : _templateText(response['forecast_basis']),
      );
    }

    return null;
  }

  _TemplateCardData _buildSingleSalesCard(
    String name,
    Map<String, dynamic> sale,
  ) {
    final items = _templateMapList(sale['items']);
    final saleId = _templateText(sale['id']);
    final status = _templateText(sale['status']);
    return _TemplateCardData(
      kind: _TemplateKind.saleReport,
      signature: _templateSignature(name, <Object?>[
        'sale-single',
        saleId,
        sale['total_display'],
        items.length,
      ]),
      eyebrow: 'Sale',
      title: saleId.isEmpty ? 'Sale' : 'Sale $saleId',
      subtitle: _joinTemplateParts(<String>[
        _templateText(sale['customer_name']),
        _templateText(sale['customer_contact']),
        _compactTemplateDate(sale['created_at']?.toString()),
      ]),
      badges: <String>[if (status.isNotEmpty) status],
      metrics: <_TemplateMetric>[
        _TemplateMetric(
          label: 'Total',
          value: _templateMetricValue(sale['total_display']),
        ),
        _TemplateMetric(
          label: 'Items',
          value: _templateMetricValue(items.length),
        ),
      ],
      rows: _templateSaleItemRows(items),
    );
  }

  _TemplateCardData _buildSalesListCard(
    String name,
    Map<String, dynamic> response,
    List<Map<String, dynamic>> matches,
  ) {
    return _TemplateCardData(
      kind: _TemplateKind.list,
      signature: _templateSignature(name, <Object?>[
        'sales-list',
        matches.length,
        matches.map((match) => _templateText(match['id'])).join('|'),
      ]),
      eyebrow: 'Sales',
      title: 'Sales',
      subtitle: _joinTemplateParts(<String>[
        _templateListSubtitle(matches.length),
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
          label: 'Sales',
          value: _templateMetricValue(response['count']),
        ),
        if (_templateText(response['customer_count']).isNotEmpty)
          _TemplateMetric(
            label: 'Customers',
            value: _templateMetricValue(response['customer_count']),
          ),
      ],
      rows: matches
          .map(
            (match) => _TemplateRow(
              title: _templateText(match['customer_name']).isEmpty
                  ? (_templateText(match['id']).isEmpty
                        ? 'Sale'
                        : _templateText(match['id']))
                  : _templateText(match['customer_name']),
              subtitle: _joinTemplateParts(<String>[
                _templateText(match['status']),
                _compactTemplateDate(match['created_at']?.toString()),
                _templateText(match['customer_contact']),
              ]),
              trailing: _templateText(match['total_display']),
            ),
          )
          .toList(growable: false),
    );
  }
}
