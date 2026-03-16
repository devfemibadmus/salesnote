part of 'preview.dart';

enum _PreviewMenuAction {
  downloadPdf,
  downloadImage,
  share,
  print,
  markAsPaid,
  deleteInvoice,
}

class SalePreviewScreen extends StatefulWidget {
  const SalePreviewScreen({
    super.key,
    required this.isCreatedSale,
    this.autoCreateOnLoad = false,
    this.autoPrintOnLoad = false,
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
  final bool autoCreateOnLoad;
  final bool autoPrintOnLoad;
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
  String? _createdSaleId;
  DateTime? _createdSaleAt;
  late final String _currencySymbol;
  late final String _currencyLocale;
  final ScrollController _receiptScrollController = ScrollController();
  final GlobalKey _receiptBoundaryKey = GlobalKey();
  bool _didAutoCreate = false;
  bool _didAutoPrint = false;

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
    if (widget.autoCreateOnLoad &&
        !widget.isCreatedSale &&
        widget.onCreate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didAutoCreate) return;
        _didAutoCreate = true;
        unawaited(_handleCreate());
      });
    }
    if (widget.autoPrintOnLoad && widget.isCreatedSale) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didAutoPrint) return;
        _didAutoPrint = true;
        unawaited(_handlePrintPdf());
      });
    }
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

  DateTime get _documentTimestamp =>
      widget.createdAt ?? _createdSaleAt ?? DateTime.now();

  String get _documentNumber {
    final explicitNumber = (widget.receiptNumber ?? '').trim();
    if (explicitNumber.isNotEmpty) {
      return explicitNumber;
    }
    final createdSaleId = (_createdSaleId ?? '').trim();
    if (createdSaleId.isNotEmpty) {
      return '#${widget.status == SaleStatus.invoice ? 'INV' : 'REC'}-$createdSaleId';
    }
    final timestamp = _documentTimestamp;
    return '#${widget.status == SaleStatus.invoice ? 'INV' : 'REC'}-${timestamp.millisecondsSinceEpoch % 1000000}';
  }

  String get _documentLabel =>
      widget.status == SaleStatus.invoice ? 'Invoice' : 'Receipt';

  Future<void> _handleCreate() async {
    if (_isAnyBusy || widget.onCreate == null) return;
    setState(() => _statusBusy = true);
    final createdSaleId = await widget.onCreate!.call();
    if (!mounted) return;
    setState(() => _statusBusy = false);
    if (createdSaleId != null && createdSaleId.isNotEmpty) {
      setState(() {
        _createdSaleId = createdSaleId.trim();
        _createdSaleAt = DateTime.now();
      });
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
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName)],
        text: widget.status == SaleStatus.invoice
            ? 'Salesnote invoice'
            : 'Salesnote receipt',
      );
    } catch (e) {
      if (!mounted) return;
      AppNotice.show(context, 'Failed to share receipt: $e');
    } finally {
      if (mounted) {
        setState(() => _documentBusy = false);
      }
    }
  }

  Future<void> _handlePrintPdf() async {
    if (_isAnyBusy) return;
    setState(() => _documentBusy = true);
    try {
      final bytes = await _buildReceiptPdfBytes();
      await Printing.layoutPdf(
        name: _receiptFileName('pdf'),
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;
      AppNotice.show(context, 'Failed to print $_documentLabel: $e');
    } finally {
      if (mounted) {
        setState(() => _documentBusy = false);
      }
    }
  }

  bool get _isAnyBusy => _documentBusy || _statusBusy || _deleteBusy;

  Future<void> _handleMenuAction(_PreviewMenuAction action) async {
    switch (action) {
      case _PreviewMenuAction.downloadPdf:
        await _handleDownloadPdf();
        return;
      case _PreviewMenuAction.downloadImage:
        await _handleDownloadImage();
        return;
      case _PreviewMenuAction.share:
        await _handleShare();
        return;
      case _PreviewMenuAction.print:
        await _handlePrintPdf();
        return;
      case _PreviewMenuAction.markAsPaid:
        await _handleMarkAsPaid();
        return;
      case _PreviewMenuAction.deleteInvoice:
        await _handleDelete();
        return;
    }
  }

  Widget _buildOverflowMenu() {
    final showCreatedActions = widget.isCreatedSale;
    final showMarkAsPaid =
        widget.status == SaleStatus.invoice && widget.onMarkAsPaid != null;
    final showDelete =
        widget.status == SaleStatus.invoice && widget.onDelete != null;

    if (!showCreatedActions) {
      return const SizedBox(width: 44);
    }

    return PopupMenuButton<_PreviewMenuAction>(
      enabled: !_isAnyBusy,
      tooltip: 'More actions',
      onSelected: (value) => unawaited(_handleMenuAction(value)),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _PreviewMenuAction.print,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.print_outlined),
            title: Text('Print'),
          ),
        ),
        const PopupMenuItem(
          value: _PreviewMenuAction.downloadPdf,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.picture_as_pdf_outlined),
            title: Text('Download PDF'),
          ),
        ),
        PopupMenuItem(
          value: _PreviewMenuAction.downloadImage,
          enabled: _fitsSinglePage,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.image_outlined,
              color: _fitsSinglePage ? null : const Color(0xFF8A9AB3),
            ),
            title: Text(
              _fitsSinglePage
                  ? 'Download Image'
                  : 'Download Image (single page)',
            ),
          ),
        ),
        const PopupMenuItem(
          value: _PreviewMenuAction.share,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.share_outlined),
            title: Text('Share'),
          ),
        ),
        if (showMarkAsPaid)
          const PopupMenuItem(
            value: _PreviewMenuAction.markAsPaid,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle_outline_rounded),
              title: Text('Mark as paid'),
            ),
          ),
        if (showDelete)
          const PopupMenuItem(
            value: _PreviewMenuAction.deleteInvoice,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFD14343),
              ),
              title: Text(
                'Delete invoice',
                style: TextStyle(color: Color(0xFFD14343)),
              ),
            ),
          ),
      ],
      child: SizedBox(
        width: 44,
        height: 44,
        child: _isAnyBusy
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.more_vert_rounded, color: Color(0xFF46566E)),
      ),
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
    final timestamp = _documentTimestamp;
    final dateText = DateFormat('MMM d, yyyy | HH:mm').format(timestamp);
    final receiptNo = _documentNumber;
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
                    _buildOverflowMenu(),
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
                                  else
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
              if (!widget.isCreatedSale)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                  child: SizedBox(
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
