import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'reset_password.dart';

class VerifyCode extends StatefulWidget {
  const VerifyCode({super.key});

  @override
  State<VerifyCode> createState() => _VerifyCodeState();
}

class _VerifyCodeState extends State<VerifyCode> {
  static const _primary = Color(0xFF007AFF);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);

  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());
  Timer? _resendTimer;
  int _resendSeconds = 120;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _next() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ResetPassword()),
    );
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      _applyPastedCode(value);
      return;
    }
    if (value.length == 1 && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_isComplete()) {
      _next();
    }
  }

  void _applyPastedCode(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    for (var i = 0; i < _controllers.length; i++) {
      _controllers[i].text = i < digits.length ? digits[i] : '';
    }
    if (digits.length >= _controllers.length) {
      _focusNodes.last.unfocus();
      _next();
    } else {
      _focusNodes[digits.length].requestFocus();
    }
  }

  bool _isComplete() {
    return _controllers.every((c) => c.text.trim().isNotEmpty);
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 120);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
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
                'Verify Code',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter the 4-digit code sent to your phone or email.',
                style: TextStyle(fontSize: 18, color: _textMuted, height: 1.4),
              ),
              const SizedBox(height: 32),
              Center(
                child: Wrap(
                  spacing: 20,
                  children: List.generate(4, (index) {
                    return SizedBox(
                      width: 62,
                      child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: null,
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) => _onChanged(index, value),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '-',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 18),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 18),
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
                    );
                  }),
                ),
              ),
              const SizedBox(height: 28),
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
                  onPressed: _next,
                  child: const Text(
                    'Verify',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _resendSeconds == 0 ? _startResendTimer : null,
                  child: Text(
                    _resendSeconds == 0
                        ? 'Resend code'
                        : 'Resend in ${_formatTime(_resendSeconds)}',
                    style: TextStyle(
                      color: _resendSeconds == 0
                          ? _textMuted
                          : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
