part of 'preview.dart';

class SalePreviewScreen extends StatefulWidget {
  const SalePreviewScreen({
    super.key,
    required this.isCreatedSale,
    required this.shop,
    required this.signature,
    required this.customerName,
    required this.customerContact,
    required this.items,
    required this.total,
    this.receiptNumber,
    this.createdAt,
    this.onCreate,
    this.onDownloadPdf,
  });

  final bool isCreatedSale;
  final ShopProfile? shop;
  final SignatureItem? signature;
  final String customerName;
  final String customerContact;
  final List<PreviewSaleItem> items;
  final double total;
  final String? receiptNumber;
  final DateTime? createdAt;
  final Future<bool> Function()? onCreate;
  final Future<void> Function()? onDownloadPdf;

  @override
  State<SalePreviewScreen> createState() => _SalePreviewScreenState();
}

class _SalePreviewScreenState extends State<SalePreviewScreen> {
  bool _busy = false;
  bool _fitsSinglePage = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_receiptScrollController.hasClients) return;
      _updateSinglePageFlag(
        _receiptScrollController.position.maxScrollExtent <= 1,
      );
    });
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

  Future<void> _handleCreate() async {
    if (_busy || widget.onCreate == null) return;
    setState(() => _busy = true);
    final ok = await widget.onCreate!.call();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleDownloadPdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _buildReceiptPdfBytes();
      await _savePdfToDevice(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF downloaded successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleDownloadImage() async {
    if (_busy) return;
    if (!_fitsSinglePage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image download is only available for single-page receipts.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await _buildReceiptImageBytes();
      await _saveImageToDevice(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image saved to gallery.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download image: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleShare() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _buildReceiptPdfBytes();
      final fileName =
          'salesnote_receipt_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: fileName,
          ),
        ],
        text: 'Salesnote receipt',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share receipt: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openActionsSheet() async {
    if (_busy) return;
    final action = await showModalBottomSheet<_ReceiptAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 54,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D9E6),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download PDF'),
                onTap: () => Navigator.of(context).pop(_ReceiptAction.downloadPdf),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Download Image'),
                subtitle: !_fitsSinglePage
                    ? const Text('Only available for single-page receipts')
                    : null,
                enabled: _fitsSinglePage,
                onTap: _fitsSinglePage
                    ? () => Navigator.of(context).pop(_ReceiptAction.downloadImage)
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share'),
                onTap: () => Navigator.of(context).pop(_ReceiptAction.share),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    switch (action) {
      case _ReceiptAction.downloadPdf:
        await _handleDownloadPdf();
        break;
      case _ReceiptAction.downloadImage:
        await _handleDownloadImage();
        break;
      case _ReceiptAction.share:
        await _handleShare();
        break;
    }
  }

  void _updateSinglePageFlag(bool next) {
    if (_fitsSinglePage == next) return;
    setState(() => _fitsSinglePage = next);
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = widget.createdAt ?? DateTime.now();
    final dateText = DateFormat('MMM d, yyyy | HH:mm').format(timestamp);
    final receiptNo =
        widget.receiptNumber ?? '#REC-${timestamp.millisecondsSinceEpoch % 1000000}';
    final customerName = widget.customerName.trim();
    final customerContact = widget.customerContact.trim();

    return PopScope(
      canPop: !_busy,
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
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF46566E),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'E-Receipt',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
                  _updateSinglePageFlag(notification.metrics.maxScrollExtent <= 1);
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
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                        Center(child: _PreviewShopAvatar(shop: widget.shop)),
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
                        if ((widget.shop?.address ?? '').trim().isNotEmpty) ...[
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
                        if (customerName.isNotEmpty ||
                            customerContact.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5ECF6)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CUSTOMER',
                                  style: TextStyle(
                                    color: Color(0xFF8A9AB3),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                                if (customerName.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    customerName,
                                    style: const TextStyle(
                                      color: Color(0xFF0E1930),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                if (customerContact.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    customerContact,
                                    style: const TextStyle(
                                      color: Color(0xFF5A6C88),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        const Divider(color: Color(0xFFE5ECF6), height: 1),
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
                        const Divider(color: Color(0xFFE5ECF6), height: 1),
                        const SizedBox(height: 6),
                        ...widget.items.map(_buildItemRow),
                        const SizedBox(height: 8),
                        const Divider(color: Color(0xFFE5ECF6), height: 1),
                        const SizedBox(height: 12),
                        _AmountRow(
                          title: 'Subtotal',
                          value: _formatAmount(widget.total),
                          strong: false,
                        ),
                        const SizedBox(height: 6),
                        _AmountRow(
                          title: 'Grand Total',
                          value: _formatAmount(widget.total),
                          strong: true,
                        ),
                        const SizedBox(height: 24),
                        Column(
                          children: [
                            SizedBox(
                              height: 68,
                              child: _PreviewSignature(signature: widget.signature),
                            ),
                            const SizedBox(height: 4),
                            const Divider(color: Color(0xFFD6DEEA), height: 1),
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
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: widget.isCreatedSale
                    ? OutlinedButton.icon(
                        onPressed: _busy ? null : _openActionsSheet,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1C2D44),
                          side: const BorderSide(color: Color(0xFFD8E2EF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.more_horiz_rounded),
                        label: const Text(
                          'Receipt Actions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _busy ? null : _handleCreate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1677E6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 6,
                          shadowColor: const Color(0x331677E6),
                        ),
                        icon: _busy
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
                          _busy ? 'Creating...' : 'Create Sale & Receipt',
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

enum _ReceiptAction { downloadPdf, downloadImage, share }
