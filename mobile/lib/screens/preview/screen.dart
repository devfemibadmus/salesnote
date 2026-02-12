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
  late final String _currencySymbol;
  late final String _currencyLocale;

  @override
  void initState() {
    super.initState();
    final ctx = CurrencyService.resolveContext();
    _currencyLocale = ctx.locale;
    _currencySymbol = ctx.symbol;
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

  Future<void> _handleDownload() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _buildReceiptPdfBytes();
      final file = await _savePdfToDevice(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF downloaded: ${file.path}')),
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

  @override
  Widget build(BuildContext context) {
    final timestamp = widget.createdAt ?? DateTime.now();
    final dateText = DateFormat('MMM d, yyyy | HH:mm').format(timestamp);
    final receiptNo =
        widget.receiptNumber ?? '#REC-${timestamp.millisecondsSinceEpoch % 1000000}';

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: widget.isCreatedSale
                    ? OutlinedButton.icon(
                        onPressed: _busy ? null : _handleDownload,
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
                            : const Icon(Icons.download_rounded),
                        label: const Text(
                          'Download PDF',
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
