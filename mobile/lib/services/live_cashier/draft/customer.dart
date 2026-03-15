part of '../../live_cashier.dart';

extension _LiveCashierOverlayDraftCustomer on _LiveCashierOverlayState {
  void _applyCustomer(
    String? raw, {
    String? explicitName,
    String? explicitContact,
  }) {
    final (name: resolvedName, contact: resolvedContact) = _resolvedCustomerParts(
      raw,
      explicitName: explicitName,
      explicitContact: explicitContact,
    );
    final name = resolvedName;
    final contact = resolvedContact;
    _reuseMatchingSavedDraft(
      isInvoice: _draftIsInvoice,
      customerName: name.isEmpty ? null : name,
      customerContact: contact.isEmpty ? null : contact,
    );
    if (name.isNotEmpty) {
      _draftCustomerName = name;
    }
    if (contact.isNotEmpty) {
      _draftCustomerContact = contact;
    }
  }

  ({String name, String contact}) _resolvedCustomerParts(
    String? raw, {
    String? explicitName,
    String? explicitContact,
  }) {
    var name = (explicitName ?? '').trim();
    var contact = (explicitContact ?? '').trim();
    if (name.isNotEmpty || contact.isNotEmpty) {
      return (name: name, contact: contact);
    }
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return (name: name, contact: contact);
    }
    final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
    final looksLikePhone = digits.isNotEmpty &&
        (digits.startsWith('+') || RegExp(r'^\d{7,}$').hasMatch(digits));
    if (looksLikePhone) {
      contact = value;
    } else {
      name = value;
    }
    return (name: name, contact: contact);
  }

  String _normalizedCustomerName(String? value) {
    return (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizedCustomerContact(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized.contains('@')) {
      return normalized;
    }
    return normalized.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  bool _customerMatchesDraft(
    Map<String, dynamic>? draft, {
    String? customerName,
    String? customerContact,
  }) {
    if (draft == null) {
      return false;
    }
    final requestedName = _normalizedCustomerName(customerName);
    final requestedContact = _normalizedCustomerContact(customerContact);
    final draftName = _normalizedCustomerName(draft['customer_name']?.toString());
    final draftContact =
        _normalizedCustomerContact(draft['customer_contact']?.toString());

    final nameMatches = requestedName.isNotEmpty &&
        draftName.isNotEmpty &&
        requestedName == draftName;
    final contactMatches = requestedContact.isNotEmpty &&
        draftContact.isNotEmpty &&
        requestedContact == draftContact;
    return nameMatches || contactMatches;
  }

  DateTime? _draftUpdatedAt(Map<String, dynamic>? draft) {
    final raw = (draft?['updated_at'] ?? '').toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  void _loadDraftIntoState(String draftId, Map<String, dynamic> draft) {
    _draftCacheId = draftId.trim();
    _draftIsInvoice =
        (draft['status'] ?? '').toString().trim().toLowerCase() == 'invoice';
    _draftCustomerName = (draft['customer_name'] ?? '').toString().trim().isEmpty
        ? null
        : (draft['customer_name'] ?? '').toString().trim();
    _draftCustomerContact =
        (draft['customer_contact'] ?? '').toString().trim().isEmpty
            ? null
            : (draft['customer_contact'] ?? '').toString().trim();
    _draftItems
      ..clear()
      ..addAll(
        (draft['items'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (item) => LiveAgentDraftItem(
                productName: (item['product_name'] ?? '').toString().trim(),
                quantity: (item['quantity'] as num?)?.toDouble() ?? 0,
                unitPrice: (item['unit_price'] as num?)?.toDouble(),
              ),
            )
            .where((item) => item.productName.isNotEmpty)
            .toList(growable: false),
      );
    _draftSignatureId = (draft['signature_id'] ?? '').toString().trim().isEmpty
        ? null
        : (draft['signature_id'] ?? '').toString().trim();
    _draftBankAccountId =
        (draft['bank_account_id'] ?? '').toString().trim().isEmpty
            ? null
            : (draft['bank_account_id'] ?? '').toString().trim();
    _draftDiscountAmount = (draft['discount_amount'] as num?)?.toDouble() ?? 0;
    _draftVatAmount =
        ((draft['vat_amount'] ?? draft['tax_amount']) as num?)?.toDouble() ?? 0;
    _draftServiceFeeAmount =
        (draft['service_fee_amount'] as num?)?.toDouble() ?? 0;
    _draftDeliveryFeeAmount =
        (draft['delivery_fee_amount'] as num?)?.toDouble() ?? 0;
    _draftRoundingAmount = (draft['rounding_amount'] as num?)?.toDouble() ?? 0;
    _draftOtherAmount = (draft['other_amount'] as num?)?.toDouble() ?? 0;
    final otherLabel = (draft['other_label'] ?? '').toString().trim();
    _draftOtherLabel = otherLabel.isEmpty ? 'Others' : otherLabel;
    _lastPersistedDraftSnapshot = null;
  }

  bool _reuseMatchingSavedDraft({
    required bool isInvoice,
    String? customerName,
    String? customerContact,
  }) {
    final normalizedName = _normalizedCustomerName(customerName);
    final normalizedContact = _normalizedCustomerContact(customerContact);
    if (normalizedName.isEmpty && normalizedContact.isEmpty) {
      return false;
    }

    final currentDraftId = (_draftCacheId ?? '').trim();
    final currentDraft = _cachedDraftPayload();
    if (_hasActiveDraft(isInvoice: isInvoice, requireMeaningfulData: false) &&
        _customerMatchesDraft(
          currentDraft,
          customerName: customerName,
          customerContact: customerContact,
        )) {
      return false;
    }

    final match = _findMatchingSavedDraft(
      isInvoice: isInvoice,
      customerName: customerName,
      customerContact: customerContact,
      excludingDraftId: currentDraftId,
    );
    if (match == null) {
      return false;
    }

    final mergedDraft = _mergeDraftPayloads(match.draft, currentDraft);
    _loadDraftIntoState(match.draftId, mergedDraft);
    return true;
  }

  ({String draftId, Map<String, dynamic> draft})? _findMatchingSavedDraft({
    required bool isInvoice,
    String? customerName,
    String? customerContact,
    String? excludingDraftId,
  }) {
    final normalizedName = _normalizedCustomerName(customerName);
    final normalizedContact = _normalizedCustomerContact(customerContact);
    if (normalizedName.isEmpty && normalizedContact.isEmpty) {
      return null;
    }

    String? bestDraftId;
    Map<String, dynamic>? bestDraft;
    DateTime? bestUpdatedAt;

    for (final entry in _loadDraftIndexEntries()) {
      final draftId = (entry['id'] ?? '').toString().trim();
      if (draftId.isEmpty || draftId == (excludingDraftId ?? '').trim()) {
        continue;
      }
      final draft = LocalCache.loadDraft(_newSaleDraftStorageKey(draftId));
      if (!_storedDraftHasMeaningfulData(draft)) {
        continue;
      }
      final kind = (draft?['status'] ?? '').toString().trim().toLowerCase();
      final draftIsInvoice = kind == 'invoice';
      if (draftIsInvoice != isInvoice) {
        continue;
      }
      if (!_customerMatchesDraft(
        draft,
        customerName: customerName,
        customerContact: customerContact,
      )) {
        continue;
      }
      final updatedAt = _draftUpdatedAt(draft);
      if (bestDraft == null ||
          (updatedAt != null &&
              (bestUpdatedAt == null || updatedAt.isAfter(bestUpdatedAt)))) {
        bestDraftId = draftId;
        bestDraft = draft;
        bestUpdatedAt = updatedAt;
      }
    }

    if (bestDraftId == null || bestDraft == null) {
      return null;
    }
    return (draftId: bestDraftId, draft: bestDraft);
  }

  Map<String, dynamic> _mergeDraftPayloads(
    Map<String, dynamic> baseDraft,
    Map<String, dynamic> incomingDraft,
  ) {
    final merged = <String, dynamic>{...baseDraft};

    String mergedTextField(String key) {
      final incoming = (incomingDraft[key] ?? '').toString().trim();
      if (incoming.isNotEmpty) {
        return incoming;
      }
      return (baseDraft[key] ?? '').toString().trim();
    }

    double mergedAmountField(String key) {
      final incoming = (incomingDraft[key] as num?)?.toDouble() ?? 0;
      if (incoming != 0) {
        return incoming;
      }
      return (baseDraft[key] as num?)?.toDouble() ?? 0;
    }

    final mergedItems = <Map<String, dynamic>>[];
    final mergedItemIndex = <String, int>{};

    void addOrReplaceItem(Map<dynamic, dynamic> rawItem) {
      final item = <String, dynamic>{
        'product_name': (rawItem['product_name'] ?? '').toString().trim(),
        'quantity': (rawItem['quantity'] as num?)?.toDouble() ?? 0,
        'unit_price': (rawItem['unit_price'] as num?)?.toDouble(),
      };
      final key = _normalizedCustomerName(item['product_name']?.toString());
      if (key.isEmpty) {
        return;
      }
      final existingIndex = mergedItemIndex[key];
      if (existingIndex == null) {
        mergedItemIndex[key] = mergedItems.length;
        mergedItems.add(item);
        return;
      }
      mergedItems[existingIndex] = item;
    }

    for (final rawItem
        in (baseDraft['items'] as List<dynamic>? ?? const <dynamic>[])) {
      if (rawItem is Map<dynamic, dynamic>) {
        addOrReplaceItem(rawItem);
      }
    }
    for (final rawItem
        in (incomingDraft['items'] as List<dynamic>? ?? const <dynamic>[])) {
      if (rawItem is Map<dynamic, dynamic>) {
        addOrReplaceItem(rawItem);
      }
    }

    merged['customer_name'] = mergedTextField('customer_name');
    merged['customer_contact'] = mergedTextField('customer_contact');
    merged['discount_amount'] = mergedAmountField('discount_amount');
    merged['vat_amount'] = mergedAmountField('vat_amount');
    merged['service_fee_amount'] = mergedAmountField('service_fee_amount');
    merged['delivery_fee_amount'] = mergedAmountField('delivery_fee_amount');
    merged['rounding_amount'] = mergedAmountField('rounding_amount');
    merged['other_amount'] = mergedAmountField('other_amount');
    merged['other_label'] = mergedTextField('other_label');
    merged['signature_id'] = mergedTextField('signature_id');
    merged['bank_account_id'] = mergedTextField('bank_account_id');
    merged['status'] = (incomingDraft['status'] ?? baseDraft['status'] ?? 'paid')
        .toString()
        .trim();
    merged['items'] = mergedItems;
    merged['updated_at'] = DateTime.now().toIso8601String();
    return merged;
  }
}
