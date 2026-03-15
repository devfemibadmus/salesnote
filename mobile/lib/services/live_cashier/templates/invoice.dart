part of '../../live_cashier.dart';

extension _LiveCashierOverlayInvoiceTemplates on _LiveCashierOverlayState {
  _TemplateCardData? _buildInvoiceTemplateCard(
    String name,
    Map<String, dynamic> response,
  ) {
    final draftSummary = _templateMap(response['draft_summary']);
    if (_canUseInvoiceDraftTemplate(name) &&
        _templateText(draftSummary?['kind']).toLowerCase() == 'invoice') {
      return _buildInvoiceDraftTemplate(name, response, draftSummary!);
    }

    final sale = _templateSingleSale(response, invoice: true);
    if (sale != null) {
      return _buildSingleInvoiceTemplate(name, sale);
    }

    final drafts = _templateDraftsByKind(response, invoice: true);
    if (name == 'list_saved_drafts' && drafts.isNotEmpty) {
      return _buildInvoiceListTemplate(name, drafts, title: 'Invoice drafts');
    }

    final matches = _templateSaleMatches(response, invoice: true);
    if ((name == 'search_invoices' || name == 'query_sales_metrics') &&
        matches.isNotEmpty) {
      return _buildInvoiceListTemplate(name, matches, title: 'Invoices');
    }

    if (name == 'forecast_sales' &&
        _templateText(response['status_filter']).toLowerCase() == 'invoice') {
      final points = _templateMapList(response['forecast_points']);
      if (points.isEmpty) {
        return null;
      }
      return _TemplateCardData(
        kind: _TemplateKind.forecast,
        signature: _templateSignature(name, <Object?>[
          'invoice',
          response['forecast_total_display'],
          response['forecast_orders_total'],
          points.length,
        ]),
        eyebrow: 'Invoice',
        title: 'Invoice forecast',
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

    if (name == 'query_sales_metrics' &&
        _templateText(response['status_filter']).toLowerCase() == 'invoice') {
      return _TemplateCardData(
        kind: _TemplateKind.saleReport,
        signature: _templateSignature(name, <Object?>[
          'invoice-report',
          response['invoice_total_display'],
          response['count'],
          matches.length,
        ]),
        eyebrow: 'Invoice',
        title: 'Invoice report',
        subtitle: _joinTemplateParts(<String>[
          if (_templateText(response['start_date']).isNotEmpty &&
              _templateText(response['end_date']).isNotEmpty)
            '${_templateText(response['start_date'])} to ${_templateText(response['end_date'])}',
        ]),
        metrics: <_TemplateMetric>[
          _TemplateMetric(
            label: 'Total',
            value: _templateMetricValue(response['invoice_total_display']),
          ),
          _TemplateMetric(
            label: 'Invoices',
            value: _templateMetricValue(response['invoice_count']),
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
                subtitle: _compactTemplateDate(match['created_at']?.toString()),
                trailing: _templateText(match['total_display']),
              );
            })
            .toList(growable: false),
      );
    }

    return null;
  }

  _TemplateCardData _buildInvoiceDraftTemplate(
    String name,
    Map<String, dynamic> response,
    Map<String, dynamic> summary,
  ) {
    final items = _templateMapList(summary['items']);
    final missingLabels = _templateStringList(response['missing_labels']);
    final customerName = _templateText(summary['customer_name']);
    final customerContact = _templateText(summary['customer_contact']);
    return _TemplateCardData(
      kind: _TemplateKind.draft,
      signature: _templateSignature(name, <Object?>[
        'invoice-draft',
        summary['draft_id'],
        summary['total_display'],
        items.length,
        missingLabels.join('|'),
      ]),
      eyebrow: 'Invoice',
      title: customerName.isEmpty
          ? 'Invoice draft'
          : 'Invoice draft for $customerName',
      subtitle: _joinTemplateParts(<String>[
        if (customerContact.isNotEmpty) customerContact,
        _templateText(response['message']),
      ]),
      badges: <String>[
        'Draft',
        if (missingLabels.isEmpty) 'Ready' else 'Needs input',
      ],
      metrics: <_TemplateMetric>[
        _TemplateMetric(
          label: 'Total',
          value: _templateMetricValue(summary['total_display']),
        ),
        _TemplateMetric(label: 'Items', value: items.length.toString()),
      ],
      rows: _templateSaleItemRows(items),
      footer: missingLabels.isEmpty
          ? 'Invoice draft is ready for preview.'
          : 'Still needed: ${missingLabels.join(', ')}',
    );
  }

  _TemplateCardData _buildSingleInvoiceTemplate(
    String name,
    Map<String, dynamic> sale,
  ) {
    final items = _templateMapList(sale['items']);
    final title = _templateText(sale['id']).isEmpty
        ? 'Invoice'
        : 'Invoice ${_templateText(sale['id'])}';
    return _TemplateCardData(
      kind: _TemplateKind.saleReport,
      signature: _templateSignature(name, <Object?>[
        'invoice',
        sale['id'],
        sale['total_display'],
        items.length,
      ]),
      eyebrow: 'Invoice',
      title: title,
      subtitle: _joinTemplateParts(<String>[
        _templateText(sale['customer_name']),
        _templateText(sale['customer_contact']),
        _compactTemplateDate(sale['created_at']?.toString()),
      ]),
      badges: <String>[
        if (_templateText(sale['status']).isNotEmpty)
          _templateText(sale['status']),
      ],
      metrics: <_TemplateMetric>[
        _TemplateMetric(
          label: 'Total',
          value: _templateMetricValue(sale['total_display']),
        ),
        _TemplateMetric(label: 'Items', value: items.length.toString()),
      ],
      rows: _templateSaleItemRows(items),
    );
  }

  _TemplateCardData _buildInvoiceListTemplate(
    String name,
    List<Map<String, dynamic>> entries, {
    required String title,
  }) {
    return _TemplateCardData(
      kind: _TemplateKind.list,
      signature: _templateSignature(name, <Object?>[
        'invoice-list',
        title,
        entries.length,
        entries.map((entry) => _templateText(entry['id'])).join('|'),
      ]),
      eyebrow: 'Invoice',
      title: title,
      subtitle: _templateListSubtitle(entries.length),
      rows: entries
          .map((entry) {
            final customerName = _templateText(entry['customer_name']);
            final label = customerName.isEmpty
                ? (_templateText(entry['label']).isEmpty
                      ? 'Invoice'
                      : _templateText(entry['label']))
                : customerName;
            return _TemplateRow(
              title: label,
              subtitle: _joinTemplateParts(<String>[
                if (_templateText(entry['customer_contact']).isNotEmpty)
                  _templateText(entry['customer_contact']),
                if (_templateText(entry['updated_at']).isNotEmpty)
                  _compactTemplateDate(entry['updated_at']?.toString()),
              ]),
              trailing: _templateText(entry['total_display']).isNotEmpty
                  ? _templateText(entry['total_display'])
                  : (_templateText(entry['item_count']).isNotEmpty
                        ? '${_templateText(entry['item_count'])} items'
                        : null),
            );
          })
          .toList(growable: false),
    );
  }
}
