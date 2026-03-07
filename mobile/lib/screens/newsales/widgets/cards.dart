part of '../newsales.dart';

class _SignatureCard extends StatelessWidget {
  const _SignatureCard({
    required this.signature,
    required this.selected,
    required this.onTap,
  });

  final SignatureItem signature;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 118,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF1677E6) : const Color(0xFFD4DEE9),
            width: selected ? 2.3 : 1.3,
          ),
          color: selected ? const Color(0xFFEFF5FD) : Colors.white,
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image(
                        image: MediaService.imageProvider(signature.imageUrl)!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) => Container(
                          color: const Color(0xFFF2F6FB),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Color(0xFF9AA8BD),
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    const Positioned(
                      right: 8,
                      top: 8,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: Color(0xFF1677E6),
                        child: Icon(Icons.check, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              signature.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF60708A),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.formatAmount,
    required this.onMinus,
    required this.onPlus,
    required this.onSetQuantity,
    required this.onDelete,
    required this.onTap,
  });

  final _DraftSaleItem item;
  final String Function(num amount, {int decimalDigits}) formatAmount;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<double> onSetQuantity;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD8E2EE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.productName,
                      style: const TextStyle(
                        color: Color(0xFF0E1930),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFE53935),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Unit: ${formatAmount(item.unitPrice, decimalDigits: 2)}',
                style: const TextStyle(
                  color: Color(0xFF60708A),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _QuantityStepper(
                    quantity: item.quantity,
                    onMinus: onMinus,
                    onPlus: onPlus,
                    onSetQuantity: onSetQuantity,
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          color: Color(0xFF60708A),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatAmount(item.lineTotal, decimalDigits: 2),
                        style: const TextStyle(
                          color: Color(0xFF1677E6),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatefulWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  Timer? _holdDelay;
  Timer? _repeatTimer;
  bool _startedRepeat = false;

  void _startHold() {
    _startedRepeat = false;
    _holdDelay?.cancel();
    _repeatTimer?.cancel();
    _holdDelay = Timer(const Duration(milliseconds: 320), () {
      _startedRepeat = true;
      widget.onTap();
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
        widget.onTap();
      });
    });
  }

  void _endHold() {
    final shouldSingleTap = !_startedRepeat;
    _holdDelay?.cancel();
    _repeatTimer?.cancel();
    if (shouldSingleTap) {
      widget.onTap();
    }
  }

  @override
  void dispose() {
    _holdDelay?.cancel();
    _repeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _endHold(),
      onTapCancel: _endHold,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(widget.icon, color: const Color(0xFF4C5E78), size: 17),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
    required this.onSetQuantity,
  });

  final double quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<double> onSetQuantity;

  @override
  Widget build(BuildContext context) {
    return _QuantityStepperField(
      quantity: quantity,
      onMinus: onMinus,
      onPlus: onPlus,
      onSetQuantity: onSetQuantity,
    );
  }
}

class _QuantityStepperField extends StatefulWidget {
  const _QuantityStepperField({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
    required this.onSetQuantity,
  });

  final double quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<double> onSetQuantity;

  @override
  State<_QuantityStepperField> createState() => _QuantityStepperFieldState();
}

class _QuantityStepperFieldState extends State<_QuantityStepperField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatQuantity(widget.quantity),
    );
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _QuantityStepperField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus &&
        oldWidget.quantity != widget.quantity &&
        _controller.text != _formatQuantity(widget.quantity)) {
      _controller.text = _formatQuantity(widget.quantity);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatQuantity(double value) {
    return value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  void _syncTypedQuantity({bool finalize = false}) {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null || parsed < 1) {
      if (finalize) {
        _controller.text = _formatQuantity(widget.quantity);
      }
      return;
    }

    final clamped = parsed.clamp(1, 9999).toDouble();
    if ((widget.quantity - clamped).abs() > 0.000001) {
      widget.onSetQuantity(clamped);
    }

    if (finalize) {
      _controller.text = _formatQuantity(clamped);
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _StepButton(icon: Icons.remove, onTap: widget.onMinus),
          Expanded(
            child: Center(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(
                  color: Color(0xFF0E1930),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => _syncTypedQuantity(),
                onSubmitted: (_) => _syncTypedQuantity(finalize: true),
                onEditingComplete: () => _syncTypedQuantity(finalize: true),
              ),
            ),
          ),
          _StepButton(icon: Icons.add, onTap: widget.onPlus),
        ],
      ),
    );
  }
}
