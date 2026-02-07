part of 'preview.dart';

extension _PreviewPdf on _SalePreviewScreenState {
  Future<Uint8List> _buildReceiptPdfBytes() async {
    final pdf = pw.Document();
    final timestamp = widget.createdAt ?? DateTime.now();
    final dateText = DateFormat('MMM d, yyyy | HH:mm').format(timestamp);
    final receiptNo =
        widget.receiptNumber ?? '#REC-${timestamp.millisecondsSinceEpoch % 1000000}';

    final shopLogoBytes = await _loadNetworkImageBytes(widget.shop?.logoUrl);
    final signatureBytes = await _loadNetworkImageBytes(widget.signature?.imageUrl);

    final subtotal = widget.total;
    final grandTotal = widget.total;
    final qtyLabelStyle = pw.TextStyle(
      color: PdfColor.fromInt(0xFF5B6E8A),
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
    );
    final headLabelStyle = pw.TextStyle(
      color: PdfColor.fromInt(0xFF8A9AB3),
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(14),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFDDE6F2), width: 1),
              ),
              padding: const pw.EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(child: _pdfAvatar(shopLogoBytes, widget.shop?.name ?? 'S')),
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.Text(
                      widget.shop?.name ?? 'Shop',
                      style: pw.TextStyle(
                        color: PdfColor.fromInt(0xFF0E1930),
                        fontSize: 18,
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
                          fontSize: 11,
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
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Divider(color: PdfColor.fromInt(0xFFE5ECF6)),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: _pdfLabelValue('RECEIPT NO.', receiptNo, false),
                      ),
                      pw.Expanded(
                        child: _pdfLabelValue('DATE & TIME', dateText, true),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(color: PdfColor.fromInt(0xFFE5ECF6)),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.SizedBox(width: 36, child: pw.Text('QTY', style: headLabelStyle)),
                      pw.Expanded(child: pw.Text('DESCRIPTION', style: headLabelStyle)),
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
                            child: pw.Text(
                              item.productName,
                              style: pw.TextStyle(
                                color: PdfColor.fromInt(0xFF0E1930),
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            _formatAmount(item.lineTotal),
                            style: pw.TextStyle(
                              color: PdfColor.fromInt(0xFF0E1930),
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  pw.SizedBox(height: 6),
                  pw.Divider(color: PdfColor.fromInt(0xFFE5ECF6)),
                  pw.SizedBox(height: 10),
                  _pdfAmountRow('Subtotal', _formatAmount(subtotal), false),
                  pw.SizedBox(height: 6),
                  _pdfAmountRow('Grand Total', _formatAmount(grandTotal), true),
                  pw.SizedBox(height: 18),
                  pw.Center(
                    child: pw.Text(
                      'Thank you for your business!',
                      style: pw.TextStyle(
                        color: PdfColor.fromInt(0xFF5B6E8A),
                        fontSize: 14,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Center(
                    child: pw.Container(
                      height: 52,
                      alignment: pw.Alignment.center,
                      child: signatureBytes == null
                          ? pw.SizedBox()
                          : pw.Image(
                              pw.MemoryImage(signatureBytes),
                              fit: pw.BoxFit.contain,
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
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ];
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
          fontSize: 24,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _pdfLabelValue(String label, String value, bool alignEnd) {
    return pw.Column(
      crossAxisAlignment: alignEnd ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: PdfColor.fromInt(0xFF8A9AB3),
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          textAlign: alignEnd ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            color: PdfColor.fromInt(0xFF0E1930),
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfAmountRow(String title, String value, bool strong) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              color: strong ? PdfColor.fromInt(0xFF0E1930) : PdfColor.fromInt(0xFF5B6E8A),
              fontSize: strong ? 13 : 11,
              fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: strong ? PdfColor.fromInt(0xFF1677E6) : PdfColor.fromInt(0xFF0E1930),
            fontSize: strong ? 18 : 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
