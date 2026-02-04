part of 'home.dart';

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.deltaText,
  });
  final String title;
  final String value;
  final String deltaText;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNegative = deltaText.contains('-');
    final deltaColor = isNegative
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);
    return Container(
      width: screenWidth * 0.76,
      height: 132,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF1)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -28,
            child: Container(
              width: 86,
              height: 86,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    fontSize: 28 / 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 54 / 2,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      isNegative
                          ? Icons.trending_down_rounded
                          : Icons.trending_up_rounded,
                      size: 16,
                      color: deltaColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      deltaText,
                      style: TextStyle(
                        color: deltaColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 30 / 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bars extends StatefulWidget {
  const _Bars({required this.bars});
  final List<_TrendBarPoint> bars;

  @override
  State<_Bars> createState() => _BarsState();
}

class _BarsState extends State<_Bars> {
  int? _selectedIndex;
  bool _animateIn = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _bestDefaultIndex(widget.bars);
    _startChartAnimation();
  }

  @override
  void didUpdateWidget(covariant _Bars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bars != widget.bars) {
      _selectedIndex = _bestDefaultIndex(widget.bars);
      _startChartAnimation();
    }
  }

  void _startChartAnimation() {
    _animateIn = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _animateIn = true);
    });
  }

  int? _bestDefaultIndex(List<_TrendBarPoint> bars) {
    if (bars.isEmpty) return null;
    var index = 0;
    var max = bars.first.total;
    for (var i = 1; i < bars.length; i++) {
      if (bars[i].total >= max) {
        max = bars[i].total;
        index = i;
      }
    }
    return index;
  }

  @override
  Widget build(BuildContext context) {
    final bars = widget.bars;
    final max = bars.isEmpty
        ? 1.0
        : bars.map((e) => e.total).reduce((a, b) => a > b ? a : b);
    final hasData = max > 0;
    final selectedIndex = _selectedIndex ?? _bestDefaultIndex(bars);
    final selectedPoint =
        (selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < bars.length)
        ? bars[selectedIndex]
        : null;

    return Container(
      height: 360,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          if (selectedPoint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${selectedPoint.label}: ${_homeFormatAmount(selectedPoint.total)} • ${selectedPoint.units.toStringAsFixed(0)} items sold',
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final p = i < bars.length ? bars[i].total : 0.0;
                final targetHeight = !hasData
                    ? 6.0
                    : (p <= 0 ? 6.0 : ((p / max) * 205).clamp(12.0, 205.0));
                final h = _animateIn ? targetHeight : 0.0;
                final isSelected = selectedIndex == i;
                final color = !hasData
                    ? const Color(0xFFBFD6EF)
                    : (p >= max
                          ? const Color(0xFF1E7DE8)
                          : (p >= (max * 0.7)
                                ? const Color(0xFF6FA9E3)
                                : const Color(0xFFBFD6EF)));
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GestureDetector(
                      onTap: i < bars.length
                          ? () => setState(() => _selectedIndex = i)
                          : null,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 1820 + (i * 45)),
                        curve: Curves.easeOutCubic,
                        height: h,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color
                              : color.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(4),
                          border: isSelected
                              ? Border.all(
                                  color: const Color(0xFF0F172A),
                                  width: 1.2,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(7, (i) {
              final label = i < bars.length ? bars[i].label : '-';
              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 15,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _TrendPill extends StatelessWidget {
  const _TrendPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF007AFF) : const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.text,
    required this.subtext,
  });
  final String title;
  final String text;
  final String subtext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final name = sale.customerName?.isNotEmpty == true
        ? sale.customerName!
        : 'Walk-in customer';
    final time = DateTime.tryParse(sale.createdAt);
    final subtitle =
        '#SALE-${sale.id} • ${time == null ? sale.createdAt : DateFormat('hh:mm a').format(time.toLocal())}';
    final initials = _initials(name);
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
            child: Text(initials),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _homeFormatAmount(sale.total),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
