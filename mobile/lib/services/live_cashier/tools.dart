part of '../live_cashier.dart';

extension _LiveCashierOverlayTools on _LiveCashierOverlayState {
  String _toolActionLabel(String name) {
    switch (name) {
      case 'navigate':
        return 'Opening page';
      case 'start_receipt_draft':
        return 'Starting receipt draft';
      case 'start_invoice_draft':
        return 'Starting invoice draft';
      case 'start_new_draft':
        return 'Starting new draft';
      case 'discard_current_draft':
        return 'Discarding current draft';
      case 'set_customer':
        return 'Updating customer';
      case 'add_item':
        return 'Adding item';
      case 'remove_item':
        return 'Removing item';
      case 'update_item':
        return 'Updating item';
      case 'select_signature':
        return 'Selecting signature';
      case 'select_bank_account':
        return 'Selecting bank account';
      case 'set_charge':
        return 'Updating charges';
      case 'submit_receipt':
        return 'Preparing receipt preview';
      case 'submit_invoice':
        return 'Preparing invoice preview';
      case 'confirm_submit_current_preview':
        return 'Creating current preview';
      case 'mark_invoice_paid':
        return 'Marking invoice as paid';
      case 'search_receipts':
        return 'Searching receipts';
      case 'search_invoices':
        return 'Searching invoices';
      case 'list_saved_drafts':
        return 'Checking saved drafts';
      case 'open_sale_preview':
        return 'Opening preview';
      case 'query_dashboard_summary':
        return 'Checking dashboard data';
      case 'query_sales_metrics':
        return 'Checking sales metrics';
      case 'forecast_sales':
        return 'Forecasting sales';
      case 'search_item_sales':
        return 'Checking item sales';
      case 'get_fast_moving_items':
        return 'Checking fast moving items';
      case 'get_slow_moving_items':
        return 'Checking slow moving items';
      default:
        return 'Processing action';
    }
  }

  String _toolResultLabel(String name, Map<String, dynamic> response) {
    final result = response['result']?.toString() ?? '';
    if (result == 'needs_input') {
      final labels = (response['missing_labels'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false);
      if (labels.isNotEmpty) {
        return 'Waiting for ${labels.join(', ')}';
      }
    }
    final message = response['message']?.toString().trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    if (result == 'ok') {
      return '${_toolActionLabel(name)} done';
    }
    return 'Unable to complete action';
  }

  Future<void> _handleToolCalls(List functionCalls) async {
    final responses = <Map<String, dynamic>>[];
    try {
      for (final call in functionCalls) {
        if (call is! Map<String, dynamic>) continue;
        final id = call['id']?.toString() ?? '';
        final name = call['name']?.toString() ?? '';
        final args =
            (call['args'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        _log('tool:call name=$name args=$args');
        if (mounted) {
          _safeSetState(() {
            _toolBusy = true;
            _toolStatus = _toolActionLabel(name);
          });
        }
        final response = await _handleFunctionCall(name, args);
        final templateCard = _buildResponseTemplateCard(name, response);
        if (mounted) {
          _safeSetState(() {
            _toolStatus = _toolResultLabel(name, response);
            _appendTemplateCard(templateCard);
          });
        }
        responses.add({'id': id, 'name': name, 'response': response});
      }
      if (responses.isNotEmpty) {
        _socket?.add(
          jsonEncode({
            'toolResponse': {'functionResponses': responses},
          }),
        );
        if (_closeAfterToolResponse) {
          _closeAfterToolResponse = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(_closeOverlay());
          });
        }
      }
    } finally {
      if (mounted) {
        _safeSetState(() {
          _toolBusy = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _handleFunctionCall(
    String name,
    Map<String, dynamic> args,
  ) async {
    String? route;
    Object? routeArgs;
    final extra = <String, dynamic>{};
    final draftFlowAction = const <String>{
      'start_receipt_draft',
      'start_invoice_draft',
      'start_new_draft',
      'set_customer',
      'add_item',
      'remove_item',
      'update_item',
      'select_signature',
      'select_bank_account',
      'set_charge',
      'submit_receipt',
      'submit_invoice',
      'confirm_submit_current_preview',
    }.contains(name);

    try {
      switch (name) {
        case 'navigate':
          route = _routeForPage(args['page_id']?.toString());
          if (route == AppRoutes.newSale) {
            routeArgs = _newSaleArgs();
          }
          break;
        case 'start_receipt_draft':
          if (!_hasActiveDraft(isInvoice: false)) {
            _resetDraft(isInvoice: false);
          }
          route = AppRoutes.newSale;
          routeArgs = _newSaleArgs();
          break;
        case 'start_invoice_draft':
          if (!_hasActiveDraft(isInvoice: true)) {
            _resetDraft(isInvoice: true);
          }
          route = AppRoutes.newSale;
          routeArgs = _newSaleArgs();
          break;
        case 'start_new_draft':
          final normalizedKind = (args['kind']?.toString() ?? '')
              .trim()
              .toLowerCase();
          if (normalizedKind != 'receipt' && normalizedKind != 'invoice') {
            return {
              'result': 'error',
              'message': 'Draft kind must be receipt or invoice.',
            };
          }
          final isInvoice = normalizedKind == 'invoice';
          _startFreshDraft(isInvoice: isInvoice);
          route = AppRoutes.newSale;
          routeArgs = _newSaleArgs();
          break;
        case 'discard_current_draft':
          _pendingRoute = null;
          _pendingArgs = null;
          return await _discardCurrentDraft();
        case 'set_customer':
          _applyCustomer(
            args['customer_name_or_phone']?.toString(),
            explicitName: args['customer_name']?.toString(),
            explicitContact: args['customer_contact']?.toString(),
          );
          route = AppRoutes.newSale;
          routeArgs = _newSaleArgs();
          break;
        case 'add_item':
          _applyAddItem(
            args['item_id_or_name']?.toString(),
            args['quantity']?.toString(),
            args['unit_price']?.toString(),
          );
          route = AppRoutes.newSale;
          routeArgs = _newSaleArgs();
          break;
        case 'remove_item':
          _applyRemoveItem(args['draft_item_id']?.toString());
          route = AppRoutes.newSale;
          routeArgs = _newSaleArgs();
          break;
        case 'update_item':
          _applyUpdateItem(
            args['draft_item_id']?.toString(),
            args['quantity_or_price']?.toString(),
            quantityRaw: args['quantity']?.toString(),
            unitPriceRaw: args['unit_price']?.toString(),
            field: args['field']?.toString(),
          );
          route = AppRoutes.newSale;
          routeArgs = _newSaleArgs();
          break;
        case 'select_signature':
          _draftSignatureId = args['signature_id']?.toString();
          route = AppRoutes.newSale;
          routeArgs = _newSaleArgs();
          break;
        case 'select_bank_account':
          _draftBankAccountId = args['bank_account_id']?.toString();
          route = AppRoutes.newSale;
          routeArgs = _newSaleArgs();
          break;
        case 'set_charge':
          _applyCharge(
            args['charge_type']?.toString(),
            args['amount']?.toString(),
            label: args['label']?.toString(),
          );
          route = AppRoutes.newSale;
          routeArgs = _newSaleArgs();
          break;
        case 'mark_invoice_paid':
          route = AppRoutes.invoices;
          routeArgs = InvoicesRouteArgs(
            openSaleId: args['sale_id']?.toString(),
            refreshFirst: true,
          );
          break;
        case 'submit_receipt':
          _draftIsInvoice = false;
          final missingReceiptData = await _validateDraftForSubmit(
            isInvoice: false,
          );
          if (missingReceiptData != null) {
            return missingReceiptData;
          }
          route = AppRoutes.newSale;
          routeArgs = NewSaleRouteArgs(
            startAsInvoice: false,
            agentDraft: _newSaleArgs().agentDraft,
            openPreviewOnLoad: true,
          );
          break;
        case 'submit_invoice':
          _draftIsInvoice = true;
          final missingInvoiceData = await _validateDraftForSubmit(
            isInvoice: true,
          );
          if (missingInvoiceData != null) {
            return missingInvoiceData;
          }
          route = AppRoutes.newSale;
          routeArgs = NewSaleRouteArgs(
            startAsInvoice: true,
            agentDraft: _newSaleArgs().agentDraft,
            openPreviewOnLoad: true,
          );
          break;
        case 'confirm_submit_current_preview':
          final missingPreviewData = await _validateDraftForSubmit(
            isInvoice: _draftIsInvoice,
          );
          if (missingPreviewData != null) {
            return missingPreviewData;
          }
          route = AppRoutes.newSale;
          routeArgs = NewSaleRouteArgs(
            startAsInvoice: _draftIsInvoice,
            agentDraft: _newSaleArgs().agentDraft,
            openPreviewOnLoad: true,
            autoCreateOnPreviewLoad: true,
          );
          _closeAfterToolResponse = true;
          break;
        case 'search_receipts':
          extra.addAll(await _searchSalesTool(args, SaleStatus.paid));
          final routeSaleId = extra['open_sale_id']?.toString();
          if (routeSaleId != null && routeSaleId.isNotEmpty) {
            route = AppRoutes.sales;
            routeArgs = SalesRouteArgs(
              openSaleId: routeSaleId,
              refreshFirst: true,
            );
          }
          break;
        case 'search_invoices':
          extra.addAll(await _searchSalesTool(args, SaleStatus.invoice));
          final routeSaleId = extra['open_sale_id']?.toString();
          if (routeSaleId != null && routeSaleId.isNotEmpty) {
            route = AppRoutes.invoices;
            routeArgs = InvoicesRouteArgs(
              openSaleId: routeSaleId,
              refreshFirst: true,
            );
          }
          break;
        case 'list_saved_drafts':
          extra.addAll(await _savedDraftsTool(args));
          break;
        case 'open_sale_preview':
          final saleId = (args['sale_id']?.toString() ?? '').trim();
          if (saleId.isNotEmpty) {
            final sale = await _api.getSale(saleId);
            route = sale.isInvoice ? AppRoutes.invoices : AppRoutes.sales;
            routeArgs = sale.isInvoice
                ? InvoicesRouteArgs(openSaleId: saleId, refreshFirst: true)
                : SalesRouteArgs(openSaleId: saleId, refreshFirst: true);
            extra['sale'] = _saleSummary(sale);
          }
          break;
        case 'query_dashboard_summary':
          extra.addAll(await _dashboardSummaryTool());
          break;
        case 'query_sales_metrics':
          extra.addAll(await _salesMetricsTool(args));
          break;
        case 'forecast_sales':
          extra.addAll(await _forecastSalesTool(args));
          break;
        case 'search_item_sales':
          extra.addAll(await _itemSalesTool(args));
          break;
        case 'get_fast_moving_items':
          extra['items'] = await _movementItemsTool(
            fast: true,
            limit: args['limit'],
          );
          break;
        case 'get_slow_moving_items':
          extra['items'] = await _movementItemsTool(
            fast: false,
            limit: args['limit'],
          );
          break;
        default:
          break;
      }
    } catch (e) {
      _log('tool:error name=$name error=$e');
      return {
        'result': 'error',
        'message': e is ApiException
            ? e.message
            : 'Unable to complete that action right now.',
      };
    }

    if (draftFlowAction) {
      _draftLog('tool:$name:beforePersist ${_draftDebugSummary()}');
      await _persistCurrentDraftToLocalCache();
      final requirements = await _draftRequirementsResponse(
        isInvoice: _draftIsInvoice,
      );
      if (routeArgs is NewSaleRouteArgs) {
        routeArgs = NewSaleRouteArgs(
          startAsInvoice: routeArgs.startAsInvoice,
          draftId: _draftCacheId,
          agentDraft: _newSaleArgs().agentDraft,
          openPreviewOnLoad: routeArgs.openPreviewOnLoad,
          autoCreateOnPreviewLoad: routeArgs.autoCreateOnPreviewLoad,
        );
      }
      _draftLog(
        'tool:$name:afterPersist ${_draftDebugSummary()} '
        'requirements=${requirements["result"]}',
      );
      if (route != null) {
        _pendingRoute = route;
        _pendingArgs = routeArgs;
        if (routeArgs is NewSaleRouteArgs) {
          _draftLog(
            'tool:$name:pendingRoute route=$route '
            'routeDraftId=${routeArgs.draftId ?? "-"} '
            'routeItems=${routeArgs.agentDraft?.items.length ?? 0}',
          );
        }
      }
      if (requirements['result'] == 'needs_input') {
        return {
          ...requirements,
          'pending_route': route,
          ...extra,
          if (routeArgs is NewSaleRouteArgs)
            'start_as_invoice': routeArgs.startAsInvoice,
          if (routeArgs is NewSaleRouteArgs && routeArgs.agentDraft != null)
            'draft_items_count': routeArgs.agentDraft!.items.length,
        };
      }
    } else if (route != null) {
      _pendingRoute = route;
      _pendingArgs = routeArgs;
    }

    return {
      'result': 'ok',
      'pending_route': route,
      'draft_summary': _draftSummary(),
      ...extra,
      if (routeArgs is NewSaleRouteArgs)
        'start_as_invoice': routeArgs.startAsInvoice,
      if (routeArgs is NewSaleRouteArgs && routeArgs.agentDraft != null)
        'draft_items_count': routeArgs.agentDraft!.items.length,
      if (routeArgs is InvoicesRouteArgs) 'sale_id': routeArgs.openSaleId,
    };
  }
}
