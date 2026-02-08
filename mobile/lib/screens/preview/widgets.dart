part of 'preview.dart';

class _LabelValue extends StatelessWidget {
  const _LabelValue({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8A9AB3),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Color(0xFF0E1930),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
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
    if (logo != null && logo.trim().isNotEmpty) {
      final url = MediaService.resolveSrc(logo.trim());
      if (url.isNotEmpty) {
        return Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFCBD8EA)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _fallbackAvatar(),
          ),
        );
      }
    }
    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    final initial = (shop?.name ?? 'S').trim().isNotEmpty
        ? (shop!.name.trim()[0]).toUpperCase()
        : 'S';
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
    final raw = signature?.imageUrl ?? '';
    final url = raw.trim().isEmpty ? '' : MediaService.resolveSrc(raw);
    if (url.isNotEmpty) {
      return Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
