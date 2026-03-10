part of '../newsales.dart';

class _NewSaleDetailsStep extends StatelessWidget {
  const _NewSaleDetailsStep({
    required this.title,
    required this.saleStatus,
    required this.customerNameController,
    required this.customerContactController,
    required this.customerNameInvalid,
    required this.customerContactInvalid,
    required this.country,
    required this.phoneError,
    required this.onPickCountry,
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
    required this.bankAccounts,
    required this.selectedBankAccountId,
    required this.onSelectSignature,
    required this.onSelectBankAccount,
    required this.onAddSignature,
    required this.onAddBankAccount,
    required this.onStatusChanged,
    required this.total,
    required this.hasItems,
    required this.formatAmount,
    required this.onContinue,
    required this.onClose,
  });

  final String title;
  final SaleStatus saleStatus;
  final TextEditingController customerNameController;
  final TextEditingController customerContactController;
  final bool customerNameInvalid;
  final bool customerContactInvalid;
  final Country? country;
  final String? phoneError;
  final VoidCallback onPickCountry;
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
  final List<ShopBankAccount> bankAccounts;
  final String? selectedBankAccountId;
  final ValueChanged<String> onSelectSignature;
  final ValueChanged<String> onSelectBankAccount;
  final Future<void> Function() onAddSignature;
  final Future<void> Function() onAddBankAccount;
  final ValueChanged<SaleStatus> onStatusChanged;
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
                      Text(
                        title,
                        style: const TextStyle(
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _DocumentTypePill(
                            label: 'Receipt',
                            active: saleStatus == SaleStatus.paid,
                            onTap: () => onStatusChanged(SaleStatus.paid),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DocumentTypePill(
                            label: 'Invoice',
                            active: saleStatus == SaleStatus.invoice,
                            onTap: () => onStatusChanged(SaleStatus.invoice),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
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
                  child: _InputBox(
                    controller: customerContactController,
                    hint: 'Enter Phone or Email',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    isInvalid: customerContactInvalid,
                    inputFormatters: [LengthLimitingTextInputFormatter(50)],
                    onChanged: onCustomerContactChanged,
                  ),
                ),
                if (phoneError != null) ...[
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
                const SizedBox(height: 24),
                if (saleStatus == SaleStatus.paid) ...[
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
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
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
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        const Text(
                          'SELECT BANK',
                          style: TextStyle(
                            color: Color(0xFF667085),
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: onAddBankAccount,
                          child: const Text(
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
                  if (bankAccounts.isNotEmpty)
                    SizedBox(
                      height: 126,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        scrollDirection: Axis.horizontal,
                        itemCount: bankAccounts.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final bankAccount = bankAccounts[index];
                          return _BankAccountCard(
                            bankAccount: bankAccount,
                            selected: bankAccount.id == selectedBankAccountId,
                            onTap: () => onSelectBankAccount(bankAccount.id),
                          );
                        },
                      ),
                    ),
                ],
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
    required this.previewLabel,
    required this.items,
    required this.drafts,
    required this.activeDraftId,
    required this.switchingDraft,
    required this.onCreateDraft,
    required this.onSwitchDraft,
    required this.onDeleteDraft,
    required this.saleSubtotal,
    required this.saleTotal,
    required this.discountAmount,
    required this.vatAmount,
    required this.serviceFeeAmount,
    required this.deliveryFeeAmount,
    required this.roundingAmount,
    required this.otherAmount,
    required this.otherLabel,
    required this.itemCount,
    required this.submitting,
    required this.onBack,
    required this.onAddItem,
    required this.onAddAdjustment,
    required this.onEditAdjustment,
    required this.onRemoveAdjustment,
    required this.onIncrement,
    required this.onDecrement,
    required this.onSetQuantity,
    required this.onDelete,
    required this.onEdit,
    required this.onSubmit,
    required this.formatAmount,
  });

  final String previewLabel;
  final List<_DraftSaleItem> items;
  final List<_DraftSlot> drafts;
  final String activeDraftId;
  final bool switchingDraft;
  final Future<void> Function() onCreateDraft;
  final Future<void> Function(String draftId) onSwitchDraft;
  final Future<void> Function(String draftId) onDeleteDraft;
  final double saleSubtotal;
  final double saleTotal;
  final double discountAmount;
  final double vatAmount;
  final double serviceFeeAmount;
  final double deliveryFeeAmount;
  final double roundingAmount;
  final double otherAmount;
  final String otherLabel;
  final int itemCount;
  final bool submitting;
  final VoidCallback onBack;
  final Future<void> Function() onAddItem;
  final Future<void> Function() onAddAdjustment;
  final Future<void> Function(_ChargeType type) onEditAdjustment;
  final Future<void> Function(_ChargeType type) onRemoveAdjustment;
  final ValueChanged<int> onIncrement;
  final ValueChanged<int> onDecrement;
  final void Function(int index, double value) onSetQuantity;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onEdit;
  final VoidCallback onSubmit;
  final String Function(num amount, {int decimalDigits}) formatAmount;

  @override
  Widget build(BuildContext context) {
    String signedAmount(double value) {
      if (value < 0) {
        return '-${formatAmount(value.abs(), decimalDigits: 2)}';
      }
      return '+${formatAmount(value, decimalDigits: 2)}';
    }

    final adjustments = <_AppliedAdjustment>[
      if (discountAmount != 0)
        _AppliedAdjustment(
          type: _ChargeType.discount,
          label: 'Discount',
          signedValue: signedAmount(-discountAmount),
        ),
      if (vatAmount != 0)
        _AppliedAdjustment(
          type: _ChargeType.vat,
          label: 'VAT',
          signedValue: signedAmount(vatAmount),
        ),
      if (serviceFeeAmount != 0)
        _AppliedAdjustment(
          type: _ChargeType.serviceFee,
          label: 'Service Fee',
          signedValue: signedAmount(serviceFeeAmount),
        ),
      if (deliveryFeeAmount != 0)
        _AppliedAdjustment(
          type: _ChargeType.delivery,
          label: 'Delivery',
          signedValue: signedAmount(deliveryFeeAmount),
        ),
      if (roundingAmount != 0)
        _AppliedAdjustment(
          type: _ChargeType.rounding,
          label: 'Rounding',
          signedValue: signedAmount(roundingAmount),
        ),
      if (otherAmount != 0)
        _AppliedAdjustment(
          type: _ChargeType.other,
          label: otherLabel.trim().isEmpty ? 'Others' : otherLabel,
          signedValue: signedAmount(otherAmount),
        ),
    ];

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
                'PRICING',
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
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: () => unawaited(onAddAdjustment()),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          'Add Adjustment',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1677E6),
                          side: const BorderSide(color: Color(0xFF9DBDE6)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$itemCount ITEMS',
                      style: const TextStyle(
                        color: Color(0xFF275A9E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (adjustments.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDCE6F2)),
                  ),
                  child: Column(
                    children: adjustments
                        .map(
                          (entry) => _AdjustmentTile(
                            label: entry.label,
                            value: entry.signedValue,
                            onEdit: () =>
                                unawaited(onEditAdjustment(entry.type)),
                            onRemove: () =>
                                unawaited(onRemoveAdjustment(entry.type)),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _PricingLine(
                label: 'Subtotal',
                value: formatAmount(saleSubtotal, decimalDigits: 2),
                strong: false,
              ),
              if (discountAmount != 0) ...[
                const SizedBox(height: 6),
                _PricingLine(
                  label: 'Discount',
                  value: signedAmount(-discountAmount),
                  strong: false,
                ),
              ],
              if (vatAmount != 0) ...[
                const SizedBox(height: 6),
                _PricingLine(
                  label: 'VAT',
                  value: signedAmount(vatAmount),
                  strong: false,
                ),
              ],
              if (serviceFeeAmount != 0) ...[
                const SizedBox(height: 6),
                _PricingLine(
                  label: 'Service Fee',
                  value: signedAmount(serviceFeeAmount),
                  strong: false,
                ),
              ],
              if (deliveryFeeAmount != 0) ...[
                const SizedBox(height: 6),
                _PricingLine(
                  label: 'Delivery',
                  value: signedAmount(deliveryFeeAmount),
                  strong: false,
                ),
              ],
              if (roundingAmount != 0) ...[
                const SizedBox(height: 6),
                _PricingLine(
                  label: 'Rounding',
                  value: signedAmount(roundingAmount),
                  strong: false,
                ),
              ],
              if (otherAmount != 0) ...[
                const SizedBox(height: 6),
                _PricingLine(
                  label: otherLabel.trim().isEmpty ? 'Others' : otherLabel,
                  value: signedAmount(otherAmount),
                  strong: false,
                ),
              ],
              const SizedBox(height: 8),
              _PricingLine(
                label: 'Grand Total',
                value: formatAmount(saleTotal, decimalDigits: 2),
                strong: true,
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
                      : Text(
                          previewLabel,
                          style: const TextStyle(
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

class _DocumentTypePill extends StatelessWidget {
  const _DocumentTypePill({
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
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 46,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AppliedAdjustment {
  const _AppliedAdjustment({
    required this.type,
    required this.label,
    required this.signedValue,
  });

  final _ChargeType type;
  final String label;
  final String signedValue;
}

class _AdjustmentTile extends StatelessWidget {
  const _AdjustmentTile({
    required this.label,
    required this.value,
    required this.onEdit,
    required this.onRemove,
  });

  final String label;
  final String value;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF324967),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0E1930),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_rounded,
              size: 18,
              color: Color(0xFF1677E6),
            ),
            splashRadius: 18,
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Color(0xFF8A99AE),
            ),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _PricingLine extends StatelessWidget {
  const _PricingLine({
    required this.label,
    required this.value,
    required this.strong,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: strong ? const Color(0xFF0E1930) : const Color(0xFF60708A),
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              fontSize: strong ? 16 : 14,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: strong ? const Color(0xFF1677E6) : const Color(0xFF0E1930),
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            fontSize: strong ? 19 : 14,
          ),
        ),
      ],
    );
  }
}
