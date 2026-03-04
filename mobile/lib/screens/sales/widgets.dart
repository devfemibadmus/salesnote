part of 'sales.dart';

class _SalesHeader extends StatelessWidget {
  const _SalesHeader({
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

class _SalesSearchField extends StatelessWidget {
  const _SalesSearchField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF1)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 17, color: Color(0xFF334155)),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.fromLTRB(10, 14, 10, 12),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Color(0xFF94A3B8),
            size: 34,
          ),
          prefixIconConstraints: BoxConstraints(minWidth: 54, minHeight: 34),
          hintText: 'Search by customer or ID',
          hintStyle: TextStyle(fontSize: 17, color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}

class _SalesSectionHeader extends StatelessWidget {
  const _SalesSectionHeader({required this.text});
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

class _SalesTile extends StatelessWidget {
  const _SalesTile({
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
                    '#SALE-${sale.id} • $timeText',
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

class _EmptySalesVisual extends StatelessWidget {
  const _EmptySalesVisual();

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

class _SalesRowSkeleton extends StatelessWidget {
  const _SalesRowSkeleton();

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
          _SkelBox(width: 72, height: 72, radius: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkelLine(width: 190, height: 20),
                SizedBox(height: 10),
                _SkelLine(width: 240, height: 16),
              ],
            ),
          ),
          SizedBox(width: 12),
          _SkelLine(width: 86, height: 22),
        ],
      ),
    );
  }
}

class _SkelLine extends StatelessWidget {
  const _SkelLine({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return _SkelBox(width: width, height: height);
  }
}

class _SkelBox extends StatelessWidget {
  const _SkelBox({
    this.width = double.infinity,
    required this.height,
    this.radius = 10,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE7EBF1),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
