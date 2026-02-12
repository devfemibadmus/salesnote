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
        '#REC-${timestamp.millisecondsSinceEpoch % 1000000}';

    final shopLogoBytes = await _loadNetworkImageBytes(widget.shop?.logoUrl);
    final signatureBytes = await _loadNetworkImageBytes(
      widget.signature?.imageUrl,
    );

    final subtotal = widget.total;
    final grandTotal = widget.total;
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
            margin: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
            width: double.infinity,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(14),
              border: pw.Border.all(
                color: PdfColor.fromInt(0xFFDDE6F2),
                width: 1,
              ),
            ),
            padding: const pw.EdgeInsets.fromLTRB(18, 18, 18, 14),
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
                pw.Column(
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
                          child: pw.Text('DESCRIPTION', style: headLabelStyle),
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
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
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
                      _formatPdfAmount(subtotal),
                      false,
                    ),
                    pw.SizedBox(height: 6),
                    _pdfAmountRow(
                      'Grand Total',
                      _formatPdfAmount(grandTotal),
                      true,
                    ),
                    pw.SizedBox(height: 18),
                    pw.SizedBox(height: 8),
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
              ],
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

  Future<File> _savePdfToDevice(Uint8List bytes) async {
    final now = DateTime.now();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(now);
    final fileName = 'salesnote_receipt_$stamp.pdf';

    File file;
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        file = File('${downloadDir.path}/$fileName');
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        file = File('${docDir.path}/$fileName');
      }
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      file = File('${docDir.path}/$fileName');
    }

    try {
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      final fallback = await getApplicationDocumentsDirectory();
      final fallbackFile = File('${fallback.path}/$fileName');
      await fallbackFile.writeAsBytes(bytes, flush: true);
      return fallbackFile;
    }
  }

  Future<Uint8List?> _loadNetworkImageBytes(String? rawPath) async {
    final raw = (rawPath ?? '').trim();
    if (raw.isEmpty) return null;
    try {
      final url = MediaService.resolveSrc(raw);
      if (url.isEmpty) return null;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode >= 200 && response.statusCode < 300) {
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
}

class _PdfFonts {
  const _PdfFonts({required this.base, required this.bold});
  final pw.Font base;
  final pw.Font bold;
}
