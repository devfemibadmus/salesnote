part of 'invoices.dart';

class _InvoicesHeader extends StatelessWidget {
  const _InvoicesHeader({
    required this.title,
    required this.showBack,
    this.showFilter = true,
  });

  final String title;
  final bool showBack;
  final bool showFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBack)
          InkWell(
            onTap: () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(18),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.chevron_left,
                size: 38,
                color: Color(0xFF0F172A),
              ),
            ),
          )
        else
          const SizedBox(width: 4),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const Spacer(),
        if (showFilter)
          const Icon(Icons.tune_rounded, size: 30, color: Color(0xFF0F2548)),
      ],
    );
  }
}



class _InvoicesSectionHeader extends StatelessWidget {
  const _InvoicesSectionHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        letterSpacing: 1.3,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
      ),
    );
  }
}
class _InvoicesTile extends StatelessWidget {
  const _InvoicesTile({
    required this.sale,
    required this.amountText,
    required this.onTap,
  });
  final Sale sale;
  final String amountText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final customerName = (sale.customerName ?? '').trim().isEmpty
        ? 'Walk-in Customer'
        : sale.customerName!.trim();
    final initials = _initials(customerName);
    final dateTime = DateTime.tryParse(sale.createdAt)?.toLocal();
    final timeText = dateTime == null
        ? '--:--'
        : DateFormat('hh:mm a').format(dateTime);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFEAF1FB),
              child: Text(initials),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#INV-${sale.id} • $timeText',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amountText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'NA';
    if (parts.length == 1) {
      final text = parts.first.toUpperCase();
      return text.length > 1 ? text.substring(0, 2) : text;
    }
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
}

class _EmptyInvoicesVisual extends StatelessWidget {
  const _EmptyInvoicesVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 370,
      height: 370,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 350,
            height: 350,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE8EEF6),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 120,
              color: Color(0xFFAFC8E5),
            ),
          ),
          Positioned(
            right: 78,
            bottom: 70,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x220F172A),
                    blurRadius: 14,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_bag_rounded,
                size: 44,
                color: Color(0xFF007AFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoicesRowSkeleton extends StatelessWidget {
  const _InvoicesRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          SkelBox(width: 72, height: 72, radius: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkelLine(width: 190, height: 20),
                SizedBox(height: 10),
                SkelLine(width: 240, height: 16),
              ],
            ),
          ),
          SizedBox(width: 12),
          SkelLine(width: 86, height: 22),
        ],
      ),
    );
  }
}



