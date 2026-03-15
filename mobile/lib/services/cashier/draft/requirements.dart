part of '../core.dart';

extension _LiveCashierOverlayDraftRequirements on _LiveCashierOverlayState {
  Map<String, dynamic> _draftSummary() {
    final currencyCode = _toolCurrencyCode();
    final currencySymbol = _toolCurrencySymbol(currencyCode);
    final items = _draftItems
        .map(
          (item) => {
            'product_name': item.productName,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'line_total': (item.unitPrice ?? 0) * item.quantity,
            'unit_price_display': item.unitPrice == null
                ? null
                : _formatToolMoney(item.unitPrice!, currencyCode: currencyCode),
            'line_total_display': _formatToolMoney(
              (item.unitPrice ?? 0) * item.quantity,
              currencyCode: currencyCode,
            ),
          },
        )
        .toList(growable: false);
    final subtotal = _draftItems.fold<double>(
      0,
      (sum, item) => sum + ((item.unitPrice ?? 0) * item.quantity),
    );
    final total =
        subtotal -
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
      'currency_symbol': currencySymbol,
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
      'subtotal_display': _formatToolMoney(
        subtotal,
        currencyCode: currencyCode,
      ),
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

  int? _toolOptionalLimit(dynamic raw, {int max = 2000}) {
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed > max ? max : parsed;
  }

  String? _toolCurrencyCode() {
    final settingsCode = CacheLoader.loadSettingsSummaryCache()
        ?.shop
        .currencyCode
        .trim()
        .toUpperCase();
    if (settingsCode != null && settingsCode.isNotEmpty) {
      return settingsCode;
    }
    final homeCode = CacheLoader.loadHomeSummaryCache()?.shop.currencyCode
        .trim()
        .toUpperCase();
    if (homeCode != null && homeCode.isNotEmpty) {
      return homeCode;
    }
    return null;
  }

  String _formatToolMoney(num amount, {String? currencyCode}) {
    final normalized = amount.toDouble();
    final code = (currencyCode ?? _toolCurrencyCode() ?? '')
        .trim()
        .toUpperCase();
    if (code.isEmpty) {
      return normalized.toStringAsFixed(2);
    }
    return CurrencyService.formatForCode(code, normalized, decimalDigits: 2);
  }

  String _toolCurrencySymbol(String? currencyCode) {
    final code = (currencyCode ?? _toolCurrencyCode() ?? '')
        .trim()
        .toUpperCase();
    if (code.isEmpty) {
      return '';
    }
    return CurrencyService.symbolForCode(code);
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

  String _resolvedRequirementLabel(
    String key, {
    int availableSignatures = 0,
    int availableBankAccounts = 0,
  }) {
    switch (key) {
      case 'signature_id':
        if (availableSignatures <= 0) {
          return 'saved signature in settings';
        }
        return 'signature choice';
      case 'bank_account_id':
        if (availableBankAccounts <= 0) {
          return 'saved bank account in settings';
        }
        return 'bank account choice';
      default:
        return _missingFieldLabel(key);
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

    if (customerName.isEmpty ||
        customerName.length < 3 ||
        customerName.length > 40) {
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
      if (_draftItems.any(
        (item) => item.unitPrice == null || item.unitPrice!.isNaN,
      )) {
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
    var missing = _currentDraftMissingFields(isInvoice: isInvoice);
    var signatures = const <SignatureItem>[];
    var bankAccounts = const <ShopBankAccount>[];
    final autoSelected = <String, dynamic>{};

    if (missing.contains('signature_id')) {
      signatures = await _toolSignatures();
      if (signatures.length == 1) {
        final selected = signatures.first;
        _draftSignatureId = selected.id;
        autoSelected['signature'] = {'id': selected.id, 'name': selected.name};
        missing = _currentDraftMissingFields(isInvoice: isInvoice);
      }
    }

    if (missing.contains('bank_account_id')) {
      final settings = await _toolSettingsSummary();
      bankAccounts = settings?.shop.bankAccounts ?? const <ShopBankAccount>[];
      if (bankAccounts.length == 1) {
        final selected = bankAccounts.first;
        _draftBankAccountId = selected.id;
        autoSelected['bank_account'] = {
          'id': selected.id,
          'bank_name': selected.bankName,
          'account_name': selected.accountName,
          'account_number': selected.accountNumber,
        };
        missing = _currentDraftMissingFields(isInvoice: isInvoice);
      }
    }

    if (missing.isEmpty) {
      return {
        'result': 'ok',
        'message': autoSelected.isEmpty
            ? 'Draft has all required fields.'
            : 'Draft ready with available shop details selected.',
        'missing_fields': const <String>[],
        'missing_labels': const <String>[],
        'auto_selected_resources': autoSelected,
        'draft_summary': _draftSummary(),
      };
    }

    if (missing.contains('signature_id') && signatures.isEmpty) {
      signatures = await _toolSignatures();
    }
    if (missing.contains('bank_account_id') && bankAccounts.isEmpty) {
      final settings = await _toolSettingsSummary();
      bankAccounts = settings?.shop.bankAccounts ?? const <ShopBankAccount>[];
    }

    final labels = missing
        .map(
          (field) => _resolvedRequirementLabel(
            field,
            availableSignatures: signatures.length,
            availableBankAccounts: bankAccounts.length,
          ),
        )
        .toList(growable: false);
    final selectionFields = <String>[
      if (missing.contains('signature_id') && signatures.length > 1)
        'signature_id',
      if (missing.contains('bank_account_id') && bankAccounts.length > 1)
        'bank_account_id',
    ];
    final response = <String, dynamic>{
      'result': 'needs_input',
      'message': 'Need ${labels.join(', ')}.',
      'missing_fields': missing,
      'missing_labels': labels,
      'selection_fields': selectionFields,
      'auto_selected_resources': autoSelected,
      'draft_summary': _draftSummary(),
    };

    if (missing.contains('signature_id')) {
      response['available_signatures'] = signatures
          .map((item) => {'id': item.id, 'name': item.name})
          .toList(growable: false);
    }

    if (missing.contains('bank_account_id')) {
      response['available_bank_accounts'] = bankAccounts
          .map(
            (item) => {
              'id': item.id,
              'bank_name': item.bankName,
              'account_name': item.accountName,
              'account_number': item.accountNumber,
            },
          )
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
}
