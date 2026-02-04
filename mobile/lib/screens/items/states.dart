part of 'items.dart';

class _ItemsLoadingState extends StatelessWidget {
  const _ItemsLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: const [
        _ItemsHeader(),
        SizedBox(height: 20),
        _ItemsSearchField(readOnly: true),
        SizedBox(height: 18),
        _ItemsRowSkeleton(),
        SizedBox(height: 12),
        _ItemsRowSkeleton(),
        SizedBox(height: 12),
        _ItemsRowSkeleton(),
        SizedBox(height: 12),
        _ItemsRowSkeleton(),
      ],
    );
  }
}

class _ItemsEmptyState extends StatelessWidget {
  const _ItemsEmptyState({required this.onAddSale, this.message});

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
        const _ItemsHeader(),
        const SizedBox(height: 82),
        const _EmptyItemsVisual(),
        const SizedBox(height: 28),
        const Center(
          child: Text(
            'No items yet',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            message ??
                'Your sold items will appear here after recording sales.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.45,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: SizedBox(
            width: 320,
            height: 60,
            child: FilledButton.icon(
              onPressed: onAddSale,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Sale',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemsMainState extends StatelessWidget {
  const _ItemsMainState({
    required this.queryController,
    required this.rows,
    required this.formatAmount,
    required this.loadingMore,
    required this.hasMore,
    required this.onLoadMore,
  });

  final TextEditingController queryController;
  final List<_ItemRow> rows;
  final String Function(num amount, {int decimalDigits}) formatAmount;
  final bool loadingMore;
  final bool hasMore;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              children: [
                const _ItemsHeader(),
                const SizedBox(height: 20),
                _ItemsSearchField(controller: queryController),
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
                if (rows.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5EAF1)),
                    ),
                    child: const Text(
                      'No matching items yet. You can load more or change your search.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                ...rows.map((row) => _ItemTile(row: row, formatAmount: formatAmount)),
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
                            hasMore ? 'Load more' : 'No more items',
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
}
