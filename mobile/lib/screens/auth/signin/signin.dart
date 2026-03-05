import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../services/cache/local.dart';
import '../../../services/device_info.dart';
import '../../../services/token_store.dart';

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
  final _loginId = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _showPassword = false;
  late final String _deviceRegionCode;

  @override
  void dispose() {
    _loginId.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _deviceRegionCode = RegionService.getDeviceRegionCode();
  }


  Future<void> _login() async {
    final input = _loginId.text.trim();
    if (input.isEmpty) {
      _showError('Enter your phone or email.');
      return;
    }

    String loginValue;
    final isEmail = input.contains('@') || RegExp(r'[a-zA-Z]').hasMatch(input);

    if (isEmail) {
      if (!Validators.isValidEmail(input)) {
        _showError('Enter a valid email.');
        return;
      }
      loginValue = input;
    } else {
      final strictPhone = await PhoneService.normalizeE164(
        input,
        _deviceRegionCode,
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
      final auth = await _api.login(
        loginValue,
        _password.text.trim(),
        deviceName: device.name,
        devicePlatform: device.platform,
        deviceOs: device.os,
      );
      final selectedRegion = !isEmail
          ? _deviceRegionCode
          : await PhoneService.regionCodeFromE164(auth.shop.phone);
      await LocalCache.setPreferredRegionCode(selectedRegion);
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
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF007AFF), Color(0xFF0055CC)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33007AFF),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Sales Note',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0E1930),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Phone or Email',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _loginId,
                keyboardType: TextInputType.emailAddress,
                enabled: !_loading,
                decoration: InputDecoration(
                  hintText: 'Enter phone or email',
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
              const SizedBox(height: 16),
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
