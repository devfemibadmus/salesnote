import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/api_client.dart';
import '../../../services/notice.dart';
import '../../../services/phone.dart';
import '../../../services/region.dart';
import '../../../services/token_store.dart';
import '../../../services/validators.dart';
import 'verify_code.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  static const _primary = Color(0xFF007AFF);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);

  final _phoneOrEmail = TextEditingController();
  late final String _deviceRegionCode;
  String? _errorText;
  final _api = ApiClient(TokenStore());
  bool _loading = false;

  @override
  void dispose() {
    _phoneOrEmail.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _deviceRegionCode = RegionService.getDeviceRegionCode();
  }

  Future<void> _next() async {
    final input = _phoneOrEmail.text.trim();
    if (input.isEmpty) {
      setState(() => _errorText = 'Enter your phone or email.');
      _showError('Enter your phone or email.');
      return;
    }

    String phoneOrEmailValue;
    final isEmail = input.contains('@') || RegExp(r'[a-zA-Z]').hasMatch(input);

    if (isEmail) {
      if (!Validators.isValidEmail(input)) {
        setState(() => _errorText = 'Enter a valid email.');
        _showError('Enter a valid email.');
        return;
      }
      phoneOrEmailValue = input.toLowerCase();
    } else {
      final normalized = await PhoneService.normalizeE164(
        input,
        _deviceRegionCode,
      );
      if (normalized == null) {
        setState(() => _errorText = 'Enter a valid phone number.');
        _showError('Enter a valid phone number.');
        return;
      }
      phoneOrEmailValue = normalized;
    }
    setState(() => _errorText = null);

    try {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _loading = true);
      await _api.forgotPassword(phoneOrEmailValue);
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(
        MaterialPageRoute(
          builder: (_) => VerifyCode(phoneOrEmail: phoneOrEmailValue),
        ),
      );
    } catch (e) {
      _showError(_errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    AppNotice.show(context, message);
  }

  String _errorMessage(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: AbsorbPointer(
            absorbing: _loading,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              children: [
                IconButton(
                  alignment: Alignment.centerLeft,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Forgot Password',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your code may be sent to your email or whatsapp or phone',
                  style: TextStyle(
                    fontSize: 18,
                    color: _textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _phoneOrEmail,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_loading,
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter Phone or Email',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    errorText: _errorText,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _loading ? null : _next,
                    child: Text(
                      _loading ? 'Please wait...' : 'Send reset code',
                      style: const TextStyle(
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
    );
  }
}
