part of '../../live_cashier.dart';

extension _LiveCashierOverlayTemplates on _LiveCashierOverlayState {
  static const Set<String> _receiptDraftActions = <String>{
    'start_receipt_draft',
    'submit_receipt',
  };

  static const Set<String> _invoiceDraftActions = <String>{
    'start_invoice_draft',
    'submit_invoice',
  };

  static const Set<String> _sharedDraftActions = <String>{
    'start_new_draft',
    'set_customer',
    'add_item',
    'remove_item',
    'update_item',
    'select_signature',
    'select_bank_account',
    'set_charge',
    'confirm_submit_current_preview',
  };

  bool _canUseReceiptDraftTemplate(String name) {
    return _receiptDraftActions.contains(name) ||
        _sharedDraftActions.contains(name);
  }

  bool _canUseInvoiceDraftTemplate(String name) {
    return _invoiceDraftActions.contains(name) ||
        _sharedDraftActions.contains(name);
  }

  _TemplateCardData? _buildResponseTemplateCard(
    String name,
    Map<String, dynamic> response,
  ) {
    final result = _templateText(response['result']).toLowerCase();
    if (result == 'error') {
      return null;
    }

    if (_receiptDraftActions.contains(name)) {
      return _buildReceiptTemplateCard(name, response);
    }
    if (_invoiceDraftActions.contains(name)) {
      return _buildInvoiceTemplateCard(name, response);
    }
    if (_sharedDraftActions.contains(name)) {
      if (_isInvoiceDraftResponse(response)) {
        return _buildInvoiceTemplateCard(name, response);
      }
      if (_isReceiptDraftResponse(response)) {
        return _buildReceiptTemplateCard(name, response);
      }
      return null;
    }

    switch (name) {
      case 'list_customers':
        return _buildCustomerTemplateCard(name, response);
      case 'list_items':
        return _buildItemTemplateCard(name, response);
      case 'search_receipts':
        return _buildReceiptTemplateCard(name, response);
      case 'search_invoices':
        return _buildInvoiceTemplateCard(name, response);
      case 'open_sale_preview':
        if (_responseSaleStatus(response) == 'invoice') {
          return _buildInvoiceTemplateCard(name, response);
        }
        if (_responseSaleStatus(response).isNotEmpty) {
          return _buildReceiptTemplateCard(name, response);
        }
        return null;
      case 'query_sales_metrics':
        final customerQuery = _templateText(response['customer_query']);
        final itemQuery = _templateText(response['item_query']);
        final status = _templateText(response['status_filter']).toLowerCase();
        if (customerQuery.isNotEmpty) {
          return _buildCustomerTemplateCard(name, response);
        }
        if (itemQuery.isNotEmpty) {
          return _buildItemTemplateCard(name, response);
        }
        if (_isInvoiceStatus(status)) {
          return _buildInvoiceTemplateCard(name, response);
        }
        if (_isReceiptStatus(status)) {
          return _buildReceiptTemplateCard(name, response);
        }
        return null;
      case 'forecast_sales':
        final scope = _templateText(response['forecast_scope']).toLowerCase();
        final status = _templateText(response['status_filter']).toLowerCase();
        if (scope == 'customer') {
          return _buildCustomerTemplateCard(name, response);
        }
        if (scope == 'item') {
          return _buildItemTemplateCard(name, response);
        }
        if (_isInvoiceStatus(status)) {
          return _buildInvoiceTemplateCard(name, response);
        }
        if (_isReceiptStatus(status)) {
          return _buildReceiptTemplateCard(name, response);
        }
        return null;
      case 'search_item_sales':
      case 'get_fast_moving_items':
      case 'get_slow_moving_items':
        return _buildItemTemplateCard(name, response);
      case 'list_saved_drafts':
        final kind = _templateText(response['kind']).toLowerCase();
        if (_isInvoiceStatus(kind)) {
          return _buildInvoiceTemplateCard(name, response);
        }
        if (_isReceiptStatus(kind)) {
          return _buildReceiptTemplateCard(name, response);
        }
        return _buildCustomerTemplateCard(name, response);
      default:
        return null;
    }
  }

  bool _isInvoiceDraftResponse(Map<String, dynamic> response) {
    final summary = _templateMap(response['draft_summary']);
    return _templateText(summary?['kind']).toLowerCase() == 'invoice';
  }

  bool _isReceiptDraftResponse(Map<String, dynamic> response) {
    final summary = _templateMap(response['draft_summary']);
    return _templateText(summary?['kind']).toLowerCase() == 'receipt';
  }

  String _responseSaleStatus(Map<String, dynamic> response) {
    final sale = _templateMap(response['sale']);
    if (sale != null) {
      return _templateText(sale['status']).toLowerCase();
    }
    final matches = _templateMapList(response['matches']);
    if (matches.length == 1) {
      return _templateText(matches.first['status']).toLowerCase();
    }
    return '';
  }

  bool _isInvoiceStatus(String value) {
    return value == 'invoice';
  }

  bool _isReceiptStatus(String value) {
    return value == 'receipt' || value == 'paid';
  }
}
