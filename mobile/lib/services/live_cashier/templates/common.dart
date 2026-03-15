part of '../../live_cashier.dart';

extension _LiveCashierOverlayTemplateCommon on _LiveCashierOverlayState {
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

  String _templateText(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  String _templateMetricValue(dynamic value, {String fallback = '--'}) {
    final text = _templateText(value);
    return text.isEmpty ? fallback : text;
  }

  String _templateMoney(
    dynamic display,
    dynamic amount, {
    String? currencyCode,
  }) {
    final displayText = _templateText(display);
    if (displayText.isNotEmpty) {
      return displayText;
    }
    final numeric = switch (amount) {
      num value => value.toDouble(),
      _ => double.tryParse(amount?.toString() ?? ''),
    };
    if (numeric == null) {
      return '--';
    }
    return _formatToolMoney(numeric, currencyCode: currencyCode);
  }

  String _compactTemplateDate(String? raw) {
    final text = _templateText(raw);
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
    return filtered.join(' | ');
  }

  String _templateSignature(String name, List<Object?> parts) {
    final buffer = StringBuffer(name);
    for (final part in parts) {
      buffer.write('|');
      buffer.write(part?.toString() ?? '');
    }
    return buffer.toString();
  }

  String _templateListSubtitle(int total) {
    if (total <= 0) {
      return '0 results';
    }
    return '$total ${total == 1 ? 'result' : 'results'}';
  }

  List<_TemplateRow> _templateSaleItemRows(List<Map<String, dynamic>> items) {
    return items
        .map((item) {
          return _TemplateRow(
            title: _templateText(item['product_name']).isEmpty
                ? 'Item'
                : _templateText(item['product_name']),
            subtitle: _joinTemplateParts(<String>[
              if (_templateText(item['quantity']).isNotEmpty)
                'Qty ${_templateText(item['quantity'])}',
              if (_templateText(item['unit_price_display']).isNotEmpty)
                _templateText(item['unit_price_display']),
            ]),
            trailing: _templateText(item['line_total_display']),
          );
        })
        .toList(growable: false);
  }

  Map<String, dynamic>? _templateSingleSale(
    Map<String, dynamic> response, {
    required bool invoice,
  }) {
    final sale = _templateMap(response['sale']);
    if (sale != null) {
      final status = _templateText(sale['status']).toLowerCase();
      if (invoice ? status == 'invoice' : status == 'paid') {
        return sale;
      }
    }
    final matches = _templateMapList(response['matches']);
    if (matches.length == 1) {
      final status = _templateText(matches.first['status']).toLowerCase();
      if (invoice ? status == 'invoice' : status == 'paid') {
        return matches.first;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _templateSaleMatches(
    Map<String, dynamic> response, {
    required bool invoice,
  }) {
    return _templateMapList(response['matches'])
        .where((match) {
          final status = _templateText(match['status']).toLowerCase();
          return invoice ? status == 'invoice' : status == 'paid';
        })
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _templateDraftsByKind(
    Map<String, dynamic> response, {
    required bool invoice,
  }) {
    return _templateMapList(response['drafts'])
        .where((draft) {
          final kind = _templateText(draft['kind']).toLowerCase();
          return invoice ? kind == 'invoice' : kind == 'receipt';
        })
        .toList(growable: false);
  }
}
