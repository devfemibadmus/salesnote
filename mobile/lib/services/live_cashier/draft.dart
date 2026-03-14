part of '../live_cashier.dart';

const String _newSaleDraftIndexKey = 'draft_new_sale_index';
const String _newSaleDraftStoragePrefix = 'draft_new_sale_';
const String _newSaleDefaultDraftId = 'draft_1';
const String _newSaleDefaultDraftLabel = 'New Sale';

extension _LiveCashierOverlayDraft on _LiveCashierOverlayState {
  void _resetDraft({required bool isInvoice}) {
    _draftCacheId = _nextLiveDraftId();
    _draftIsInvoice = isInvoice;
    _draftCustomerName = null;
    _draftCustomerContact = null;
    _draftItems.clear();
    _draftSignatureId = null;
    _draftBankAccountId = null;
    _draftDiscountAmount = 0;
    _draftVatAmount = 0;
    _draftServiceFeeAmount = 0;
    _draftDeliveryFeeAmount = 0;
    _draftRoundingAmount = 0;
    _draftOtherAmount = 0;
    _draftOtherLabel = 'Others';
  }

  void _applyCustomer(
    String? raw, {
    String? explicitName,
    String? explicitContact,
  }) {
    final name = (explicitName ?? '').trim();
    final contact = (explicitContact ?? '').trim();
    if (name.isNotEmpty) {
      _draftCustomerName = name;
    }
    if (contact.isNotEmpty) {
      _draftCustomerContact = contact;
    }
    if (name.isNotEmpty || contact.isNotEmpty) {
      return;
    }
    final value = (raw ?? '').trim();
    if (value.isEmpty) return;
    final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
    final looksLikePhone = digits.isNotEmpty &&
        (digits.startsWith('+') || RegExp(r'^\d{7,}$').hasMatch(digits));
    if (looksLikePhone) {
      _draftCustomerContact = value;
    } else {
      _draftCustomerName = value;
    }
  }

  void _applyAddItem(String? name, String? quantityRaw, String? unitPriceRaw) {
    final productName = (name ?? '').trim();
    if (productName.isEmpty) return;
    final quantity = double.tryParse((quantityRaw ?? '').trim()) ?? 1;
    final unitPrice = double.tryParse((unitPriceRaw ?? '').trim());
    _draftItems.add(
      LiveAgentDraftItem(
        productName: productName,
        quantity: quantity <= 0 ? 1 : quantity,
        unitPrice: unitPrice,
      ),
    );
  }

  void _applyRemoveItem(String? rawIndex) {
    final index = _resolveDraftItemIndex(rawIndex);
    if (index == null || index < 0 || index >= _draftItems.length) return;
    _draftItems.removeAt(index);
  }

  void _applyUpdateItem(
    String? rawIndex,
    String? rawValue, {
    String? quantityRaw,
    String? unitPriceRaw,
    String? field,
  }) {
    final index = _resolveDraftItemIndex(rawIndex);
    if (index == null || index < 0 || index >= _draftItems.length) {
      return;
    }
    final current = _draftItems[index];
    final explicitQuantity = double.tryParse((quantityRaw ?? '').trim());
    final explicitUnitPrice = double.tryParse((unitPriceRaw ?? '').trim());
    final fallbackValue = double.tryParse((rawValue ?? '').trim());
    final normalizedField = (field ?? '').trim().toLowerCase();

    double quantity = current.quantity;
    double? unitPrice = current.unitPrice;

    if (explicitQuantity != null) {
      quantity = explicitQuantity > 0 ? explicitQuantity : quantity;
    }
    if (explicitUnitPrice != null) {
      unitPrice = explicitUnitPrice;
    }

    if (explicitQuantity == null && explicitUnitPrice == null && fallbackValue != null) {
      if (normalizedField == 'quantity') {
        quantity = fallbackValue > 0 ? fallbackValue : quantity;
      } else if (normalizedField == 'unit_price' || normalizedField == 'price') {
        unitPrice = fallbackValue;
      } else if (fallbackValue >= 100) {
        unitPrice = fallbackValue;
      } else {
        quantity = fallbackValue > 0 ? fallbackValue : quantity;
      }
    }

    _draftItems[index] = LiveAgentDraftItem(
      productName: current.productName,
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }

  void _applyCharge(String? chargeTypeRaw, String? amountRaw, {String? label}) {
    final amount = double.tryParse((amountRaw ?? '').trim());
    if (amount == null) return;
    switch ((chargeTypeRaw ?? '').trim().toLowerCase()) {
      case 'discount':
        _draftDiscountAmount = amount;
        break;
      case 'vat':
      case 'tax':
        _draftVatAmount = amount;
        break;
      case 'service_fee':
      case 'service fee':
        _draftServiceFeeAmount = amount;
        break;
      case 'delivery':
      case 'delivery_fee':
      case 'delivery fee':
        _draftDeliveryFeeAmount = amount;
        break;
      case 'rounding':
        _draftRoundingAmount = amount;
        break;
      case 'other':
        _draftOtherAmount = amount;
        final normalizedLabel = (label ?? '').trim();
        if (normalizedLabel.isNotEmpty) {
          _draftOtherLabel = normalizedLabel;
        }
        break;
      default:
        break;
    }
  }

  int? _resolveDraftItemIndex(String? rawIndex) {
    final value = (rawIndex ?? '').trim();
    if (value.isEmpty) return null;
    final parsedIndex = int.tryParse(value);
    if (parsedIndex != null) {
      return parsedIndex;
    }
    final lowered = value.toLowerCase();
    for (var i = 0; i < _draftItems.length; i++) {
      if (_draftItems[i].productName.toLowerCase() == lowered) {
        return i;
      }
    }
    return null;
  }

  String _nextLiveDraftId() {
    return 'draft_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _newSaleDraftStorageKey(String draftId) {
    return '$_newSaleDraftStoragePrefix$draftId';
  }

  String _currentDraftLabel() {
    final customerName = (_draftCustomerName ?? '').trim();
    if (customerName.isNotEmpty) {
      return customerName;
    }
    if (_draftItems.isNotEmpty) {
      final firstItem = _draftItems.first.productName.trim();
      if (firstItem.isNotEmpty) {
        return firstItem;
      }
    }
    return _draftIsInvoice ? 'New Invoice' : _newSaleDefaultDraftLabel;
  }

  bool _hasMeaningfulDraftState() {
    final customerName = (_draftCustomerName ?? '').trim();
    final customerContact = (_draftCustomerContact ?? '').trim();
    return _draftItems.isNotEmpty ||
        customerName.isNotEmpty ||
        customerContact.isNotEmpty ||
        (_draftSignatureId ?? '').trim().isNotEmpty ||
        (_draftBankAccountId ?? '').trim().isNotEmpty ||
        _draftDiscountAmount != 0 ||
        _draftVatAmount != 0 ||
        _draftServiceFeeAmount != 0 ||
        _draftDeliveryFeeAmount != 0 ||
        _draftRoundingAmount != 0 ||
        _draftOtherAmount != 0;
  }

  Map<String, dynamic> _cachedDraftPayload() {
    return {
      'customer_name': (_draftCustomerName ?? '').trim(),
      'customer_contact': (_draftCustomerContact ?? '').trim(),
      'discount_amount': _draftDiscountAmount,
      'vat_amount': _draftVatAmount,
      'service_fee_amount': _draftServiceFeeAmount,
      'delivery_fee_amount': _draftDeliveryFeeAmount,
      'rounding_amount': _draftRoundingAmount,
      'other_amount': _draftOtherAmount,
      'other_label': _draftOtherLabel,
      'signature_id': _draftSignatureId,
      'bank_account_id': _draftBankAccountId,
      'status': _draftIsInvoice ? 'invoice' : 'paid',
      'step': _hasMeaningfulDraftState() ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
      'items': _draftItems
          .map(
            (item) => {
              'product_name': item.productName,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
            },
          )
          .toList(growable: false),
    };
  }

  List<Map<String, dynamic>> _loadDraftIndexEntries() {
    final index = LocalCache.loadDraft(_newSaleDraftIndexKey);
    final entries = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    void addEntry(String rawId, String rawLabel) {
      final id = rawId.trim();
      if (id.isEmpty || !seenIds.add(id)) {
        return;
      }
      final normalizedLabel = rawLabel.trim().isEmpty
          ? _newSaleDefaultDraftLabel
          : rawLabel.trim();
      entries.add({'id': id, 'label': normalizedLabel});
    }

    if (index != null) {
      final draftMaps = (index['drafts'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>();
      for (final raw in draftMaps) {
        addEntry(
          (raw['id'] ?? '').toString(),
          (raw['label'] ?? '').toString(),
        );
      }

      final idsLegacy = (index['ids'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString());
      for (final id in idsLegacy) {
        addEntry(id, _newSaleDefaultDraftLabel);
      }
    }

    for (final key in LocalCache.listDraftKeys(prefix: _newSaleDraftStoragePrefix)) {
      final draftId = key.substring(_newSaleDraftStoragePrefix.length);
      addEntry(draftId, _newSaleDefaultDraftLabel);
    }

    if (entries.isEmpty) {
      entries.add(const {'id': _newSaleDefaultDraftId, 'label': _newSaleDefaultDraftLabel});
    }

    return entries;
  }

  Future<void> _persistCurrentDraftToLocalCache() async {
    final draftId = (_draftCacheId ?? '').trim().isEmpty
        ? _nextLiveDraftId()
        : _draftCacheId!.trim();
    _draftCacheId = draftId;

    final indexEntries = _loadDraftIndexEntries();
    final label = _currentDraftLabel();
    final existingIndex = indexEntries.indexWhere(
      (entry) => entry['id']?.toString() == draftId,
    );
    if (existingIndex >= 0) {
      indexEntries[existingIndex] = {'id': draftId, 'label': label};
    } else {
      indexEntries.add({'id': draftId, 'label': label});
    }

    await LocalCache.saveDraft(_newSaleDraftIndexKey, {
      'active_id': draftId,
      'drafts': indexEntries,
    });
    await LocalCache.saveDraft(
      _newSaleDraftStorageKey(draftId),
      _cachedDraftPayload(),
    );
  }

  bool _storedDraftHasMeaningfulData(Map<String, dynamic>? draft) {
    if (draft == null) {
      return false;
    }
    final items = (draft['items'] as List<dynamic>? ?? const <dynamic>[]);
    if (items.isNotEmpty) {
      return true;
    }
    final customerName = (draft['customer_name'] ?? '').toString().trim();
    final customerContact = (draft['customer_contact'] ?? '').toString().trim();
    final signatureId = (draft['signature_id'] ?? '').toString().trim();
    final bankAccountId = (draft['bank_account_id'] ?? '').toString().trim();
    final discountAmount = (draft['discount_amount'] as num?)?.toDouble() ?? 0;
    final vatAmount =
        ((draft['vat_amount'] ?? draft['tax_amount']) as num?)?.toDouble() ?? 0;
    final serviceFeeAmount =
        (draft['service_fee_amount'] as num?)?.toDouble() ?? 0;
    final deliveryFeeAmount =
        (draft['delivery_fee_amount'] as num?)?.toDouble() ?? 0;
    final roundingAmount = (draft['rounding_amount'] as num?)?.toDouble() ?? 0;
    final otherAmount = (draft['other_amount'] as num?)?.toDouble() ?? 0;
    return customerName.isNotEmpty ||
        customerContact.isNotEmpty ||
        signatureId.isNotEmpty ||
        bankAccountId.isNotEmpty ||
        discountAmount != 0 ||
        vatAmount != 0 ||
        serviceFeeAmount != 0 ||
        deliveryFeeAmount != 0 ||
        roundingAmount != 0 ||
        otherAmount != 0;
  }

  Future<Map<String, dynamic>> _savedDraftsTool(Map<String, dynamic> args) async {
    final requestedKind = (args['kind']?.toString() ?? args['status']?.toString() ?? '')
        .trim()
        .toLowerCase();
    final limit = _toolLimit(args['limit'], fallback: 10, max: 50);
    final index = LocalCache.loadDraft(_newSaleDraftIndexKey);
    final activeId = (index?['active_id'] ?? '').toString().trim();
    final entries = _loadDraftIndexEntries();
    final drafts = <Map<String, dynamic>>[];

    for (final entry in entries) {
      final draftId = (entry['id'] ?? '').toString().trim();
      if (draftId.isEmpty) {
        continue;
      }
      final draft = LocalCache.loadDraft(_newSaleDraftStorageKey(draftId));
      if (!_storedDraftHasMeaningfulData(draft)) {
        continue;
      }
      final rawStatus = (draft?['status'] ?? '').toString().trim().toLowerCase();
      final kind = rawStatus == 'invoice' ? 'invoice' : 'receipt';
      if (requestedKind == 'invoice' && kind != 'invoice') {
        continue;
      }
      if ((requestedKind == 'receipt' || requestedKind == 'paid') && kind != 'receipt') {
        continue;
      }
      final rawItems = (draft?['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .toList(growable: false);
      final itemNames = rawItems
          .map((item) => (item['product_name'] ?? '').toString().trim())
          .where((name) => name.isNotEmpty)
          .toList(growable: false);
      final itemCount = rawItems.fold<double>(
        0,
        (sum, item) => sum + ((item['quantity'] as num?)?.toDouble() ?? 0),
      );
      drafts.add({
        'id': draftId,
        'label': ((entry['label'] ?? '').toString().trim().isEmpty
                ? _newSaleDefaultDraftLabel
                : (entry['label'] ?? '').toString().trim()),
        'kind': kind,
        'customer_name': (draft?['customer_name'] ?? '').toString().trim(),
        'customer_contact': (draft?['customer_contact'] ?? '').toString().trim(),
        'item_names': itemNames,
        'items': rawItems
            .map(
              (item) => {
                'product_name': (item['product_name'] ?? '').toString().trim(),
                'quantity': (item['quantity'] as num?)?.toDouble() ?? 0,
                'unit_price': (item['unit_price'] as num?)?.toDouble(),
              },
            )
            .where((item) => (item['product_name'] as String).isNotEmpty)
            .toList(growable: false),
        'item_count': itemCount,
        'is_active': draftId == activeId,
        'updated_at': (draft?['updated_at'] ?? '').toString(),
      });
    }

    return {
      'count': drafts.length,
      'kind': requestedKind.isEmpty ? 'all' : requestedKind,
      'active_draft_id': activeId.isEmpty ? _draftCacheId : activeId,
      'drafts': drafts.take(limit).toList(growable: false),
    };
  }

  Map<String, dynamic> _draftSummary() {
    final currencyCode = _toolCurrencyCode();
    final items = _draftItems
        .map((item) => {
              'product_name': item.productName,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'line_total': (item.unitPrice ?? 0) * item.quantity,
              'unit_price_display': item.unitPrice == null
                  ? null
                  : _formatToolMoney(
                      item.unitPrice!,
                      currencyCode: currencyCode,
                    ),
              'line_total_display': _formatToolMoney(
                (item.unitPrice ?? 0) * item.quantity,
                currencyCode: currencyCode,
              ),
            })
        .toList(growable: false);
    final subtotal = _draftItems.fold<double>(
      0,
      (sum, item) => sum + ((item.unitPrice ?? 0) * item.quantity),
    );
    final total = subtotal -
        _draftDiscountAmount +
        _draftVatAmount +
        _draftServiceFeeAmount +
        _draftDeliveryFeeAmount +
        _draftRoundingAmount +
        _draftOtherAmount;
    return {
      'draft_id': _draftCacheId,
      'kind': _draftIsInvoice ? 'invoice' : 'receipt',
      'currency_code': currencyCode,
      'customer_name': _draftCustomerName,
      'customer_contact': _draftCustomerContact,
      'items': items,
      'charges': {
        'discount_amount': _draftDiscountAmount,
        'vat_amount': _draftVatAmount,
        'service_fee_amount': _draftServiceFeeAmount,
        'delivery_fee_amount': _draftDeliveryFeeAmount,
        'rounding_amount': _draftRoundingAmount,
        'other_amount': _draftOtherAmount,
        'other_label': _draftOtherLabel,
      },
      'subtotal': subtotal,
      'subtotal_display': _formatToolMoney(subtotal, currencyCode: currencyCode),
      'total': total,
      'total_display': _formatToolMoney(total, currencyCode: currencyCode),
      'signature_id': _draftSignatureId,
      'bank_account_id': _draftBankAccountId,
    };
  }

  DateTime? _toolDate(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  int _toolLimit(dynamic raw, {int fallback = 5, int max = 20}) {
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed == null || parsed <= 0) return fallback;
    return parsed > max ? max : parsed;
  }

  String? _toolCurrencyCode() {
    final settingsCode =
        CacheLoader.loadSettingsSummaryCache()?.shop.currencyCode.trim().toUpperCase();
    if (settingsCode != null && settingsCode.isNotEmpty) {
      return settingsCode;
    }
    final homeCode =
        CacheLoader.loadHomeSummaryCache()?.shop.currencyCode.trim().toUpperCase();
    if (homeCode != null && homeCode.isNotEmpty) {
      return homeCode;
    }
    return null;
  }

  String _formatToolMoney(num amount, {String? currencyCode}) {
    final code = (currencyCode ?? _toolCurrencyCode() ?? '').trim().toUpperCase();
    final normalized = amount.toDouble();
    if (code.isEmpty) {
      return normalized.toStringAsFixed(2);
    }
    return '$code ${normalized.toStringAsFixed(2)}';
  }

  Future<SettingsSummary?> _toolSettingsSummary() async {
    final cached = CacheLoader.loadSettingsSummaryCache();
    if (cached != null) {
      return cached;
    }
    try {
      final fresh = await _api.getSettingsSummary();
      unawaited(CacheLoader.saveSettingsSummaryCache(fresh));
      return fresh;
    } catch (_) {
      return null;
    }
  }

  Future<List<SignatureItem>> _toolSignatures() async {
    final cached = CacheLoader.loadSignaturesCache();
    if (cached.isNotEmpty) {
      return cached;
    }
    try {
      final fresh = await _api.listSignatures();
      unawaited(CacheLoader.saveSignaturesCache(fresh));
      return fresh;
    } catch (_) {
      return const <SignatureItem>[];
    }
  }

  String _missingFieldLabel(String key) {
    switch (key) {
      case 'customer_name':
        return 'customer name';
      case 'customer_contact':
        return 'customer phone or email';
      case 'items':
        return 'at least one item';
      case 'item_quantity':
        return 'valid item quantities';
      case 'item_unit_price':
        return 'item prices';
      case 'signature_id':
        return 'signature';
      case 'bank_account_id':
        return 'bank account';
      default:
        return key.replaceAll('_', ' ');
    }
  }

  bool _looksLikeCustomerContact(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return false;
    }
    if (normalized.contains('@')) {
      return Validators.isValidEmail(normalized);
    }
    final digits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 7;
  }

  List<String> _currentDraftMissingFields({required bool isInvoice}) {
    final missing = <String>[];
    final customerName = (_draftCustomerName ?? '').trim();
    final customerContact = (_draftCustomerContact ?? '').trim();

    if (customerName.isEmpty || customerName.length < 3 || customerName.length > 40) {
      missing.add('customer_name');
    }
    if (!_looksLikeCustomerContact(customerContact)) {
      missing.add('customer_contact');
    }
    if (_draftItems.isEmpty) {
      missing.add('items');
    } else {
      if (_draftItems.any((item) => item.quantity <= 0)) {
        missing.add('item_quantity');
      }
      if (_draftItems.any((item) => item.unitPrice == null || item.unitPrice!.isNaN)) {
        missing.add('item_unit_price');
      }
    }
    if ((_draftSignatureId ?? '').trim().isEmpty) {
      missing.add('signature_id');
    }
    if (isInvoice && (_draftBankAccountId ?? '').trim().isEmpty) {
      missing.add('bank_account_id');
    }
    return missing;
  }

  Future<Map<String, dynamic>> _draftRequirementsResponse({
    required bool isInvoice,
  }) async {
    final missing = _currentDraftMissingFields(isInvoice: isInvoice);
    if (missing.isEmpty) {
      return {
        'result': 'ok',
        'message': 'Draft has all required fields.',
        'missing_fields': const <String>[],
        'missing_labels': const <String>[],
        'draft_summary': _draftSummary(),
      };
    }

    final labels = missing.map(_missingFieldLabel).toList(growable: false);
    final response = <String, dynamic>{
      'result': 'needs_input',
      'message': 'Need ${labels.join(', ')}.',
      'missing_fields': missing,
      'missing_labels': labels,
      'draft_summary': _draftSummary(),
    };

    if (missing.contains('signature_id')) {
      final signatures = await _toolSignatures();
      response['available_signatures'] = signatures
          .map((item) => {
                'id': item.id,
                'name': item.name,
              })
          .toList(growable: false);
    }

    if (missing.contains('bank_account_id')) {
      final settings = await _toolSettingsSummary();
      response['available_bank_accounts'] =
          (settings?.shop.bankAccounts ?? const <ShopBankAccount>[])
              .map((item) => {
                    'id': item.id,
                    'bank_name': item.bankName,
                    'account_name': item.accountName,
                    'account_number': item.accountNumber,
                  })
              .toList(growable: false);
    }

    return response;
  }

  Future<Map<String, dynamic>?> _validateDraftForSubmit({
    required bool isInvoice,
  }) async {
    final response = await _draftRequirementsResponse(isInvoice: isInvoice);
    if (response['result'] == 'ok') {
      return null;
    }
    return response;
  }

  Map<String, dynamic> _saleSummary(Sale sale) {
    final currencyCode = _toolCurrencyCode();
    return {
      'id': sale.id,
      'status': sale.status.name,
      'customer_name': sale.customerName,
      'customer_contact': sale.customerContact,
      'total': sale.total,
      'currency_code': currencyCode,
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
    return {
      'currency_code': currencyCode,
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

  NewSaleRouteArgs _newSaleArgs() {
    return NewSaleRouteArgs(
      startAsInvoice: _draftIsInvoice,
      draftId: _draftCacheId,
      agentDraft: LiveAgentDraftArgs(
        customerName: _draftCustomerName,
        customerContact: _draftCustomerContact,
        items: List<LiveAgentDraftItem>.unmodifiable(_draftItems),
        signatureId: _draftSignatureId,
        bankAccountId: _draftBankAccountId,
        discountAmount: _draftDiscountAmount,
        vatAmount: _draftVatAmount,
        serviceFeeAmount: _draftServiceFeeAmount,
        deliveryFeeAmount: _draftDeliveryFeeAmount,
        roundingAmount: _draftRoundingAmount,
        otherAmount: _draftOtherAmount,
        otherLabel: _draftOtherLabel,
      ),
    );
  }

  String? _routeForPage(String? pageId) {
    switch (pageId) {
      case 'home':
        return AppRoutes.home;
      case 'sales':
        return AppRoutes.sales;
      case 'invoices':
        return AppRoutes.invoices;
      case 'items':
        return AppRoutes.items;
      case 'settings':
        return AppRoutes.shop;
      case 'new_sale':
        return AppRoutes.newSale;
      default:
        return null;
    }
  }
}


