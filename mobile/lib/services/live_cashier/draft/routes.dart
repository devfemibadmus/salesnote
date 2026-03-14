part of '../../live_cashier.dart';

extension _LiveCashierOverlayDraftRoutes on _LiveCashierOverlayState {
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
