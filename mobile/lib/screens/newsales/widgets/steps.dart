part of '../newsales.dart';

class _NewSaleDetailsStep extends StatelessWidget {
  const _NewSaleDetailsStep({
    required this.customerNameController,
    required this.customerContactController,
    required this.customerNameInvalid,
    required this.customerContactInvalid,
    required this.useEmailForContact,
    required this.country,
    required this.phoneError,
    required this.onPickCountry,
    required this.onToggleContactType,
    required this.onCustomerNameChanged,
    required this.onCustomerContactChanged,
    required this.drafts,
    required this.activeDraftId,
    required this.switchingDraft,
    required this.onCreateDraft,
    required this.onSwitchDraft,
    required this.onDeleteDraft,
    required this.signatures,
    required this.loadingSignatures,
    required this.uploadingSignature,
    required this.selectedSignatureId,
    required this.onSelectSignature,
    required this.onAddSignature,
    required this.total,
    required this.hasItems,
    required this.formatAmount,
    required this.onContinue,
    required this.onClose,
  });

  final TextEditingController customerNameController;
  final TextEditingController customerContactController;
  final bool customerNameInvalid;
  final bool customerContactInvalid;
  final bool useEmailForContact;
  final Country? country;
  final String? phoneError;
  final VoidCallback onPickCountry;
  final VoidCallback onToggleContactType;
  final ValueChanged<String> onCustomerNameChanged;
  final ValueChanged<String> onCustomerContactChanged;
  final List<_DraftSlot> drafts;
  final String activeDraftId;
  final bool switchingDraft;
  final Future<void> Function() onCreateDraft;
  final Future<void> Function(String draftId) onSwitchDraft;
  final Future<void> Function(String draftId) onDeleteDraft;
  final List<SignatureItem> signatures;
  final bool loadingSignatures;
  final bool uploadingSignature;
  final String? selectedSignatureId;
  final ValueChanged<String> onSelectSignature;
  final Future<void> Function() onAddSignature;
  final double total;
  final bool hasItems;
  final String Function(num amount, {int decimalDigits}) formatAmount;
  final VoidCallback onContinue;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Text(
                        'New Sale',
                        style: TextStyle(
                          color: Color(0xFF0E1930),
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close, color: Color(0xFF667085)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: _StepProgress(activeStep: 0),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _DraftSwitcher(
                    drafts: drafts,
                    activeDraftId: activeDraftId,
                    loading: switchingDraft,
                    onCreateDraft: onCreateDraft,
                    onSwitchDraft: onSwitchDraft,
                    onDeleteDraft: onDeleteDraft,
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'CUSTOMER DETAILS',
                    style: TextStyle(
                      color: Color(0xFF667085),
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _InputBox(
                    controller: customerNameController,
                    hint: 'Customer Name',
                    textInputAction: TextInputAction.next,
                    isInvalid: customerNameInvalid,
                    inputFormatters: [LengthLimitingTextInputFormatter(40)],
                    onChanged: onCustomerNameChanged,
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: useEmailForContact
                      ? _InputBox(
                          controller: customerContactController,
                          hint: 'Customer Email',
                          textInputAction: TextInputAction.done,
                          keyboardType: TextInputType.emailAddress,
                          isInvalid: customerContactInvalid,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(50),
                          ],
                          onChanged: onCustomerContactChanged,
                        )
                      : Row(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: onPickCountry,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: customerContactInvalid
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFFD6DFEB),
                                    width: customerContactInvalid ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      country?.flagEmoji ?? '🇳🇬',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '+${country?.phoneCode ?? '234'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _InputBox(
                                controller: customerContactController,
                                hint: '8104156984',
                                textInputAction: TextInputAction.done,
                                keyboardType: TextInputType.phone,
                                isInvalid: customerContactInvalid,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: onCustomerContactChanged,
                              ),
                            ),
                          ],
                        ),
                ),
                if (!useEmailForContact && phoneError != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      phoneError!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onToggleContactType,
                      child: Text(
                        useEmailForContact
                            ? 'Use phone instead'
                            : 'Use email instead',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Text(
                        'SELECT SIGNATURE',
                        style: TextStyle(
                          color: Color(0xFF667085),
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: uploadingSignature ? null : onAddSignature,
                        child: uploadingSignature
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                '+ NEW',
                                style: TextStyle(
                                  color: Color(0xFF1677E6),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 122,
                  child: loadingSignatures
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          scrollDirection: Axis.horizontal,
                          itemCount: signatures.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final signature = signatures[index];
                            final selected =
                                signature.id == selectedSignatureId;
                            return _SignatureCard(
                              signature: signature,
                              selected: selected,
                              onTap: () => onSelectSignature(signature.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        _BottomActionBar(
          label: hasItems ? 'View Items' : 'Add Items',
          amountLabel: 'TOTAL AMOUNT',
          amount: total,
          formatAmount: formatAmount,
          onTap: onContinue,
          trailingIcon: Icons.arrow_forward_ios_rounded,
        ),
      ],
    );
  }
}

class _NewSaleItemsStep extends StatelessWidget {
  const _NewSaleItemsStep({
    required this.items,
    required this.drafts,
    required this.activeDraftId,
    required this.switchingDraft,
    required this.onCreateDraft,
    required this.onSwitchDraft,
    required this.onDeleteDraft,
    required this.saleTotal,
    required this.itemCount,
    required this.submitting,
    required this.onBack,
    required this.onAddItem,
    required this.onIncrement,
    required this.onDecrement,
    required this.onSetQuantity,
    required this.onDelete,
    required this.onEdit,
    required this.onSubmit,
    required this.formatAmount,
  });

  final List<_DraftSaleItem> items;
  final List<_DraftSlot> drafts;
  final String activeDraftId;
  final bool switchingDraft;
  final Future<void> Function() onCreateDraft;
  final Future<void> Function(String draftId) onSwitchDraft;
  final Future<void> Function(String draftId) onDeleteDraft;
  final double saleTotal;
  final int itemCount;
  final bool submitting;
  final VoidCallback onBack;
  final Future<void> Function() onAddItem;
  final ValueChanged<int> onIncrement;
  final ValueChanged<int> onDecrement;
  final void Function(int index, double value) onSetQuantity;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onEdit;
  final VoidCallback onSubmit;
  final String Function(num amount, {int decimalDigits}) formatAmount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF1677E6),
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Add Items',
                style: TextStyle(
                  color: Color(0xFF0E1930),
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: _StepProgress(activeStep: 1),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _DraftSwitcher(
            drafts: drafts,
            activeDraftId: activeDraftId,
            loading: switchingDraft,
            onCreateDraft: onCreateDraft,
            onSwitchDraft: onSwitchDraft,
            onDeleteDraft: onDeleteDraft,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                GestureDetector(
                  onTap: onAddItem,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFC8D5E6),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: const [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(0xFFE9EFF7),
                          child: Icon(
                            Icons.add,
                            color: Color(0xFF1677E6),
                            size: 30,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Add Another Item',
                          style: TextStyle(
                            color: Color(0xFF5D6D87),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ...List.generate(items.length, (displayIndex) {
                  final index = items.length - 1 - displayIndex;
                  final item = items[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: displayIndex == items.length - 1 ? 14 : 12,
                    ),
                    child: _ItemCard(
                      item: item,
                      formatAmount: formatAmount,
                      onMinus: () => onDecrement(index),
                      onPlus: () => onIncrement(index),
                      onSetQuantity: (value) => onSetQuantity(index, value),
                      onDelete: () => onDelete(index),
                      onTap: () => onEdit(index),
                    ),
                  );
                }),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SALE TOTAL',
                style: TextStyle(
                  color: Color(0xFF6B7A92),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatAmount(saleTotal, decimalDigits: 2),
                      style: const TextStyle(
                        color: Color(0xFF0E1930),
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDF7E7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$itemCount ITEMS',
                      style: const TextStyle(
                        color: Color(0xFF118044),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: submitting ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1677E6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 6,
                    shadowColor: const Color(0x331677E6),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Preview Sales  →',
                          style: TextStyle(
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
    );
  }
}
