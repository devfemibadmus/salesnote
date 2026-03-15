part of '../core.dart';

const String _newSaleDraftIndexKey = DraftConstants.newSaleDraftIndexKey;
const String _newSaleDraftStoragePrefix =
    DraftConstants.newSaleDraftStoragePrefix;
const String _newSaleDefaultDraftId = DraftConstants.newSaleDefaultDraftId;
const String _newSaleDefaultDraftLabel =
    DraftConstants.newSaleDefaultDraftLabel;

extension _LiveCashierOverlayDraftDebug on _LiveCashierOverlayState {
  String _draftDebugSummary({
    String? draftId,
    String? customerName,
    String? customerContact,
    int? itemCount,
    bool? isInvoice,
  }) {
    final normalizedDraftId = (draftId ?? _draftCacheId ?? '').trim();
    final normalizedCustomerName = (customerName ?? _draftCustomerName ?? '')
        .trim();
    final normalizedCustomerContact =
        (customerContact ?? _draftCustomerContact ?? '').trim();
    final normalizedItemCount = itemCount ?? _draftItems.length;
    final normalizedIsInvoice = isInvoice ?? _draftIsInvoice;
    return 'draftId=${normalizedDraftId.isEmpty ? "-" : normalizedDraftId} '
        'kind=${normalizedIsInvoice ? "invoice" : "receipt"} '
        'customer=${normalizedCustomerName.isEmpty ? "-" : normalizedCustomerName} '
        'contact=${normalizedCustomerContact.isEmpty ? "-" : normalizedCustomerContact} '
        'items=$normalizedItemCount';
  }

  void _draftLog(String message) {
    _log('draft:$message');
  }
}
