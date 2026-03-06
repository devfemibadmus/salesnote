part of '../newsales.dart';

class _InputBox extends StatelessWidget {
  const _InputBox({
    required this.controller,
    required this.hint,
    this.textInputAction,
    this.keyboardType,
    this.focusNode,
    this.inputFormatters,
    this.isInvalid = false,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.compact = false,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;
  final bool isInvalid;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final bool compact;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 62 : 74,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isInvalid ? const Color(0xFFEF4444) : const Color(0xFFD6DFEB),
          width: isInvalid ? 1.5 : 1,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
      alignment: Alignment.center,
      child: Row(
        children: [
          if (prefix != null) ...[prefix!],
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: textAlign,
              textInputAction: textInputAction,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              onChanged: onChanged,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFF97A6BD),
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
              ),
              style: const TextStyle(
                color: Color(0xFF101828),
                fontSize: 18,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          if (suffix != null) ...[suffix!],
        ],
      ),
    );
  }
}

class _ThousandsSeparatedNumberFormatter extends TextInputFormatter {
  const _ThousandsSeparatedNumberFormatter({this.allowNegative = false});

  final bool allowNegative;

  static String normalize(String input) {
    return input.replaceAll(',', '').trim();
  }

  static double parse(String input) {
    return double.tryParse(normalize(input)) ?? 0;
  }

  static String formatForDisplay(String input, {bool allowNegative = false}) {
    return _formatSanitized(input, allowNegative: allowNegative);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = _formatSanitized(
      newValue.text,
      allowNegative: allowNegative,
    );

    final selectionFromEnd = newValue.text.length - newValue.selection.end;
    final nextOffset = (formatted.length - selectionFromEnd).clamp(
      0,
      formatted.length,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: nextOffset),
      composing: TextRange.empty,
    );
  }

  static String _formatSanitized(String input, {required bool allowNegative}) {
    if (input.isEmpty) {
      return '';
    }

    final source = input.replaceAll(',', '').replaceAll(' ', '');
    if (source.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    var hasDot = false;
    var hasSign = false;

    for (var i = 0; i < source.length; i++) {
      final ch = source[i];
      final code = ch.codeUnitAt(0);
      final isDigit = code >= 48 && code <= 57;

      if (isDigit) {
        buffer.write(ch);
        continue;
      }
      if (ch == '.' && !hasDot) {
        hasDot = true;
        buffer.write(ch);
        continue;
      }
      if (ch == '-' && allowNegative && !hasSign && buffer.isEmpty) {
        hasSign = true;
        buffer.write(ch);
      }
    }

    var raw = buffer.toString();
    if (raw.isEmpty) {
      return '';
    }
    if (raw == '-' && allowNegative) {
      return raw;
    }
    if (raw == '.') {
      return '0.';
    }
    if (raw == '-.') {
      return '-0.';
    }

    final negative = raw.startsWith('-');
    if (negative) {
      raw = raw.substring(1);
    }

    final hasDecimal = raw.contains('.');
    final split = raw.split('.');
    var intPart = split.first;
    final decimalPart = split.length > 1 ? split.sublist(1).join() : '';

    if (intPart.isEmpty) {
      intPart = '0';
    }
    intPart = intPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    final formattedInt = intPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );

    final sign = negative ? '-' : '';
    if (!hasDecimal) {
      return '$sign$formattedInt';
    }
    return '$sign$formattedInt.$decimalPart';
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        final active = index <= activeStep;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF1677E6)
                    : const Color(0xFFD8E0EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.label,
    required this.amountLabel,
    required this.amount,
    required this.formatAmount,
    required this.onTap,
    this.trailingIcon,
  });

  final String label;
  final String amountLabel;
  final double amount;
  final String Function(num amount, {int decimalDigits}) formatAmount;
  final VoidCallback onTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amountLabel,
                  style: const TextStyle(
                    color: Color(0xFF8B9CB3),
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  formatAmount(amount, decimalDigits: 2),
                  style: const TextStyle(
                    color: Color(0xFF0E1930),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 0.95,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 151,
            height: 51,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1677E6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 7,
                shadowColor: const Color(0x331677E6),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 6),
                      Icon(trailingIcon, size: 16),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
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
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEAF3FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? const Color(0xFFB9D3F6) : const Color(0xFFD7E0EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF1677E6) : const Color(0xFF475569),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _DraftSwitcher extends StatelessWidget {
  const _DraftSwitcher({
    required this.drafts,
    required this.activeDraftId,
    required this.loading,
    required this.onCreateDraft,
    required this.onSwitchDraft,
    required this.onDeleteDraft,
  });

  final List<_DraftSlot> drafts;
  final String activeDraftId;
  final bool loading;
  final Future<void> Function() onCreateDraft;
  final Future<void> Function(String draftId) onSwitchDraft;
  final Future<void> Function(String draftId) onDeleteDraft;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: drafts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final draft = drafts[index];
                final selected = draft.id == activeDraftId;
                return InkWell(
                  onTap: loading ? null : () => onSwitchDraft(draft.id),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFEAF3FF) : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF1677E6)
                            : const Color(0xFFD4DEE9),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          draft.label,
                          style: TextStyle(
                            color: selected
                                ? const Color(0xFF1677E6)
                                : const Color(0xFF60708A),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: loading ? null : () => onDeleteDraft(draft.id),
                          child: const Icon(
                            Icons.close,
                            size: 15,
                            color: Color(0xFF95A6BE),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: loading ? null : onCreateDraft,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD4DEE9)),
            ),
            child: loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add, size: 18, color: Color(0xFF1677E6)),
          ),
        ),
      ],
    );
  }
}
