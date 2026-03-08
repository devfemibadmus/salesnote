import 'dart:async';

import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';

import '../../../data/models.dart';
import '../../../services/api_client.dart';
import '../../../services/cache/local.dart';
import '../../../services/notice.dart';
import '../../../services/phone.dart';
import '../../../services/region.dart';
import '../../../services/token_store.dart';
import '../../../services/timezone.dart';
import '../../../services/validators.dart';
import '../verify/verify_code.dart';
import 'steps/contact.dart';
import 'steps/final_step.dart';
import 'steps/shop_name.dart';

class Signup extends StatefulWidget {
  const Signup({super.key, this.preferredRegionCode});

  final String? preferredRegionCode;

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  static const _primary = Color(0xFF007AFF);

  final _shopName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _address = TextEditingController();
  final _api = ApiClient(TokenStore());
  Country? _country;
  late final String _deviceRegionCode;

  int _step = 0;
  bool _showPassword = false;
  bool _submitting = false;
  String? _shopNameError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  String? _addressError;
  Timer? _phoneDebounce;

  @override
  void dispose() {
    _phoneDebounce?.cancel();
    _shopName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _address.dispose();
    super.dispose();
  }

  void _initCountry() {
    try {
      _country = CountryParser.parseCountryCode(_deviceRegionCode);
    } catch (_) {
      _country = CountryParser.parseCountryCode('NG');
    }
  }

  @override
  void initState() {
    super.initState();
    _deviceRegionCode =
        (widget.preferredRegionCode?.trim().toUpperCase().isNotEmpty ?? false)
        ? widget.preferredRegionCode!.trim().toUpperCase()
        : (LocalCache.getPreferredRegionCode() ??
              RegionService.getDeviceRegionCode());
    _initCountry();
  }


  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step -= 1);
  }

  Future<void> _next() async {
    if (_step == 1) {
      final ok = await _validateContactAsync();
      if (!ok) return;
    } else if (!_validateStep()) {
      return;
    }
    if (_step < 2) {
      setState(() => _step += 1);
      return;
    }
    if (_submitting) return;
    await _submit();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    String timezone;
    try {
      timezone = await TimezoneService.getDeviceTimezone();
    } catch (e) {
      setState(() => _submitting = false);
      _showError(e.toString());
      return;
    }

    final phoneRegion = (_country?.countryCode ?? _deviceRegionCode);
    final phoneE164 = await PhoneService.normalizeE164(
      _phone.text.trim(),
      phoneRegion,
      countryPhoneCode: _country?.phoneCode,
    );
    if (phoneE164 == null) {
      final phoneErrorMessage = RegionService.invalidPhoneMessage(
        country: _country,
        regionCode: phoneRegion,
      );
      setState(() {
        _phoneError = phoneErrorMessage;
        _submitting = false;
      });
      _showError(phoneErrorMessage);
      return;
    }

    final input = RegisterInput(
      shopName: _shopName.text.trim(),
      phone: phoneE164,
      email: _email.text.trim(),
      password: _password.text,
      address: _address.text.trim(),
      timezone: timezone,
    );

    try {
      await _api.register(input);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyCode.signup(
            phoneOrEmail: input.email,
            registerInput: input,
            preferredRegionCode: phoneRegion,
          ),
        ),
      );
    } catch (e) {
      _showError(_errorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
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

  bool _validateStep() {
    setState(() {
      _shopNameError = null;
      _phoneError = null;
      _emailError = null;
      _passwordError = null;
      _addressError = null;
    });

    if (_step == 0) {
      final name = _shopName.text.trim();
      if (name.length < 3) {
        _shopNameError = 'Shop name must be at least 3 characters.';
        _showError(_shopNameError!);
        setState(() {});
        return false;
      }
      if (name.length > 40) {
        _shopNameError = 'Shop name must be 40 characters or less.';
        _showError(_shopNameError!);
        setState(() {});
        return false;
      }
      return true;
    }

    if (_step == 1) {
      return true;
    }

    final password = _password.text;
    final address = _address.text.trim();
    final addressWords = _wordCount(address);
    if (password.isEmpty) {
      _passwordError = 'Password is required.';
      _showError(_passwordError!);
    } else if (password.length < 5) {
      _passwordError = 'Password must be at least 5 characters.';
      _showError(_passwordError!);
    } else if (password.length > 20) {
      _passwordError = 'Password must be 20 characters or less.';
      _showError(_passwordError!);
    }
    if (address.isEmpty) {
      _addressError = 'Shop address is required.';
      _showError(_addressError!);
    } else if (address.length < 8) {
      _addressError = 'Address must be at least 8 characters.';
      _showError(_addressError!);
    } else if (address.length > 40) {
      _addressError = 'Address must be 40 characters or less.';
      _showError(_addressError!);
    } else if (addressWords < 4) {
      _addressError = 'Address words: $addressWords (need 4-10).';
      _showError(_addressError!);
    } else if (addressWords > 10) {
      _addressError = 'Address words: $addressWords (need 4-10).';
      _showError(_addressError!);
    }
    setState(() {});
    return _passwordError == null && _addressError == null;
  }

  int _wordCount(String text) {
    final normalized = text.replaceAll(',', ' ').trim();
    if (normalized.isEmpty) return 0;
    final words = normalized
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .toList();
    return words.length;
  }

  void _onPhoneChanged(String value) {
    _phoneDebounce?.cancel();
    _phoneDebounce = Timer(const Duration(milliseconds: 300), () async {
      final input = value.trim();
      if (input.isEmpty) {
        if (mounted) setState(() => _phoneError = null);
        return;
      }
      final region = (_country?.countryCode ?? _deviceRegionCode);
      final valid = await PhoneService.isValid(
        input,
        region,
        countryPhoneCode: _country?.phoneCode,
      );
      if (!mounted) return;
      setState(() {
        _phoneError = valid
            ? null
            : RegionService.invalidPhoneMessage(
                country: _country,
                regionCode: region,
              );
      });
      if (valid) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      ShopNameStep(
        controller: _shopName,
        enabled: !_submitting,
        errorText: _shopNameError,
        onChanged: (_) {
          if (_shopNameError != null) {
            setState(() => _shopNameError = null);
          }
        },
      ),
      ContactStep(
        phoneController: _phone,
        emailController: _email,
        enabled: !_submitting,
        phoneError: _phoneError,
        emailError: _emailError,
        country: _country,
        onPhoneChanged: (_) {
          _onPhoneChanged(_phone.text);
        },
        onEmailChanged: (_) {
          if (_emailError != null) {
            setState(() => _emailError = null);
          }
        },
      ),
      FinalStep(
        passwordController: _password,
        addressController: _address,
        showPassword: _showPassword,
        onTogglePassword: () => setState(() => _showPassword = !_showPassword),
        enabled: !_submitting,
        passwordError: _passwordError,
        addressError: _addressError,
        onPasswordChanged: (_) {
          if (_passwordError != null) {
            setState(() => _passwordError = null);
          }
        },
        onAddressChanged: (_) {
          if (_addressError != null) {
            setState(() => _addressError = null);
          }
        },
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: AbsorbPointer(
            absorbing: _submitting,
            child: Column(
              children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _back,
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    ),
                    const Spacer(),
                    const Text(
                      'Create Account',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              _StepIndicator(active: _step),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: steps[_step],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  children: [
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
                        onPressed: _submitting ? null : _next,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _submitting
                                  ? 'Please wait...'
                                  : (_step < 2 ? 'Next' : 'Create shop'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            if (_step == 2) ...[
                              const SizedBox(width: 10),
                              const Icon(Icons.arrow_forward),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Step ${_step + 1} of 3',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_step == 2) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'By creating your shop, you agree to our Merchant Terms of Service and Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _validateContactAsync() async {
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    final region = (_country?.countryCode ?? _deviceRegionCode);

    if (phone.isEmpty) {
      setState(() => _phoneError = 'Phone number is required.');
      _showError('Phone number is required.');
    } else {
      final valid = await PhoneService.isValid(
        phone,
        region,
        countryPhoneCode: _country?.phoneCode,
      );
      if (!valid) {
        final phoneErrorMessage = RegionService.invalidPhoneMessage(
          country: _country,
          regionCode: region,
        );
        setState(() => _phoneError = phoneErrorMessage);
        _showError(phoneErrorMessage);
      }
    }

    if (!Validators.isValidEmail(email)) {
      setState(() => _emailError = 'Enter a valid email (max 50 characters).');
      _showError('Enter a valid email (max 50 characters).');
    }

    return _phoneError == null && _emailError == null;
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.active});

  final int active;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF007AFF);
    const inactive = Color(0xFFD1D5DB);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          final isActive = index == active;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            height: 8,
            width: isActive ? 46 : 10,
            decoration: BoxDecoration(
              color: isActive ? activeColor : inactive,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}
