part of 'items.dart';

class _ItemsHeader extends StatelessWidget {
  const _ItemsHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: 4),
        SizedBox(width: 10),
        Text(
          'Items',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        Spacer(),
      ],
    );
  }
}



class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.row, required this.formatAmount});

  final _ItemRow row;
  final String Function(num amount, {int decimalDigits}) formatAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Text(_initials(row.name)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.quantity.toStringAsFixed(0)} items sold • @ ${formatAmount(row.unitPrice)}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatAmount(row.total),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'NA';
    if (parts.length == 1) {
      final token = parts.first;
      return token.length >= 2
          ? token.substring(0, 2).toUpperCase()
          : token.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }
}

class _EmptyItemsVisual extends StatelessWidget {
  const _EmptyItemsVisual();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 210,
        height: 210,
        decoration: const BoxDecoration(
          color: Color(0xFFE8EEF6),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.inventory_2_outlined,
          size: 84,
          color: Color(0xFFAFC8E5),
        ),
      ),
    );
  }
}

class _ItemsRowSkeleton extends StatelessWidget {
  const _ItemsRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          SkelBox(width: 52, height: 52, radius: 26),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkelLine(width: 170, height: 18),
                SizedBox(height: 8),
                SkelLine(width: 120, height: 14),
              ],
            ),
          ),
          SizedBox(width: 10),
          SkelLine(width: 78, height: 20),
        ],
      ),
    );
  }
}


