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

    String? bestDraftId;
    Map<String, dynamic>? bestDraft;
    DateTime? bestUpdatedAt;

    for (final entry in _loadDraftIndexEntries()) {
      final draftId = (entry['id'] ?? '').toString().trim();
      if (draftId.isEmpty || draftId == currentDraftId) {
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
      return false;
    }

    _loadDraftIntoState(bestDraftId, bestDraft);
    return true;
  }
}
