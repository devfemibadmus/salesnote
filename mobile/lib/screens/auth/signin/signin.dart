import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/api_client.dart';
import '../../../services/device_info.dart';
import '../../../services/token_store.dart';
import 'package:country_picker/country_picker.dart';

import '../../../services/phone.dart';
import '../../../services/region.dart';
import '../../../services/validators.dart';
import '../signup/signup.dart';
import '../verify/forgot_password.dart';

class Signin extends StatefulWidget {
  const Signin({super.key});

  @override
  State<Signin> createState() => _SigninState();
}

class _SigninState extends State<Signin> {
  static const _primary = Color(0xFF007AFF);
  static const _textMuted = Color(0xFF64748B);

  final _api = ApiClient(TokenStore());
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _showPassword = false;
  bool _useEmail = false;
  Country? _country;
  late final String _deviceRegionCode;
  String? _phoneError;
  Timer? _phoneDebounce;

  @override
  void dispose() {
    _phoneDebounce?.cancel();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
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


  Future<void> _login() async {
    String loginValue;
    if (_useEmail) {
      final input = _email.text.trim();
      if (!Validators.isValidEmail(input)) {
        _showError('Enter a valid email.');
        return;
      }
      loginValue = input;
    } else {
      final input = _phone.text.trim();
      final region = _country?.countryCode ?? _deviceRegionCode;
      final phoneCode = _country?.phoneCode;
      final strictPhone = await PhoneService.normalizeE164(
        input,
        region,
        countryPhoneCode: phoneCode,
      );
      if (strictPhone == null) {
        _showError('Enter a valid phone number.');
        return;
      }
      loginValue = strictPhone;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    try {
      final device = await DeviceInfoService.getDeviceInfo()
          .timeout(const Duration(seconds: 2), onTimeout: () => DeviceInfoData());
      await _api.login(
        loginValue,
        _password.text.trim(),
        deviceName: device.name,
        devicePlatform: device.platform,
        deviceOs: device.os,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
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
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              children: [
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Salesnote',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                ),
              ),
              const SizedBox(height: 48),
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
                  decoration: InputDecoration(
                    hintText: 'name@email.com',
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
                  ),
                )
              else
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _loading
                          ? null
                          : () {
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
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        enabled: !_loading,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: _onPhoneChanged,
                        decoration: InputDecoration(
                          hintText: '8104156984',
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
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() => _useEmail = !_useEmail);
                        },
                  child: Text(
                    _useEmail ? 'Use phone instead' : 'Use email instead',
                    style: const TextStyle(
                      color: _textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Password',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _password,
                obscureText: !_showPassword,
                enabled: !_loading,
                decoration: InputDecoration(
                  hintText: '• • • • • • • •',
                  hintStyle: const TextStyle(color: Color(0xFFCBD5F5)),
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
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ForgotPassword(),
                            ),
                          );
                        },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: _textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                  onPressed: _loading ? null : _login,
                  child: Text(
                    _loading ? 'Please wait...' : 'Sign In',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have a shop? ",
                    style: TextStyle(color: _textMuted),
                  ),
                  GestureDetector(
                    onTap: _loading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const Signup()),
                            );
                          },
                    child: const Text(
                      'Create a shop',
                      style: TextStyle(
                        color: _textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
