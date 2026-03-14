class AppRoutes {
  static const auth = '/auth';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const sales = '/sales';
  static const items = '/items';
  static const invoices = '/invoices';
  static const newSale = '/sales/new';
  static const shop = '/shop';
  static const notification = '/notification';

  static const Map<String, int> tabIndices = {
    home: 0,
    sales: 1,
    invoices: 2,
    shop: 3,
  };
}

class SalesRouteArgs {
  const SalesRouteArgs({this.openSaleId, this.refreshFirst = false});

  final String? openSaleId;
  final bool refreshFirst;
}

class InvoicesRouteArgs {
  const InvoicesRouteArgs({this.openSaleId, this.refreshFirst = false});

  final String? openSaleId;
  final bool refreshFirst;
}

class LiveAgentDraftItem {
  const LiveAgentDraftItem({
    required this.productName,
    required this.quantity,
    this.unitPrice,
  });

  final String productName;
  final double quantity;
  final double? unitPrice;
}

class LiveAgentDraftArgs {
  const LiveAgentDraftArgs({
    this.customerName,
    this.customerContact,
    this.items = const <LiveAgentDraftItem>[],
    this.signatureId,
    this.bankAccountId,
    this.discountAmount = 0,
    this.vatAmount = 0,
    this.serviceFeeAmount = 0,
    this.deliveryFeeAmount = 0,
    this.roundingAmount = 0,
    this.otherAmount = 0,
    this.otherLabel,
  });

  final String? customerName;
  final String? customerContact;
  final List<LiveAgentDraftItem> items;
  final String? signatureId;
  final String? bankAccountId;
  final double discountAmount;
  final double vatAmount;
  final double serviceFeeAmount;
  final double deliveryFeeAmount;
  final double roundingAmount;
  final double otherAmount;
  final String? otherLabel;
}

class NewSaleRouteArgs {
  const NewSaleRouteArgs({
    this.startAsInvoice = false,
    this.agentDraft,
    this.draftId,
    this.openPreviewOnLoad = false,
    this.autoCreateOnPreviewLoad = false,
  });

  final bool startAsInvoice;
  final LiveAgentDraftArgs? agentDraft;
  final String? draftId;
  final bool openPreviewOnLoad;
  final bool autoCreateOnPreviewLoad;
}
