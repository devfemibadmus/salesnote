import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../services/cache/local.dart';
import '../../../services/device_info.dart';
import '../../../services/notice.dart';
import '../../../services/phone.dart';
import '../../../services/region.dart';
import '../../../services/token_store.dart';
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
  static const _textDark = Color(0xFF0F172A);
  static const _surface = Colors.white;

  final _api = ApiClient(TokenStore());
  final _loginId = TextEditingController();
  final _password = TextEditingController();
  final _pageController = PageController();
  final _passwordFocusNode = FocusNode();
  late final PageController _countrySelectorController;
  late final List<Country> _countries;

  bool _loading = false;
  bool _showPassword = false;
  Country? _country;
  late final String _deviceRegionCode;

  @override
  void initState() {
    super.initState();
    _countries = CountryService().getAll();
    _deviceRegionCode = RegionService.getDeviceRegionCode();
    try {
      _country = CountryParser.parseCountryCode(_deviceRegionCode);
    } catch (_) {
      _country = CountryParser.parseCountryCode('NG');
    }
    final initialIndex = _countries.indexWhere(
      (country) => country.countryCode == _country?.countryCode,
    );
    _countrySelectorController = PageController(
      initialPage: initialIndex >= 0 ? initialIndex : 0,
      viewportFraction: 0.62,
    );
    _passwordFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _loginId.dispose();
    _password.dispose();
    _pageController.dispose();
    _countrySelectorController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int index) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_pageController.hasClients) {
      return;
    }
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _login() async {
    final input = _loginId.text.trim();
    if (input.isEmpty) {
      _showError('Enter your phone or email.');
      return;
    }

    if (_password.text.trim().isEmpty) {
      _showError('Enter your password.');
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
      final selectedCountry = _country;
      final strictPhone = await PhoneService.normalizeE164(
        input,
        selectedCountry?.countryCode ?? _deviceRegionCode,
        countryPhoneCode: selectedCountry?.phoneCode,
      );
      if (strictPhone == null) {
        _showError(
          RegionService.invalidPhoneMessage(
            country: selectedCountry,
            regionCode: _deviceRegionCode,
          ),
        );
        return;
      }
      loginValue = strictPhone;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    try {
      final device = await DeviceInfoService.getDeviceInfo().timeout(
        const Duration(seconds: 2),
        onTimeout: () => DeviceInfoData(),
      );
      final auth = await _api.login(
        loginValue,
        _password.text.trim(),
        deviceName: device.name,
        devicePlatform: device.platform,
        deviceOs: device.os,
      );
      final selectedRegion = !isEmail
          ? (_country?.countryCode ?? _deviceRegionCode)
          : await PhoneService.regionCodeFromE164(auth.shop.phone);
      await LocalCache.setPreferredRegionCode(selectedRegion);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      _showError(_errorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFBFDBFE)),
      ),
    );
  }

  Widget _buildCountryPage() {
    final country = _country ?? CountryParser.parseCountryCode('NG');
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final compact = height < 760;
        final veryCompact = height < 680;
        final topGap = veryCompact ? 8.0 : 14.0;
        final titleGap = veryCompact ? 10.0 : 16.0;
        final titleSize = veryCompact ? 25.0 : (compact ? 27.0 : 30.0);
        final bodySize = veryCompact ? 14.0 : (compact ? 15.0 : 16.0);
        final selectorGap = veryCompact ? 6.0 : 12.0;
        final flagSelectedSize = veryCompact ? 88.0 : (compact ? 98.0 : 112.0);
        final flagUnselectedSize = veryCompact ? 74.0 : (compact ? 82.0 : 92.0);
        final countryNameSize = veryCompact ? 22.0 : (compact ? 24.0 : 28.0);
        final countryCodeSize = veryCompact ? 16.0 : 18.0;
        final buttonHeight = veryCompact ? 54.0 : 58.0;
        final bottomGap = veryCompact ? 12.0 : 18.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(0, compact ? 8 : 12, 0, compact ? 14 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: topGap),
              SizedBox(height: titleGap),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Choose your country',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Swipe to set your phone sign-in country and your account region defaults, including currency. Email sign-in still works normally.',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: bodySize,
                    height: 1.45,
                  ),
                ),
              ),
              SizedBox(height: selectorGap),
              Expanded(
                child: PageView.builder(
                  controller: _countrySelectorController,
                  clipBehavior: Clip.none,
                  padEnds: true,
                  itemCount: _countries.length,
                  onPageChanged: (index) {
                    if (!mounted) return;
                    setState(() => _country = _countries[index]);
                  },
                  itemBuilder: (context, index) {
                    final item = _countries[index];
                    return AnimatedBuilder(
                      animation: _countrySelectorController,
                      builder: (context, child) {
                        var page = _countrySelectorController.initialPage.toDouble();
                        if (_countrySelectorController.hasClients) {
                          page = _countrySelectorController.page ?? page;
                        }
                        final distance = (page - index).abs().clamp(0.0, 1.0);
                        final scale = 1 - (distance * 0.34);
                        final opacity = 1 - (distance * 0.48);
                        final slideX = (page - index) * 30;

                        return Transform.translate(
                          offset: Offset(slideX, 0),
                          child: Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: opacity.clamp(0.22, 1.0),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Center(
                        child: SizedBox.expand(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.flagEmoji,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: item.countryCode == country.countryCode
                                      ? flagSelectedSize
                                      : flagUnselectedSize,
                                ),
                              ),
                              SizedBox(height: veryCompact ? 12 : 18),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _textDark,
                                    fontSize: countryNameSize,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '+${item.phoneCode}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _textMuted,
                                  fontSize: countryCodeSize,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  height: buttonHeight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _loading ? null : () => _goToPage(1),
                    child: const Text(
                      'Continue',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              SizedBox(height: bottomGap),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _SigninStepDot(active: true),
                  SizedBox(width: 8),
                  _SigninStepDot(active: false),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCredentialsPage() {
    final country = _country ?? CountryParser.parseCountryCode('NG');
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _loading ? null : () => _goToPage(0),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
              const Spacer(),
              const _SigninStepDot(active: false),
              const SizedBox(width: 8),
              const _SigninStepDot(active: true),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Sign in',
            style: TextStyle(
              color: _textDark,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Using ${country.name} for phone number validation.',
            style: const TextStyle(
              color: _textMuted,
              fontSize: 16,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _loginId,
            keyboardType: TextInputType.emailAddress,
            enabled: !_loading,
            decoration: _inputDecoration('Phone or Email'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            focusNode: _passwordFocusNode,
            obscureText: !_showPassword,
            enabled: !_loading,
            decoration: _inputDecoration('Password').copyWith(
              suffixIcon: _passwordFocusNode.hasFocus
                  ? IconButton(
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
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
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 58,
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
          const SizedBox(height: 22),
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
                          MaterialPageRoute(
                            builder: (_) => Signup(
                              preferredRegionCode:
                                  _country?.countryCode ?? _deviceRegionCode,
                            ),
                          ),
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
    );
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
            child: PageView(
              controller: _pageController,
              children: [
                _buildCountryPage(),
                _buildCredentialsPage(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SigninStepDot extends StatelessWidget {
  const _SigninStepDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: active ? 30 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF007AFF) : const Color(0xFFD1D5DB),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
