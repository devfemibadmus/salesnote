import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';

Future<ShopBankAccount?> showBankAccountDialog({
  required BuildContext context,
  required ShopBankAccount initial,
  required bool isNew,
}) async {
  final bankNameController = TextEditingController(text: initial.bankName);
  final accountNumberController = TextEditingController(
    text: initial.accountNumber,
  );
  final accountNameController = TextEditingController(text: initial.accountName);

  String? bankNameError;
  String? accountNumberError;
  String? accountNameError;

  bool validate(void Function(void Function()) setLocalState) {
    final bankName = bankNameController.text.trim();
    final accountNumber = accountNumberController.text.trim();
    final accountName = accountNameController.text.trim();

    setLocalState(() {
      bankNameError = bankName.isEmpty ? 'Bank name is required.' : null;
      accountNumberError = accountNumber.isEmpty
          ? 'Account number is required.'
          : null;
      accountNameError = accountName.isEmpty
          ? 'Account name is required.'
          : null;
    });

    return bankNameError == null &&
        accountNumberError == null &&
        accountNameError == null;
  }

  return showDialog<ShopBankAccount>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (dialogContext, setLocalState) => AlertDialog(
        backgroundColor: const Color(0xFFF3F4F6),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(isNew ? 'Add Bank Account' : 'Edit Bank Account'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bankNameController,
                decoration: InputDecoration(
                  hintText: 'Bank name',
                  errorText: bankNameError,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) {
                  if (bankNameError == null) return;
                  setLocalState(() {
                    bankNameError = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: InputDecoration(
                  hintText: 'Account number',
                  errorText: accountNumberError,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) {
                  if (accountNumberError == null) return;
                  setLocalState(() {
                    accountNumberError = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountNameController,
                decoration: InputDecoration(
                  hintText: 'Account name',
                  errorText: accountNameError,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) {
                  if (accountNameError == null) return;
                  setLocalState(() {
                    accountNameError = null;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!validate(setLocalState)) return;
              Navigator.pop(
                dialogContext,
                ShopBankAccount(
                  id: initial.id,
                  bankName: bankNameController.text.trim(),
                  accountNumber: accountNumberController.text.trim(),
                  accountName: accountNameController.text.trim(),
                ),
              );
            },
            child: Text(isNew ? 'Add' : 'Save'),
          ),
        ],
      ),
    ),
  );
}
