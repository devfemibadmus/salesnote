part of 'preview.dart';

class _ReceiptWatermark extends StatelessWidget {
  const _ReceiptWatermark({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ReceiptWatermarkPainter(text),
      ),
    );
  }
}

class _ReceiptWatermarkPainter extends CustomPainter {
  _ReceiptWatermarkPainter(this.text);

  final String text;

  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0xFF2D4F7D);
    final style = TextStyle(
      color: color.withValues(alpha: 0.06),
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final textWidth = textPainter.width;
    final textHeight = textPainter.height;
    if (textWidth == 0 || textHeight == 0) return;

    final spacingX = textWidth + 56;
    final spacingY = textHeight + 46;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.35);
    canvas.translate(-size.width / 2, -size.height / 2);

    for (double y = -textHeight; y < size.height + textHeight; y += spacingY) {
      for (double x = -textWidth; x < size.width + textWidth; x += spacingX) {
        textPainter.paint(canvas, Offset(x, y));
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReceiptWatermarkPainter oldDelegate) {
    return oldDelegate.text != text;
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.title,
    required this.value,
    required this.strong,
  });

  final String title;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: strong ? const Color(0xFF0E1930) : const Color(0xFF5B6E8A),
              fontSize: strong ? 17 : 16,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              letterSpacing: strong ? .3 : 0,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: strong ? const Color(0xFF1677E6) : const Color(0xFF0E1930),
            fontSize: strong ? 24 : 18,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PreviewShopAvatar extends StatelessWidget {
  const _PreviewShopAvatar({required this.shop});
  final ShopProfile? shop;

  @override
  Widget build(BuildContext context) {
    final logo = shop?.logoUrl;
    final provider = MediaService.imageProvider(logo);
    if (provider != null) {
      return Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD8EA)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image(
          image: provider,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackAvatar(),
        ),
      );
    }
    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    final name = (shop?.name ?? '').trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';
    return Container(
      width: 74,
      height: 74,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFE7EEF8),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFF36527A),
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PreviewSignature extends StatelessWidget {
  const _PreviewSignature({required this.signature});
  final SignatureItem? signature;

  @override
  Widget build(BuildContext context) {
    final provider = MediaService.imageProvider(signature?.imageUrl);
    if (provider != null) {
      return Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: const Offset(1.6, 0),
              child: Opacity(
                opacity: 0.95,
                child: Image(
                  image: provider,
                  fit: BoxFit.contain,
                  color: const Color(0xFF111111),
                  colorBlendMode: BlendMode.srcATop,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(1.0, 0),
              child: Opacity(
                opacity: 0.85,
                child: Image(
                  image: provider,
                  fit: BoxFit.contain,
                  color: const Color(0xFF111111),
                  colorBlendMode: BlendMode.srcATop,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0.4, 0),
              child: Opacity(
                opacity: 0.65,
                child: Image(
                  image: provider,
                  fit: BoxFit.contain,
                  color: const Color(0xFF111111),
                  colorBlendMode: BlendMode.srcATop,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
            Image(
              image: provider,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _PreviewBankDetails extends StatelessWidget {
  const _PreviewBankDetails({required this.bankAccount});

  final ShopBankAccount? bankAccount;

  @override
  Widget build(BuildContext context) {
    if (bankAccount == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'No bank account added yet. Add one in Settings before sharing this invoice.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    Widget line(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 108,
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF8A9AB3),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF0E1930),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PAY TO',
            style: TextStyle(
              color: Color(0xFF667085),
              letterSpacing: 2.0,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          line('Bank', bankAccount!.bankName),
          line('Account No.', bankAccount!.accountNumber),
          line('Account Name', bankAccount!.accountName),
        ],
      ),
    );
  }
}
