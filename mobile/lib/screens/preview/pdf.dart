part of 'preview.dart';

extension _PreviewPdf on _SalePreviewScreenState {
  Future<Uint8List> _buildReceiptPdfBytes() async {
    final pdfFonts = await _loadPdfFonts();
    final pdf = pw.Document(
      theme: pdfFonts == null
          ? null
          : pw.ThemeData.withFont(
              base: pdfFonts.base,
              bold: pdfFonts.bold,
              italic: pdfFonts.base,
              boldItalic: pdfFonts.bold,
            ),
    );
    final timestamp = widget.createdAt ?? DateTime.now();
    final dateText = DateFormat('MMM d, yyyy | HH:mm').format(timestamp);
    final receiptNo =
        widget.receiptNumber ??
        '#${widget.status == SaleStatus.invoice ? 'INV' : 'REC'}-${timestamp.millisecondsSinceEpoch % 1000000}';

    final shopLogoBytes = await _loadNetworkImageBytes(widget.shop?.logoUrl);
    final signatureBytes = await _loadNetworkImageBytes(
      widget.signature?.imageUrl,
    );
    final selectedBankAccount = _selectedBankAccount;

    final customerName = widget.customerName.trim();
    final customerContact = widget.customerContact.trim();
    final hasCustomerDetails =
        customerName.isNotEmpty || customerContact.isNotEmpty;
    final customerTopValue = customerContact.isNotEmpty
        ? customerContact
        : customerName;
    final customerBottomValue = customerContact.isNotEmpty ? customerName : '';
    final qtyLabelStyle = pw.TextStyle(
      color: PdfColor.fromInt(0xFF5B6E8A),
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
    );
    final headLabelStyle = pw.TextStyle(
      color: PdfColor.fromInt(0xFF8A9AB3),
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
    );
    final itemRowHeight = 30.0;
    final receiptWidth = 390.0;
    final receiptHeight = (620.0 + (widget.items.length * itemRowHeight)).clamp(
      700.0,
      2000.0,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(receiptWidth, receiptHeight),
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Container(
            width: double.infinity,
            color: PdfColors.white,
            child: pw.Stack(
              children: [
                pw.Positioned.fill(
                  child: pw.Opacity(
                    opacity: 0.09,
                    child: _pdfWatermarkPattern(
                      'Salesnote',
                      receiptWidth,
                      receiptHeight,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Center(
                        child: _pdfAvatar(
                          shopLogoBytes,
                          widget.shop?.name ?? 'S',
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Center(
                        child: pw.Text(
                          widget.shop?.name ?? 'Shop',
                          style: pw.TextStyle(
                            color: PdfColor.fromInt(0xFF0E1930),
                            fontSize: 21,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      if ((widget.shop?.address ?? '').trim().isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Center(
                          child: pw.Text(
                            widget.shop!.address!.trim(),
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              color: PdfColor.fromInt(0xFF5A6C88),
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      pw.SizedBox(height: 4),
                      pw.Center(
                        child: pw.Text(
                          widget.shop?.phone ?? '',
                          style: pw.TextStyle(
                            color: PdfColor.fromInt(0xFF1677E6),
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 14),
                      pw.Divider(color: PdfColor.fromInt(0xFFE5ECF6)),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.SizedBox(
                            width: 36,
                            child: pw.Text('QTY', style: headLabelStyle),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              'DESCRIPTION',
                              style: headLabelStyle,
                            ),
                          ),
                          pw.Text('AMOUNT', style: headLabelStyle),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Divider(color: PdfColor.fromInt(0xFFE5ECF6)),
                      pw.SizedBox(height: 2),
                      ...widget.items.map((item) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.SizedBox(
                                width: 36,
                                child: pw.Text(
                                  item.quantity % 1 == 0
                                      ? item.quantity.toInt().toString()
                                      : item.quantity.toStringAsFixed(2),
                                  style: qtyLabelStyle,
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      item.productName,
                                      style: pw.TextStyle(
                                        color: PdfColor.fromInt(0xFF0E1930),
                                        fontSize: 13,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                    pw.SizedBox(height: 2),
                                    pw.Text(
                                      'Unit: ${_formatPdfAmount(item.unitPrice)}',
                                      style: pw.TextStyle(
                                        color: PdfColor.fromInt(0xFF8A9AB3),
                                        fontSize: 11,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              pw.SizedBox(width: 8),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  pw.Text(
                                    _formatPdfAmount(item.lineTotal),
                                    style: pw.TextStyle(
                                      color: PdfColor.fromInt(0xFF0E1930),
                                      fontSize: 13,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      pw.SizedBox(height: 6),
                      pw.Divider(color: PdfColor.fromInt(0xFFE5ECF6)),
                      pw.SizedBox(height: 10),
                      _pdfAmountRow(
                        'Subtotal',
                        _formatPdfAmount(widget.subtotal),
                        false,
                      ),
                      if (widget.discountAmount != 0) ...[
                        pw.SizedBox(height: 6),
                        _pdfAmountRow(
                          'Discount',
                          _formatSignedPdfAmount(-widget.discountAmount),
                          false,
                        ),
                      ],
                      if (widget.vatAmount != 0) ...[
                        pw.SizedBox(height: 6),
                        _pdfAmountRow(
                          'VAT',
                          _formatSignedPdfAmount(widget.vatAmount),
                          false,
                        ),
                      ],
                      if (widget.serviceFeeAmount != 0) ...[
                        pw.SizedBox(height: 6),
                        _pdfAmountRow(
                          'Service Fee',
                          _formatSignedPdfAmount(widget.serviceFeeAmount),
                          false,
                        ),
                      ],
                      if (widget.deliveryFeeAmount != 0) ...[
                        pw.SizedBox(height: 6),
                        _pdfAmountRow(
                          'Delivery',
                          _formatSignedPdfAmount(widget.deliveryFeeAmount),
                          false,
                        ),
                      ],
                      if (widget.roundingAmount != 0) ...[
                        pw.SizedBox(height: 6),
                        _pdfAmountRow(
                          'Rounding',
                          _formatSignedPdfAmount(widget.roundingAmount),
                          false,
                        ),
                      ],
                      if (widget.otherAmount != 0) ...[
                        pw.SizedBox(height: 6),
                        _pdfAmountRow(
                          widget.otherLabel.trim().isEmpty
                              ? 'Others'
                              : widget.otherLabel,
                          _formatSignedPdfAmount(widget.otherAmount),
                          false,
                        ),
                      ],
                      pw.SizedBox(height: 6),
                      _pdfAmountRow(
                        'Grand Total',
                        _formatPdfAmount(widget.total),
                        true,
                      ),
                      pw.SizedBox(height: 18),
                      if (widget.status == SaleStatus.invoice) ...[
                        _pdfBankDetails(selectedBankAccount),
                        pw.SizedBox(height: 18),
                      ],
                      if (widget.status != SaleStatus.invoice &&
                          hasCustomerDetails)
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              flex: 6,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.stretch,
                                  children: [
                                    pw.Container(
                                      height: 52,
                                      alignment: pw.Alignment.bottomCenter,
                                      child: pw.Text(
                                        customerTopValue,
                                        textAlign: pw.TextAlign.center,
                                        maxLines: 2,
                                        style: pw.TextStyle(
                                          color: PdfColor.fromInt(0xFF5A6C88),
                                          fontSize: 10,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    pw.Divider(
                                      color: PdfColor.fromInt(0xFFD6DEEA),
                                    ),
                                    pw.SizedBox(height: 4),
                                    if (customerBottomValue.isNotEmpty)
                                      pw.Text(
                                        customerBottomValue,
                                        textAlign: pw.TextAlign.center,
                                        maxLines: 2,
                                        style: pw.TextStyle(
                                          color: PdfColor.fromInt(0xFF0E1930),
                                          fontSize: 10,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 12),
                            pw.Expanded(
                              flex: 5,
                              child: pw.Column(
                                children: [
                                  pw.Container(
                                    height: 52,
                                    alignment: pw.Alignment.center,
                                    child: signatureBytes == null
                                        ? pw.SizedBox()
                                        : pw.Stack(
                                            alignment: pw.Alignment.center,
                                            children: [
                                              pw.Transform.translate(
                                                offset: const PdfPoint(2.0, 0),
                                                child: pw.Opacity(
                                                  opacity: 1.0,
                                                  child: pw.Image(
                                                    pw.MemoryImage(
                                                      signatureBytes,
                                                    ),
                                                    fit: pw.BoxFit.contain,
                                                  ),
                                                ),
                                              ),
                                              pw.Transform.translate(
                                                offset: const PdfPoint(1.4, 0),
                                                child: pw.Opacity(
                                                  opacity: 1.0,
                                                  child: pw.Image(
                                                    pw.MemoryImage(
                                                      signatureBytes,
                                                    ),
                                                    fit: pw.BoxFit.contain,
                                                  ),
                                                ),
                                              ),
                                              pw.Transform.translate(
                                                offset: const PdfPoint(0.8, 0),
                                                child: pw.Opacity(
                                                  opacity: 1.0,
                                                  child: pw.Image(
                                                    pw.MemoryImage(
                                                      signatureBytes,
                                                    ),
                                                    fit: pw.BoxFit.contain,
                                                  ),
                                                ),
                                              ),
                                              pw.Transform.translate(
                                                offset: const PdfPoint(0.2, 0),
                                                child: pw.Opacity(
                                                  opacity: 1.0,
                                                  child: pw.Image(
                                                    pw.MemoryImage(
                                                      signatureBytes,
                                                    ),
                                                    fit: pw.BoxFit.contain,
                                                  ),
                                                ),
                                              ),
                                              pw.Image(
                                                pw.MemoryImage(signatureBytes),
                                                fit: pw.BoxFit.contain,
                                              ),
                                            ],
                                          ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Divider(
                                    color: PdfColor.fromInt(0xFFD6DEEA),
                                  ),
                                  pw.SizedBox(height: 4),
                                  pw.Text(
                                    'AUTHORIZED SIGNATURE',
                                    textAlign: pw.TextAlign.center,
                                    style: pw.TextStyle(
                                      color: PdfColor.fromInt(0xFF8A9AB3),
                                      fontSize: 11,
                                      fontWeight: pw.FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else if (widget.status != SaleStatus.invoice) ...[
                        pw.Center(
                          child: pw.Container(
                            height: 52,
                            alignment: pw.Alignment.center,
                            child: signatureBytes == null
                                ? pw.SizedBox()
                                : pw.Stack(
                                    alignment: pw.Alignment.center,
                                    children: [
                                      pw.Transform.translate(
                                        offset: const PdfPoint(2.0, 0),
                                        child: pw.Opacity(
                                          opacity: 1.0,
                                          child: pw.Image(
                                            pw.MemoryImage(signatureBytes),
                                            fit: pw.BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                      pw.Transform.translate(
                                        offset: const PdfPoint(1.4, 0),
                                        child: pw.Opacity(
                                          opacity: 1.0,
                                          child: pw.Image(
                                            pw.MemoryImage(signatureBytes),
                                            fit: pw.BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                      pw.Transform.translate(
                                        offset: const PdfPoint(0.8, 0),
                                        child: pw.Opacity(
                                          opacity: 1.0,
                                          child: pw.Image(
                                            pw.MemoryImage(signatureBytes),
                                            fit: pw.BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                      pw.Transform.translate(
                                        offset: const PdfPoint(0.2, 0),
                                        child: pw.Opacity(
                                          opacity: 1.0,
                                          child: pw.Image(
                                            pw.MemoryImage(signatureBytes),
                                            fit: pw.BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                      pw.Image(
                                        pw.MemoryImage(signatureBytes),
                                        fit: pw.BoxFit.contain,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Divider(color: PdfColor.fromInt(0xFFD6DEEA)),
                        pw.SizedBox(height: 4),
                        pw.Center(
                          child: pw.Text(
                            'AUTHORIZED SIGNATURE',
                            style: pw.TextStyle(
                              color: PdfColor.fromInt(0xFF8A9AB3),
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                      pw.SizedBox(height: 10),
                      pw.Center(
                        child: pw.Text(
                          dateText,
                          style: pw.TextStyle(
                            color: PdfColor.fromInt(0xFF8A9AB3),
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Center(
                        child: pw.Text(
                          receiptNo,
                          style: pw.TextStyle(
                            color: PdfColor.fromInt(0xFF8A9AB3),
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

  String _receiptFileName(String extension) {
    final now = DateTime.now();
    final name = widget.customerName.trim().isNotEmpty
        ? widget.customerName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '').replaceAll(' ', '_')
        : 'Customer';
    final total = widget.total.toStringAsFixed(2);
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(now);
    return '$name--$total--$stamp.$extension';
  }

  Future<String> _savePdfToDevice(Uint8List bytes) async {
    final fileName = _receiptFileName('pdf');
    final baseName = fileName.substring(0, fileName.length - 4);
    final savedPath = await FileSaver.instance.saveAs(
      name: baseName,
      bytes: bytes,
      includeExtension: true,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
    if (savedPath == null || savedPath.trim().isEmpty) {
      throw Exception('Save cancelled.');
    }
    return savedPath;
  }

  Future<Uint8List> _buildReceiptImageBytes() async {
    final renderObject = _receiptBoundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw Exception('Receipt preview is not ready.');
    }
    final view = ui.PlatformDispatcher.instance.views.first;
    final pixelRatio = view.devicePixelRatio.clamp(1.0, 3.0);
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Unable to render image.');
    }
    return byteData.buffer.asUint8List();
  }

  Future<void> _saveImageToDevice(Uint8List bytes) async {
    final fileName = _receiptFileName('png');
    final result = await SaverGallery.saveImage(
      bytes,
      fileName: fileName,
      quality: 100,
      skipIfExists: false,
    );
    if (!result.isSuccess) {
      throw Exception(
        result.errorMessage ?? 'Unable to save image to gallery.',
      );
    }
  }

  Future<Uint8List?> _loadNetworkImageBytes(String? rawPath) async {
    final raw = (rawPath ?? '').trim();
    if (raw.isEmpty) return null;
    final cached = MediaService.loadCachedBytes(raw);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    try {
      final url = MediaService.resolveSrc(raw, withCacheBust: false);
      if (url.isEmpty) return null;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await MediaService.warmImage(raw);
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  pw.Widget _pdfAvatar(Uint8List? logoBytes, String name) {
    if (logoBytes != null) {
      return pw.Container(
        width: 56,
        height: 56,
        decoration: pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          border: pw.Border.all(color: PdfColor.fromInt(0xFFCBD8EA)),
        ),
        child: pw.ClipOval(
          child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.cover),
        ),
      );
    }
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S';
    return pw.Container(
      width: 56,
      height: 56,
      alignment: pw.Alignment.center,
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFE7EEF8),
        shape: pw.BoxShape.circle,
      ),
      child: pw.Text(
        initial,
        style: pw.TextStyle(
          color: PdfColor.fromInt(0xFF36527A),
          fontSize: 26,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _pdfAmountRow(String title, String value, bool strong) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              color: strong
                  ? PdfColor.fromInt(0xFF0E1930)
                  : PdfColor.fromInt(0xFF5B6E8A),
              fontSize: strong ? 15 : 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: strong
                ? PdfColor.fromInt(0xFF1677E6)
                : PdfColor.fromInt(0xFF0E1930),
            fontSize: strong ? 22 : 15,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatPdfAmount(num amount) {
    return _formatAmount(amount);
  }

  String _formatSignedPdfAmount(double amount) {
    if (amount < 0) {
      return '-${_formatPdfAmount(amount.abs())}';
    }
    return '+${_formatPdfAmount(amount)}';
  }

  pw.Widget _pdfWatermarkPattern(String text, double width, double height) {
    final watermarkStyle = pw.TextStyle(
      color: PdfColor.fromInt(0x2D4F7D),
      fontSize: 22,
      fontWeight: pw.FontWeight.bold,
    );

    pw.Widget row(int count) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: List.generate(
          count,
          (_) => pw.Transform.rotateBox(
            angle: -0.35,
            child: pw.Text(text, style: watermarkStyle),
          ),
        ),
      );
    }

    final rowCount = (height / 180).ceil().clamp(3, 6);
    final colCount = (width / 300).ceil().clamp(1, 3);

    return pw.ClipRect(
      child: pw.Center(
        child: pw.SizedBox(
          width: width * 1.15,
          height: height * 1.15,
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: List.generate(rowCount, (_) => row(colCount)),
          ),
        ),
      ),
    );
  }

  Future<_PdfFonts?> _loadPdfFonts() async {
    try {
      final baseData = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      return _PdfFonts(
        base: pw.Font.ttf(baseData),
        bold: pw.Font.ttf(boldData),
      );
    } catch (_) {
      return null;
    }
  }

  pw.Widget _pdfBankDetails(ShopBankAccount? bankAccount) {
    if (bankAccount == null) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF8FAFC),
          border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
        ),
        child: pw.Text(
          'No bank account added yet. Add one in Settings before sharing this invoice.',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: PdfColor.fromInt(0xFF64748B),
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
    }

    pw.Widget line(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 84,
              child: pw.Text(
                label.toUpperCase(),
                style: pw.TextStyle(
                  color: PdfColor.fromInt(0xFF8A9AB3),
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  color: PdfColor.fromInt(0xFF0E1930),
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF8FAFC),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PAY TO',
            style: pw.TextStyle(
              color: PdfColor.fromInt(0xFF667085),
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          line('Bank', bankAccount.bankName),
          line('Account No.', bankAccount.accountNumber),
          line('Account Name', bankAccount.accountName),
        ],
      ),
    );
  }
}

class _PdfFonts {
  const _PdfFonts({required this.base, required this.bold});
  final pw.Font base;
  final pw.Font bold;
}
