import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';

import '../../../services/api_client.dart';
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
  final _email = TextEditingController();
  Country? _country;
  late final String _deviceRegionCode;
  bool _useEmail = true;
  String? _errorText;
  String? _phoneError;
  Timer? _phoneDebounce;
  final _api = ApiClient(TokenStore());
  bool _loading = false;

  @override
  void dispose() {
    _phoneDebounce?.cancel();
    _phoneOrEmail.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _deviceRegionCode = RegionService.getDeviceRegionCode();
    _initCountry();
  }

  void _initCountry() {
    try {
      _country = CountryParser.parseCountryCode(_deviceRegionCode);
    } catch (_) {
      _country = CountryParser.parseCountryCode('NG');
    }
  }

  void _onPhoneChanged(String value) {
    _phoneDebounce?.cancel();
    _phoneDebounce = Timer(const Duration(milliseconds: 300), () async {
      final input = value.trim();
      if (input.isEmpty) {
        if (mounted) setState(() => _phoneError = null);
        return;
      }
      final region = _country?.countryCode ?? _deviceRegionCode;
      final valid = await PhoneService.isValid(
        input,
        region,
        countryPhoneCode: _country?.phoneCode,
      );
      if (!mounted) return;
      setState(() {
        _phoneError = valid ? null : 'Enter a valid phone number.';
      });
      if (valid) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }


  Future<void> _next() async {
    if (!_useEmail) {
      setState(() => _errorText = 'Enter your email to receive a reset code.');
      _showError('Enter your email to receive a reset code.');
      return;
    }

    final input = _email.text.trim();
    if (!Validators.isValidEmail(input)) {
      setState(() => _errorText = 'Enter a valid email.');
      _showError('Enter a valid email.');
      return;
    }
    setState(() => _errorText = null);

    try {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _loading = true);
      await _api.forgotPassword(input);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const VerifyCode()),
      );
    } catch (e) {
      _showError(_errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
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
                'Enter your phone or email to receive a reset code.',
                style: TextStyle(fontSize: 18, color: _textMuted, height: 1.4),
              ),
              const SizedBox(height: 28),
              const Text(
                'Phone or Email',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 8),
              if (_useEmail)
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_loading,
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'name@email.com',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                )
              else
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        showCountryPicker(
                          context: context,
                          showPhoneCode: true,
                          onSelect: (value) async {
                            setState(() => _country = value);
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _country?.flagEmoji ?? '🇳🇬',
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '+${_country?.phoneCode ?? '234'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.keyboard_arrow_down, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _phoneOrEmail,
                        keyboardType: TextInputType.phone,
                        enabled: !_loading,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) {
                          if (_errorText != null) {
                            setState(() => _errorText = null);
                          }
                          _onPhoneChanged(_phoneOrEmail.text);
                        },
                        decoration: InputDecoration(
                          hintText: '8104156984',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (!_useEmail && _phoneError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _phoneError!,
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() {
                    _useEmail = !_useEmail;
                    _errorText = null;
                  }),
                  child: Text(
                    _useEmail ? 'Use phone instead' : 'Use email instead',
                    style: const TextStyle(
                      color: _textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
