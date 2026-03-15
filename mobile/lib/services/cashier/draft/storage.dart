part of '../core.dart';

extension _LiveCashierOverlayDraftStorage on _LiveCashierOverlayState {
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
        addEntry((raw['id'] ?? '').toString(), (raw['label'] ?? '').toString());
      }

      final idsLegacy = (index['ids'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString());
      for (final id in idsLegacy) {
        addEntry(id, _newSaleDefaultDraftLabel);
      }
    }

    for (final key in LocalCache.listDraftKeys(
      prefix: _newSaleDraftStoragePrefix,
    )) {
      final draftId = key.substring(_newSaleDraftStoragePrefix.length);
      addEntry(draftId, _newSaleDefaultDraftLabel);
    }

    if (entries.isEmpty) {
      entries.add(const {
        'id': _newSaleDefaultDraftId,
        'label': _newSaleDefaultDraftLabel,
      });
    }

    return entries;
  }

  Future<void> _persistCurrentDraftToLocalCache() async {
    var draftId = (_draftCacheId ?? '').trim().isEmpty
        ? _nextLiveDraftId()
        : _draftCacheId!.trim();
    _draftCacheId = draftId;
    _draftLog('persist:start ${_draftDebugSummary(draftId: draftId)}');

    if (!_hasMeaningfulDraftState()) {
      _draftLog('persist:removeEmpty ${_draftDebugSummary(draftId: draftId)}');
      await _removeDraftFromLocalCache(draftId);
      return;
    }

    await _deduplicateCurrentDraftByCustomer();
    draftId = (_draftCacheId ?? '').trim().isEmpty
        ? draftId
        : _draftCacheId!.trim();

    final label = _currentDraftLabel();
    final payload = _cachedDraftPayload();
    final snapshot = jsonEncode({
      'draft_id': draftId,
      'label': label,
      'payload': payload,
    });
    if (_lastPersistedDraftSnapshot == snapshot) {
      _draftLog(
        'persist:skipUnchanged ${_draftDebugSummary(draftId: draftId)}',
      );
      return;
    }

    final indexEntries = _loadDraftIndexEntries();
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
    await LocalCache.saveDraft(_newSaleDraftStorageKey(draftId), payload);
    _lastPersistedDraftSnapshot = snapshot;
    _draftLog(
      'persist:done label="$label" ${_draftDebugSummary(draftId: draftId)}',
    );
  }

  Future<void> _deduplicateCurrentDraftByCustomer() async {
    final currentDraftId = (_draftCacheId ?? '').trim();
    if (currentDraftId.isEmpty) {
      return;
    }
    final customerName = (_draftCustomerName ?? '').trim();
    final customerContact = (_draftCustomerContact ?? '').trim();
    final match = _findMatchingSavedDraft(
      isInvoice: _draftIsInvoice,
      customerName: customerName,
      customerContact: customerContact,
      excludingDraftId: currentDraftId,
    );
    if (match == null) {
      _draftLog('dedupe:miss ${_draftDebugSummary(draftId: currentDraftId)}');
      return;
    }
    final mergedDraft = _mergeDraftPayloads(match.draft, _cachedDraftPayload());
    _draftLog(
      'dedupe:merge from=$currentDraftId to=${match.draftId} '
      'current=${_draftDebugSummary(draftId: currentDraftId)}',
    );
    _loadDraftIntoState(match.draftId, mergedDraft);
    await _removeDraftFromLocalCache(currentDraftId);
  }

  Future<void> _removeDraftFromLocalCache(String draftId) async {
    final normalized = draftId.trim();
    if (normalized.isEmpty) {
      return;
    }
    _draftLog('removeLocal draftId=$normalized');
    final indexEntries = _loadDraftIndexEntries()
        .where((entry) => entry['id']?.toString() != normalized)
        .toList(growable: false);
    await LocalCache.clearDraft(_newSaleDraftStorageKey(normalized));
    _lastPersistedDraftSnapshot = null;
    final nextEntries = indexEntries.isEmpty
        ? const <Map<String, dynamic>>[
            {'id': _newSaleDefaultDraftId, 'label': _newSaleDefaultDraftLabel},
          ]
        : indexEntries;
    final nextActiveId =
        nextEntries.first['id']?.toString() ?? _newSaleDefaultDraftId;
    await LocalCache.saveDraft(_newSaleDraftIndexKey, {
      'active_id': nextActiveId,
      'drafts': nextEntries,
    });
  }

  Future<Map<String, dynamic>> _discardCurrentDraft() async {
    final currentDraftId = (_draftCacheId ?? '').trim();
    final currentKind = _draftIsInvoice;
    if (currentDraftId.isEmpty) {
      _draftLog('discard:noop noActiveDraft');
      _clearDraftState(isInvoice: currentKind, clearDraftId: true);
      return {
        'result': 'ok',
        'message': 'No active draft to discard.',
        'draft_summary': _draftSummary(),
      };
    }
    _draftLog(
      'discard:current draftId=$currentDraftId ${_draftDebugSummary()}',
    );
    await _removeDraftFromLocalCache(currentDraftId);
    _clearDraftState(isInvoice: currentKind, clearDraftId: true);
    return {
      'result': 'ok',
      'message': 'Current draft discarded.',
      'discarded_draft_id': currentDraftId,
      'draft_summary': _draftSummary(),
    };
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
        discountAmount != 0 ||
        vatAmount != 0 ||
        serviceFeeAmount != 0 ||
        deliveryFeeAmount != 0 ||
        roundingAmount != 0 ||
        otherAmount != 0;
  }

  Future<Map<String, dynamic>> _savedDraftsTool(
    Map<String, dynamic> args,
  ) async {
    final requestedKind =
        (args['kind']?.toString() ?? args['status']?.toString() ?? '')
            .trim()
            .toLowerCase();
    final limit = _toolOptionalLimit(args['limit']);
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
      final rawStatus = (draft?['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final kind = rawStatus == 'invoice' ? 'invoice' : 'receipt';
      if (requestedKind == 'invoice' && kind != 'invoice') {
        continue;
      }
      if ((requestedKind == 'receipt' || requestedKind == 'paid') &&
          kind != 'receipt') {
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
        'customer_contact': (draft?['customer_contact'] ?? '')
            .toString()
            .trim(),
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
      'drafts': (limit == null ? drafts : drafts.take(limit)).toList(
        growable: false,
      ),
    };
  }
}
