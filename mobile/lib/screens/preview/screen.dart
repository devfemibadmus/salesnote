part of 'preview.dart';

class SalePreviewScreen extends StatefulWidget {
  const SalePreviewScreen({
    super.key,
    required this.isCreatedSale,
    required this.status,
    required this.shop,
    required this.signature,
    this.selectedBankAccountId,
    required this.customerName,
    required this.customerContact,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.vatAmount,
    required this.serviceFeeAmount,
    required this.deliveryFeeAmount,
    required this.roundingAmount,
    required this.otherAmount,
    required this.otherLabel,
    required this.total,
    this.receiptNumber,
    this.createdAt,
    this.onCreate,
    this.onMarkAsPaid,
    this.onDelete,
    this.onDownloadPdf,
  });

  final bool isCreatedSale;
  final SaleStatus status;
  final ShopProfile? shop;
  final SignatureItem? signature;
  final String? selectedBankAccountId;
  final String customerName;
  final String customerContact;
  final List<PreviewSaleItem> items;
  final double subtotal;
  final double discountAmount;
  final double vatAmount;
  final double serviceFeeAmount;
  final double deliveryFeeAmount;
  final double roundingAmount;
  final double otherAmount;
  final String otherLabel;
  final double total;
  final String? receiptNumber;
  final DateTime? createdAt;
  final Future<String?> Function()? onCreate;
  final Future<void> Function()? onMarkAsPaid;
  final Future<void> Function()? onDelete;
  final Future<void> Function()? onDownloadPdf;

  @override
  State<SalePreviewScreen> createState() => _SalePreviewScreenState();
}

class _SalePreviewScreenState extends State<SalePreviewScreen> {
  bool _documentBusy = false;
  bool _statusBusy = false;
  bool _deleteBusy = false;
  bool _fitsSinglePage = false;
  String? _selectedBankAccountId;
  late final String _currencySymbol;
  late final String _currencyLocale;
  final ScrollController _receiptScrollController = ScrollController();
  final GlobalKey _receiptBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final ctx = CurrencyService.resolveContext();
    _currencyLocale = ctx.locale;
    _currencySymbol = ctx.symbol;
    _selectedBankAccountId =
        widget.selectedBankAccountId ??
        (widget.shop?.bankAccounts.isNotEmpty == true
            ? widget.shop!.bankAccounts.first.id
            : null);
    _syncSinglePageFlagWithRetry();
  }

  ShopBankAccount? get _selectedBankAccount {
    final bankAccounts = widget.shop?.bankAccounts ?? const <ShopBankAccount>[];
    if (bankAccounts.isEmpty) return null;
    for (final bankAccount in bankAccounts) {
      if (bankAccount.id == _selectedBankAccountId) {
        return bankAccount;
      }
    }
    return bankAccounts.first;
  }

  @override
  void dispose() {
    _receiptScrollController.dispose();
    super.dispose();
  }

  String _formatAmount(num amount) {
    return NumberFormat.currency(
      locale: _currencyLocale,
      symbol: _currencySymbol,
      decimalDigits: 2,
    ).format(amount);
  }

  String _formatSignedAmount(double amount) {
    if (amount < 0) {
      return '-${_formatAmount(amount.abs())}';
    }
    return '+${_formatAmount(amount)}';
  }

  Future<void> _handleCreate() async {
    if (_isAnyBusy || widget.onCreate == null) return;
    setState(() => _statusBusy = true);
    final createdSaleId = await widget.onCreate!.call();
    if (!mounted) return;
    setState(() => _statusBusy = false);
    if (createdSaleId != null && createdSaleId.isNotEmpty) {
      Navigator.of(context).pop(createdSaleId);
    }
  }

  Future<void> _handleMarkAsPaid() async {
    if (_isAnyBusy || widget.onMarkAsPaid == null) return;
    setState(() => _statusBusy = true);
    try {
      await widget.onMarkAsPaid!.call();
    } finally {
      if (mounted) {
        setState(() => _statusBusy = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    if (_isAnyBusy || widget.onDelete == null) return;
    setState(() => _deleteBusy = true);
    try {
      await widget.onDelete!.call();
    } finally {
      if (mounted) {
        setState(() => _deleteBusy = false);
      }
    }
  }

  Future<void> _handleDownloadPdf() async {
    if (_isAnyBusy) return;
    setState(() => _documentBusy = true);
    try {
      final bytes = await _buildReceiptPdfBytes();
      await _savePdfToDevice(bytes);
      if (!mounted) return;
      AppNotice.show(context, 'PDF downloaded successfully.');
    } catch (e) {
      if (!mounted) return;
      AppNotice.show(context, 'Failed to download PDF: $e');
    } finally {
      if (mounted) {
        setState(() => _documentBusy = false);
      }
    }
  }

  Future<void> _handleDownloadImage() async {
    if (_isAnyBusy) return;
    if (!_fitsSinglePage) {
      AppNotice.show(
        context,
        'Image download is only available for single-page documents.',
      );
      return;
    }
    setState(() => _documentBusy = true);
    try {
      final bytes = await _buildReceiptImageBytes();
      await _saveImageToDevice(bytes);
      if (!mounted) return;
      AppNotice.show(context, 'Image saved to gallery.');
    } catch (e) {
      if (!mounted) return;
      AppNotice.show(context, 'Failed to download image: $e');
    } finally {
      if (mounted) {
        setState(() => _documentBusy = false);
      }
    }
  }

  Future<void> _handleShare() async {
    if (_isAnyBusy) return;
    setState(() => _documentBusy = true);
    try {
      final bytes = await _buildReceiptPdfBytes();
      final fileName = _receiptFileName('pdf');
      await Share.shareXFiles([
        XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName),
      ], text: widget.status == SaleStatus.invoice ? 'Salesnote invoice' : 'Salesnote receipt');
    } catch (e) {
      if (!mounted) return;
      AppNotice.show(context, 'Failed to share receipt: $e');
    } finally {
      if (mounted) {
        setState(() => _documentBusy = false);
      }
    }
  }

  bool get _isAnyBusy => _documentBusy || _statusBusy || _deleteBusy;

  Widget _buildReceiptActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1C2D44),
          side: const BorderSide(color: Color(0xFFD8E2EF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildCreatedSaleActions() {
    final showMarkAsPaid =
        widget.status == SaleStatus.invoice && widget.onMarkAsPaid != null;
    final showDelete =
        widget.status == SaleStatus.invoice && widget.onDelete != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildReceiptActionButton(
                icon: Icons.picture_as_pdf_outlined,
                label: 'PDF',
                onPressed: _isAnyBusy ? null : _handleDownloadPdf,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildReceiptActionButton(
                icon: Icons.image_outlined,
                label: 'Image',
                onPressed: (_isAnyBusy || !_fitsSinglePage)
                    ? null
                    : _handleDownloadImage,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildReceiptActionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onPressed: _isAnyBusy ? null : _handleShare,
              ),
            ),
          ],
        ),
        if (!_fitsSinglePage) ...[
          const SizedBox(height: 8),
          const Text(
            'Image download is available only for single-page documents.',
            style: TextStyle(
              color: Color(0xFF8A9AB3),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (showMarkAsPaid) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isAnyBusy ? null : _handleMarkAsPaid,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1677E6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _statusBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                _statusBusy ? 'Updating...' : 'Mark as paid',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        if (showDelete) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _isAnyBusy ? null : _handleDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD14343),
                side: const BorderSide(color: Color(0xFFF2B8B8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _deleteBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFD14343),
                      ),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              label: Text(
                _deleteBusy ? 'Deleting...' : 'Delete invoice',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _updateSinglePageFlag(bool next) {
    if (_fitsSinglePage == next) return;
    setState(() => _fitsSinglePage = next);
  }

  bool _isSinglePageFromMetrics(ScrollMetrics metrics) {
    final renderObject =
        _receiptBoundaryKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderObject == null || !renderObject.hasSize) {
      return metrics.maxScrollExtent <= 0;
    }
    final receiptHeight = renderObject.size.height;
    final deviceHeight = MediaQuery.of(context).size.height;
    return receiptHeight <= deviceHeight;
  }

  void _syncSinglePageFlagWithRetry([int retry = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_receiptScrollController.hasClients) {
        if (retry < 6) {
          _syncSinglePageFlagWithRetry(retry + 1);
        }
        return;
      }
      _updateSinglePageFlag(
        _isSinglePageFromMetrics(_receiptScrollController.position),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = widget.createdAt ?? DateTime.now();
    final dateText = DateFormat('MMM d, yyyy | HH:mm').format(timestamp);
    final receiptNo =
        widget.receiptNumber ??
        '#${widget.status == SaleStatus.invoice ? 'INV' : 'REC'}-${timestamp.millisecondsSinceEpoch % 1000000}';
    final customerName = widget.customerName.trim();
    final customerContact = widget.customerContact.trim();
    final hasCustomerDetails =
        customerName.isNotEmpty || customerContact.isNotEmpty;
    final customerTopValue = customerContact.isNotEmpty
        ? customerContact
        : customerName;
    final customerBottomValue = customerContact.isNotEmpty ? customerName : '';
    final bankAccounts = widget.shop?.bankAccounts ?? const <ShopBankAccount>[];

    return PopScope(
      canPop: !_isAnyBusy,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _isAnyBusy
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF46566E),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.status == SaleStatus.invoice
                            ? 'Invoice'
                            : 'E-Receipt',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0E1930),
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollMetricsNotification>(
                  onNotification: (notification) {
                    _updateSinglePageFlag(
                      _isSinglePageFromMetrics(notification.metrics),
                    );
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _receiptScrollController,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: RepaintBoundary(
                      key: _receiptBoundaryKey,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFDDE6F2)),
                        ),
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: _ReceiptWatermark(text: 'Salesnote'),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                18,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: _PreviewShopAvatar(
                                      shop: widget.shop,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: Text(
                                      widget.shop?.name ?? 'Shop',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF0E1930),
                                        fontSize: 25,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if ((widget.shop?.address ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Center(
                                      child: Text(
                                        widget.shop!.address!.trim(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFF5A6C88),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Center(
                                    child: Text(
                                      widget.shop?.phone ?? '',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF1677E6),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  const Divider(
                                    color: Color(0xFFE5ECF6),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: const [
                                      SizedBox(
                                        width: 42,
                                        child: Text(
                                          'QTY',
                                          style: TextStyle(
                                            color: Color(0xFF8A9AB3),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          'DESCRIPTION',
                                          style: TextStyle(
                                            color: Color(0xFF8A9AB3),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'AMOUNT',
                                        style: TextStyle(
                                          color: Color(0xFF8A9AB3),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(
                                    color: Color(0xFFE5ECF6),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 6),
                                  ...widget.items.map(_buildItemRow),
                                  const SizedBox(height: 8),
                                  const Divider(
                                    color: Color(0xFFE5ECF6),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 12),
                                  _AmountRow(
                                    title: 'Subtotal',
                                    value: _formatAmount(widget.subtotal),
                                    strong: false,
                                  ),
                                  if (widget.discountAmount != 0) ...[
                                    const SizedBox(height: 6),
                                    _AmountRow(
                                      title: 'Discount',
                                      value: _formatSignedAmount(
                                        -widget.discountAmount,
                                      ),
                                      strong: false,
                                    ),
                                  ],
                                  if (widget.vatAmount != 0) ...[
                                    const SizedBox(height: 6),
                                    _AmountRow(
                                      title: 'VAT',
                                      value: _formatSignedAmount(
                                        widget.vatAmount,
                                      ),
                                      strong: false,
                                    ),
                                  ],
                                  if (widget.serviceFeeAmount != 0) ...[
                                    const SizedBox(height: 6),
                                    _AmountRow(
                                      title: 'Service Fee',
                                      value: _formatSignedAmount(
                                        widget.serviceFeeAmount,
                                      ),
                                      strong: false,
                                    ),
                                  ],
                                  if (widget.deliveryFeeAmount != 0) ...[
                                    const SizedBox(height: 6),
                                    _AmountRow(
                                      title: 'Delivery',
                                      value: _formatSignedAmount(
                                        widget.deliveryFeeAmount,
                                      ),
                                      strong: false,
                                    ),
                                  ],
                                  if (widget.roundingAmount != 0) ...[
                                    const SizedBox(height: 6),
                                    _AmountRow(
                                      title: 'Rounding',
                                      value: _formatSignedAmount(
                                        widget.roundingAmount,
                                      ),
                                      strong: false,
                                    ),
                                  ],
                                  if (widget.otherAmount != 0) ...[
                                    const SizedBox(height: 6),
                                    _AmountRow(
                                      title: widget.otherLabel.trim().isEmpty
                                          ? 'Others'
                                          : widget.otherLabel,
                                      value: _formatSignedAmount(
                                        widget.otherAmount,
                                      ),
                                      strong: false,
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  _AmountRow(
                                    title: 'Grand Total',
                                    value: _formatAmount(widget.total),
                                    strong: true,
                                  ),
                                  if (widget.status == SaleStatus.invoice &&
                                      bankAccounts.isNotEmpty) ...[
                                    const SizedBox(height: 22),
                                    _PreviewBankDetails(
                                      bankAccount: _selectedBankAccount,
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  if (widget.status != SaleStatus.invoice &&
                                      hasCustomerDetails)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 6,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                SizedBox(
                                                  height: 68,
                                                  child: Align(
                                                    alignment:
                                                        Alignment.bottomCenter,
                                                    child: Text(
                                                      customerTopValue,
                                                      textAlign:
                                                          TextAlign.center,
                                                      maxLines: 2,
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF5A6C88,
                                                        ),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const Divider(
                                                  color: Color(0xFFD6DEEA),
                                                  height: 1,
                                                ),
                                                const SizedBox(height: 4),
                                                if (customerBottomValue
                                                    .isNotEmpty)
                                                  Text(
                                                    customerBottomValue,
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    style: const TextStyle(
                                                      color: Color(0xFF0E1930),
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 0.8,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            children: [
                                              SizedBox(
                                                height: 68,
                                                child: _PreviewSignature(
                                                  signature: widget.signature,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Divider(
                                                color: Color(0xFFD6DEEA),
                                                height: 1,
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'AUTHORIZED SIGNATURE',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Color(0xFF8A9AB3),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  else if (widget.status != SaleStatus.invoice)
                                    Column(
                                      children: [
                                        SizedBox(
                                          height: 68,
                                          child: _PreviewSignature(
                                            signature: widget.signature,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Divider(
                                          color: Color(0xFFD6DEEA),
                                          height: 1,
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'AUTHORIZED SIGNATURE',
                                          style: TextStyle(
                                            color: Color(0xFF8A9AB3),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 10),
                                  Center(
                                    child: Text(
                                      dateText,
                                      style: const TextStyle(
                                        color: Color(0xFF8A9AB3),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Center(
                                    child: Text(
                                      receiptNo,
                                      style: const TextStyle(
                                        color: Color(0xFF8A9AB3),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                child: widget.isCreatedSale
                    ? _buildCreatedSaleActions()
                    : SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton.icon(
                          onPressed: _isAnyBusy ? null : _handleCreate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1677E6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 6,
                            shadowColor: const Color(0x331677E6),
                          ),
                          icon: _statusBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            _statusBusy
                                ? 'Creating...'
                                : (widget.status == SaleStatus.invoice
                                      ? 'Create Invoice'
                                      : 'Create Sale & Receipt'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(PreviewSaleItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              item.quantity % 1 == 0
                  ? item.quantity.toInt().toString()
                  : item.quantity.toStringAsFixed(2),
              style: const TextStyle(
                color: Color(0xFF5B6E8A),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    color: Color(0xFF0E1930),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Unit: ${_formatAmount(item.unitPrice)}',
                  style: const TextStyle(
                    color: Color(0xFF8A9AB3),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatAmount(item.lineTotal),
                style: const TextStyle(
                  color: Color(0xFF0E1930),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
