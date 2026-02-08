part of 'sales.dart';

class _SalesLoadingState extends StatelessWidget {
  const _SalesLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: const [
        _SalesHeader(
          title: 'Sales History',
          showBack: false,
          showFilter: false,
        ),
        SizedBox(height: 20),
        _SkelBox(height: 70, radius: 20),
        SizedBox(height: 26),
        _SkelLine(width: 170, height: 20),
        SizedBox(height: 18),
        _SalesRowSkeleton(),
        SizedBox(height: 14),
        _SalesRowSkeleton(),
        SizedBox(height: 14),
        _SalesRowSkeleton(),
        SizedBox(height: 26),
        _SkelLine(width: 230, height: 20),
        SizedBox(height: 18),
        _SalesRowSkeleton(),
        SizedBox(height: 14),
        _SalesRowSkeleton(),
      ],
    );
  }
}

class _SalesEmptyState extends StatelessWidget {
  const _SalesEmptyState({required this.onAddSale, this.message});

  final VoidCallback onAddSale;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        const _SalesHeader(
          title: 'Sales History',
          showBack: false,
          showFilter: false,
        ),
        const SizedBox(height: 88),
        const _EmptySalesVisual(),
        const SizedBox(height: 32),
        const Center(
          child: Text(
            'No sales yet',
            style: TextStyle(
              fontSize: 52 / 2,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            message ??
                'Your completed sales will appear\nhere. Start by adding a new sale.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              height: 1.5,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(height: 30),
        Center(
          child: SizedBox(
            width: 330,
            height: 72,
            child: FilledButton.icon(
              onPressed: onAddSale,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 6,
                shadowColor: const Color(0xFF007AFF).withValues(alpha: 0.35),
              ),
              icon: const Icon(Icons.add, size: 34),
              label: const Text(
                'Add Sale',
                style: TextStyle(fontSize: 38 / 2, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SalesMainState extends StatelessWidget {
  const _SalesMainState({
    required this.queryController,
    required this.sales,
    required this.loadingMore,
    required this.hasMore,
    required this.formatAmount,
    required this.onLoadMore,
    required this.onOpenSale,
  });

  final TextEditingController queryController;
  final List<Sale> sales;
  final bool loadingMore;
  final bool hasMore;
  final String Function(num amount) formatAmount;
  final Future<void> Function() onLoadMore;
  final Future<void> Function(Sale sale) onOpenSale;

  @override
  Widget build(BuildContext context) {
    final groups = _groupSales(sales);
    final sections = groups.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              children: [
                const _SalesHeader(
                  title: 'Sales History',
                  showBack: false,
                  showFilter: false,
                ),
                const SizedBox(height: 20),
                _SalesSearchField(controller: queryController),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
              if (sections.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5EAF1)),
                  ),
                  child: const Text(
                    'No matching sales yet. You can load more or change your search.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              for (final section in sections) ...[
                _SalesSectionHeader(text: _sectionTitle(section.key)),
                const SizedBox(height: 14),
                ...section.value.map(
                  (sale) => _SalesTile(
                    sale: sale,
                    amountText: formatAmount(sale.total),
                    onTap: () => onOpenSale(sale),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: (loadingMore || !hasMore) ? null : onLoadMore,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF007AFF),
                    side: BorderSide(
                      color: hasMore
                          ? const Color(0xFF007AFF)
                          : const Color(0xFFCBD5E1),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: loadingMore
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          hasMore ? 'Load more' : 'No more sales',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
            ),
          ),
        ],
      ),
    );
  }

  Map<DateTime, List<Sale>> _groupSales(List<Sale> value) {
    final map = <DateTime, List<Sale>>{};
    for (final sale in value) {
      final date =
          DateTime.tryParse(sale.createdAt)?.toLocal() ?? DateTime.now();
      final day = DateTime(date.year, date.month, date.day);
      map.putIfAbsent(day, () => <Sale>[]).add(sale);
    }
    return map;
  }

  String _sectionTitle(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return 'TODAY';
    if (day == yesterday) return 'YESTERDAY';
    return DateFormat('MMM d, yyyy').format(day).toUpperCase();
  }
}
