part of '../../live_cashier.dart';

extension _LiveCashierOverlayCustomerTemplates on _LiveCashierOverlayState {
  _TemplateCardData? _buildCustomerTemplateCard(
    String name,
    Map<String, dynamic> response,
  ) {
    final customerQuery = _templateText(response['customer_query']);
    final customers = _templateMapList(response['customers']);
    final matchedCustomers = _templateStringList(response['matched_customers']);
    final itemBreakdown = _templateMapList(response['item_breakdown']);
    final drafts = _templateMapList(response['drafts'])
        .where((draft) {
          return _templateText(draft['customer_name']).isNotEmpty ||
              _templateText(draft['customer_contact']).isNotEmpty;
        })
        .toList(growable: false);
    final matches = _templateMapList(response['matches']);

    if (name == 'forecast_sales' &&
        _templateText(response['forecast_scope']).toLowerCase() == 'customer') {
      final subject = customerQuery.isNotEmpty
          ? customerQuery
          : matchedCustomers.isNotEmpty
          ? matchedCustomers.first
          : _templateText(response['scope_label']);
      final points = _templateMapList(response['forecast_points']);
      return _TemplateCardData(
        kind: _TemplateKind.forecast,
        signature: _templateSignature(name, <Object?>[
          'customer',
          subject,
          response['forecast_total_display'],
          response['forecast_orders_total'],
          response['trend_direction'],
          points.length,
        ]),
        eyebrow: 'Customer',
        title: subject.isEmpty ? 'Customer forecast' : 'Forecast for $subject',
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
        rows: <_TemplateRow>[
          for (final customer in matchedCustomers)
            _TemplateRow(title: customer, subtitle: 'Matched customer'),
          for (final point in points)
            _TemplateRow(
              title: _templateText(point['period']),
              subtitle: _templateText(point['projected_orders']).isEmpty
                  ? null
                  : '${_templateText(point['projected_orders'])} projected orders',
              trailing: _templateText(point['projected_total_display']),
            ),
        ],
        footer: _templateText(response['forecast_basis']).isEmpty
            ? null
            : _templateText(response['forecast_basis']),
      );
    }

    if (name == 'query_sales_metrics' && customerQuery.isNotEmpty) {
      final title = customerQuery.isEmpty
          ? 'Customer report'
          : 'Customer report for $customerQuery';
      return _TemplateCardData(
        kind: _TemplateKind.saleReport,
        signature: _templateSignature(name, <Object?>[
          customerQuery,
          response['all_total_display'],
          response['count'],
          matches.length,
        ]),
        eyebrow: 'Customer',
        title: title,
        subtitle: _joinTemplateParts(<String>[
          if (_templateText(response['status_filter']).isNotEmpty &&
              _templateText(response['status_filter']).toLowerCase() != 'all')
            'Filter ${_templateText(response['status_filter'])}',
          if (_templateText(response['start_date']).isNotEmpty &&
              _templateText(response['end_date']).isNotEmpty)
            '${_templateText(response['start_date'])} to ${_templateText(response['end_date'])}',
        ]),
        metrics: <_TemplateMetric>[
          _TemplateMetric(
            label: 'Total',
            value: _templateMetricValue(response['all_total_display']),
          ),
          _TemplateMetric(
            label: 'Sales',
            value: _templateMetricValue(response['count']),
          ),
          _TemplateMetric(
            label: 'Customers',
            value: _templateMetricValue(response['customer_count']),
          ),
        ],
        rows: matches
            .map((match) {
              return _TemplateRow(
                title: _templateText(match['customer_name']).isEmpty
                    ? _templateText(match['id'])
                    : _templateText(match['customer_name']),
                subtitle: _joinTemplateParts(<String>[
                  _compactTemplateDate(match['created_at']?.toString()),
                  _templateText(match['customer_contact']),
                ]),
                trailing: _templateText(match['total_display']),
              );
            })
            .toList(growable: false),
      );
    }

    if ((name == 'list_customers' || name == 'query_sales_metrics') &&
        customers.isNotEmpty) {
      if (customers.length == 1) {
        final customer = customers.first;
        final title = _templateText(customer['customer_name']).isEmpty
            ? 'Customer'
            : _templateText(customer['customer_name']);
        final detailRows = itemBreakdown.isNotEmpty
            ? itemBreakdown
                  .map((item) {
                    return _TemplateRow(
                      title: _templateText(item['product_name']).isEmpty
                          ? 'Item'
                          : _templateText(item['product_name']),
                      subtitle: _templateText(item['quantity']).isEmpty
                          ? null
                          : '${_templateText(item['quantity'])} units',
                      trailing: _templateText(item['revenue_display']),
                    );
                  })
                  .toList(growable: false)
            : matches
                  .map((match) {
                    return _TemplateRow(
                      title:
                          _compactTemplateDate(
                            match['created_at']?.toString(),
                          ).isEmpty
                          ? 'Sale'
                          : _compactTemplateDate(
                              match['created_at']?.toString(),
                            ),
                      subtitle: _joinTemplateParts(<String>[
                        _templateText(match['id']),
                        _templateText(match['status']),
                      ]),
                      trailing: _templateText(match['total_display']),
                    );
                  })
                  .toList(growable: false);
        return _TemplateCardData(
          kind: _TemplateKind.saleReport,
          signature: _templateSignature(name, <Object?>[
            'customer-single',
            title,
            customer['total_display'],
            customer['sales_count'],
            detailRows.length,
          ]),
          eyebrow: 'Customer',
          title: title,
          subtitle: _joinTemplateParts(<String>[
            _templateText(customer['customer_contact']),
            _compactTemplateDate(customer['last_sale_at']?.toString()),
          ]),
          metrics: <_TemplateMetric>[
            _TemplateMetric(
              label: 'Total',
              value: _templateMetricValue(customer['total_display']),
            ),
            _TemplateMetric(
              label: 'Sales',
              value: _templateMetricValue(customer['sales_count']),
            ),
            _TemplateMetric(
              label: 'Receipts',
              value: _templateMetricValue(customer['receipts_count']),
            ),
            _TemplateMetric(
              label: 'Invoices',
              value: _templateMetricValue(customer['invoice_count']),
            ),
          ],
          rows: detailRows,
          footer: itemBreakdown.isNotEmpty
              ? 'Top purchased items'
              : (matches.isNotEmpty ? 'Recent sales' : null),
        );
      }
      return _TemplateCardData(
        kind: _TemplateKind.list,
        signature: _templateSignature(name, <Object?>[
          'customer-list',
          customers.length,
          customers
              .map((customer) => _templateText(customer['customer_name']))
              .join('|'),
        ]),
        eyebrow: 'Customer',
        title: customerQuery.isEmpty
            ? 'Customers'
            : 'Customers for $customerQuery',
        subtitle: _templateListSubtitle(customers.length),
        metrics: <_TemplateMetric>[
          if (_templateText(response['all_total_display']).isNotEmpty)
            _TemplateMetric(
              label: 'Total',
              value: _templateMetricValue(response['all_total_display']),
            ),
          _TemplateMetric(
            label: 'Customers',
            value: _templateMetricValue(response['count']),
          ),
        ],
        rows: customers
            .map((customer) {
              final title = _templateText(customer['customer_name']).isEmpty
                  ? 'Customer'
                  : _templateText(customer['customer_name']);
              return _TemplateRow(
                title: title,
                subtitle: _joinTemplateParts(<String>[
                  _templateText(customer['customer_contact']),
                  if (_templateText(customer['sales_count']).isNotEmpty)
                    '${_templateText(customer['sales_count'])} sales',
                ]),
                trailing: _templateText(customer['total_display']),
              );
            })
            .toList(growable: false),
      );
    }

    if (name == 'list_saved_drafts' && drafts.isNotEmpty) {
      return _TemplateCardData(
        kind: _TemplateKind.list,
        signature: _templateSignature(name, <Object?>[
          drafts.length,
          drafts
              .map((draft) => _templateText(draft['customer_name']))
              .join('|'),
        ]),
        eyebrow: 'Customer',
        title: 'Customers with drafts',
        subtitle: '${drafts.length} saved drafts',
        rows: drafts
            .map((draft) {
              final customerName = _templateText(draft['customer_name']);
              return _TemplateRow(
                title: customerName.isEmpty ? 'Customer draft' : customerName,
                subtitle: _joinTemplateParts(<String>[
                  if (_templateText(draft['kind']).isNotEmpty)
                    _templateText(draft['kind']),
                  _templateText(draft['customer_contact']),
                ]),
                trailing: _templateText(draft['item_count']).isEmpty
                    ? null
                    : '${_templateText(draft['item_count'])} items',
              );
            })
            .toList(growable: false),
      );
    }

    return null;
  }
}
