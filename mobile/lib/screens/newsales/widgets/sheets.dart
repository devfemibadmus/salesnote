part of '../newsales.dart';

class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet({
    required this.api,
    required this.currencySymbol,
    required this.formatAmount,
  });

  final ApiClient api;
  final String currencySymbol;
  final String Function(num amount, {int decimalDigits}) formatAmount;

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  static Future<void>? _globalSuggestionsFetch;
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _unitPriceController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final List<String> _itemSuggestionsCache = <String>[];
  List<String> _visibleSuggestions = <String>[];

  double _qty = 1;

  @override
  void initState() {
    super.initState();
    _itemNameController.addListener(_onItemNameChanged);
    _loadItemSuggestions();
  }

  @override
  void dispose() {
    _itemNameController.removeListener(_onItemNameChanged);
    _itemNameController.dispose();
    _unitPriceController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  double get _unitPrice =>
      double.tryParse(_unitPriceController.text.trim()) ?? 0;
  double get _lineTotal => _unitPrice * _qty;

  bool get _canAdd =>
      _itemNameController.text.trim().isNotEmpty && _unitPrice > 0;

  void _onItemNameChanged() {
    _rebuildVisibleSuggestions();
    setState(() {});
  }

  void _rebuildVisibleSuggestions() {
    final query = _itemNameController.text.trim().toLowerCase();
    final unique = _itemSuggestionsCache.toSet().toList();

    if (query.isEmpty) {
      _visibleSuggestions = unique.take(6).toList();
      return;
    }

    final scored = unique
        .map((name) {
          final lower = name.toLowerCase();
          int rank;
          if (lower == query) {
            rank = 0;
          } else if (lower.startsWith(query)) {
            rank = 1;
          } else if (lower.contains(query)) {
            rank = 2;
          } else {
            final words = lower.split(RegExp(r'[\s\-_]+'));
            rank = words.any((w) => w.startsWith(query)) ? 3 : 99;
          }
          return (
            name: name,
            rank: rank,
            lengthDiff: (lower.length - query.length).abs(),
          );
        })
        .where((e) => e.rank < 99)
        .toList();

    scored.sort((a, b) {
      final rank = a.rank.compareTo(b.rank);
      if (rank != 0) return rank;
      final len = a.lengthDiff.compareTo(b.lengthDiff);
      if (len != 0) return len;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    _visibleSuggestions = scored
        .map((e) => e.name)
        .where((name) => name.toLowerCase() != query)
        .take(6)
        .toList();
  }

  Future<void> _loadItemSuggestions() async {
    var hasAnyCachedSuggestions = false;

    final cached = LocalCache.loadItemSuggestions();
    if (cached.isNotEmpty) {
      hasAnyCachedSuggestions = true;
      _itemSuggestionsCache
        ..clear()
        ..addAll(cached);
      _rebuildVisibleSuggestions();
      if (mounted) setState(() {});
      return;
    }

    final cachedItemsPage = LocalCache.loadSalesPage(includeItems: true);
    if (cachedItemsPage != null) {
      final names = _extractItemNamesFromSalesPage(cachedItemsPage);
      if (names.isNotEmpty) {
        hasAnyCachedSuggestions = true;
        _itemSuggestionsCache
          ..clear()
          ..addAll(names);
        _rebuildVisibleSuggestions();
        if (mounted) setState(() {});
        await LocalCache.saveItemSuggestions(_itemSuggestionsCache);
      }
    }

    if (!hasAnyCachedSuggestions) {
      unawaited(_fetchSuggestionsInBackgroundOnce());
    }
  }

  List<String> _extractItemNamesFromSalesPage(Map<String, dynamic> page) {
    final sales = (page['sales'] as List<dynamic>? ?? const <dynamic>[]);
    final names = <String>[];
    for (final sale in sales) {
      final map = sale as Map<String, dynamic>;
      final items = (map['items'] as List<dynamic>? ?? const <dynamic>[]);
      for (final item in items) {
        final productName =
            ((item as Map<String, dynamic>)['product_name'] ?? '')
                .toString()
                .trim();
        if (productName.isNotEmpty) names.add(productName);
      }
    }
    return names.toSet().toList();
  }

  Future<void> _fetchSuggestionsInBackgroundOnce() async {
    final inFlight = _globalSuggestionsFetch;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final request = _fetchSuggestionsInBackground();
    _globalSuggestionsFetch = request;
    try {
      await request;
    } finally {
      if (identical(_globalSuggestionsFetch, request)) {
        _globalSuggestionsFetch = null;
      }
    }
  }

  Future<void> _fetchSuggestionsInBackground() async {
    try {
      final sales = await widget.api.listSales(
        page: 1,
        perPage: 100,
        includeItems: true,
      );
      final names = <String>{};
      for (final sale in sales) {
        for (final item in sale.items) {
          final name = item.productName.trim();
          if (name.isNotEmpty) names.add(name);
        }
      }
      if (names.isEmpty) {
        return;
      }
      _itemSuggestionsCache
        ..clear()
        ..addAll(names);
      _rebuildVisibleSuggestions();
      if (mounted) setState(() {});
      await LocalCache.saveItemSuggestions(_itemSuggestionsCache);
      await LocalCache.saveSalesPage(
        includeItems: true,
        sales: sales.map((e) => e.toJson()).toList(),
        page: 1,
        hasMore: sales.length == 100,
      );
    } catch (_) {}
  }

  Future<void> _rememberItemName(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (_itemSuggestionsCache.any(
      (e) => e.toLowerCase() == normalized.toLowerCase(),
    )) {
      return;
    }
    _itemSuggestionsCache.insert(0, normalized);
    _rebuildVisibleSuggestions();
    if (mounted) setState(() {});
    await LocalCache.saveItemSuggestions(_itemSuggestionsCache);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.94;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 74,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D9E6),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InputBox(
                    controller: _itemNameController,
                    hint: 'Wireless Earbuds',
                    focusNode: _nameFocus,
                    compact: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_visibleSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: _visibleSuggestions.map((label) {
                        return _SuggestionChip(
                          label: label,
                          active:
                              _itemNameController.text.trim().toLowerCase() ==
                              label.toLowerCase(),
                          onTap: () {
                            _itemNameController.text = label;
                            _itemNameController.selection =
                                TextSelection.fromPosition(
                                  TextPosition(offset: label.length),
                                );
                            _rebuildVisibleSuggestions();
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'QUANTITY',
                              style: TextStyle(
                                color: Color(0xFF5F708A),
                                letterSpacing: 2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _QuantityStepper(
                              quantity: _qty,
                              onMinus: () => setState(
                                () =>
                                    _qty = (_qty - 1).clamp(1, 9999).toDouble(),
                              ),
                              onPlus: () => setState(
                                () =>
                                    _qty = (_qty + 1).clamp(1, 9999).toDouble(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'UNIT PRICE',
                              style: TextStyle(
                                color: Color(0xFF5F708A),
                                letterSpacing: 2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _InputBox(
                              controller: _unitPriceController,
                              hint: 'Unit price',
                              compact: true,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setState(() {}),
                              prefix: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  widget.currencySymbol,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFC8DBF5)),
                      color: const Color(0xFFF1F6FC),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'LINE TOTAL\n',
                                  style: TextStyle(
                                    color: Color(0xFF1677E6),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                    fontSize: 11,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      '${_qty.toStringAsFixed(_qty.truncateToDouble() == _qty ? 0 : 2)} units × '
                                      '${widget.formatAmount(_unitPrice, decimalDigits: 2)}',
                                  style: const TextStyle(
                                    color: Color(0xFF5E708A),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          widget.formatAmount(_lineTotal, decimalDigits: 2),
                          style: const TextStyle(
                            color: Color(0xFF1677E6),
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: ElevatedButton(
                      onPressed: _canAdd
                          ? () async {
                              await _rememberItemName(_itemNameController.text);
                              if (!mounted) {
                                return;
                              }
                              Navigator.of(this.context).pop(
                                _DraftSaleItem(
                                  productName: _itemNameController.text.trim(),
                                  quantity: _qty,
                                  unitPrice: _unitPrice,
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1677E6),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF9EC4F2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 7,
                        shadowColor: const Color(0x331677E6),
                      ),
                      child: const Text(
                        '🛒  Add to Sale',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddSignatureSheet extends StatefulWidget {
  const _AddSignatureSheet({required this.onUpload});

  final Future<SignatureItem> Function(String name, String imagePath) onUpload;

  @override
  State<_AddSignatureSheet> createState() => _AddSignatureSheetState();
}

class _AddSignatureSheetState extends State<_AddSignatureSheet> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _path;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving && _nameController.text.trim().isNotEmpty && _path != null;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.94;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D9E6),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'New Signature',
                    style: TextStyle(
                      color: Color(0xFF0E1930),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _InputBox(
                    controller: _nameController,
                    hint: 'Signature name',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _saving
                        ? null
                        : () async {
                            final file = await _picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 90,
                            );
                            if (file == null) return;
                            if (!mounted) return;
                            setState(() => _path = file.path);
                          },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFC8D5E6)),
                        color: const Color(0xFFF8FAFC),
                      ),
                      child: _path == null
                          ? const Center(
                              child: Text(
                                'Tap to select image',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(12),
                              child: Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(_path!),
                                    fit: BoxFit.contain,
                                    alignment: Alignment.center,
                                    errorBuilder: (_, error, stackTrace) {
                                      return const Center(
                                        child: Text(
                                          'Image selected',
                                          style: TextStyle(
                                            color: Color(0xFF1D4ED8),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _canSave
                          ? () async {
                              setState(() => _saving = true);
                              try {
                                final created = await widget.onUpload(
                                  _nameController.text.trim(),
                                  _path!,
                                );
                                if (!context.mounted) return;
                                Navigator.pop(context, created);
                              } catch (e) {
                                if (!mounted) return;
                                final message = e is ApiException
                                    ? e.message
                                    : 'Unable to upload signature.';
                                Navigator.of(
                                  this.context,
                                ).pop(_SignatureSheetError(message));
                              } finally {
                                if (mounted) setState(() => _saving = false);
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1677E6),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFA9C9EF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Upload Signature',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignatureSheetError {
  const _SignatureSheetError(this.message);
  final String message;
}
