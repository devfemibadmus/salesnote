part of '../core.dart';

extension _LiveCashierOverlayDraftState on _LiveCashierOverlayState {
  void _clearDraftState({
    required bool isInvoice,
    bool assignNewDraftId = false,
    bool clearDraftId = false,
  }) {
    _lastPersistedDraftSnapshot = null;
    if (clearDraftId) {
      _draftCacheId = null;
    } else if (assignNewDraftId || (_draftCacheId ?? '').trim().isEmpty) {
      _draftCacheId = _nextLiveDraftId();
    }
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

  bool _hasActiveDraft({
    required bool isInvoice,
    bool requireMeaningfulData = true,
  }) {
    final draftId = (_draftCacheId ?? '').trim();
    if (draftId.isEmpty || _draftIsInvoice != isInvoice) {
      return false;
    }
    if (!requireMeaningfulData) {
      return true;
    }
    return _hasMeaningfulDraftState();
  }

  void _resetDraft({required bool isInvoice}) {
    _clearDraftState(isInvoice: isInvoice);
  }

  void _startFreshDraft({required bool isInvoice}) {
    _clearDraftState(isInvoice: isInvoice, assignNewDraftId: true);
  }
}
