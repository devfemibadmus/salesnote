import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models.dart';
import '../services/api_client.dart';
import '../services/validators.dart';

class AddSignatureSheetResult {
  const AddSignatureSheetResult._({this.signature, this.errorMessage});

  factory AddSignatureSheetResult.success(SignatureItem signature) =>
      AddSignatureSheetResult._(signature: signature);

  factory AddSignatureSheetResult.failure(String message) =>
      AddSignatureSheetResult._(errorMessage: message);

  final SignatureItem? signature;
  final String? errorMessage;
}

Future<AddSignatureSheetResult?> showAddSignatureSheet({
  required BuildContext context,
  required Future<SignatureItem> Function(String name, String imagePath) onUpload,
}) async {
  final output = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    barrierColor: const Color(0x8A000000),
    backgroundColor: Colors.transparent,
    builder: (context) => _AddSignatureSheet(onUpload: onUpload),
  );

  if (output == null) {
    return null;
  }
  if (output is _AddSignatureSheetError) {
    return AddSignatureSheetResult.failure(output.message);
  }
  if (output is SignatureItem) {
    return AddSignatureSheetResult.success(output);
  }
  return null;
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
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving &&
      _path != null &&
      Validators.isValidSignatureName(_nameController.text.trim());

  void _validateName() {
    final text = _nameController.text.trim();
    setState(() {
      if (text.isEmpty) {
        _nameError = 'Name is required.';
      } else if (!Validators.isValidSignatureName(text)) {
        _nameError = 'Use letters only, max 10 letters.';
      } else {
        _nameError = null;
      }
    });
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
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    enabled: !_saving,
                    onChanged: (_) => _validateName(),
                    decoration: InputDecoration(
                      hintText: 'Signature name',
                      errorText: _nameError,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF1677E6)),
                      ),
                    ),
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
                            if (file == null || !mounted) return;
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
                              _validateName();
                              if (!_canSave || _path == null) return;
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
                                  context,
                                ).pop(_AddSignatureSheetError(message));
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

class _AddSignatureSheetError {
  const _AddSignatureSheetError(this.message);
  final String message;
}
