import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/api_client.dart';
import '../../../services/token_store.dart';
import 'reset_password.dart';

class VerifyCode extends StatefulWidget {
  const VerifyCode({super.key, required this.phoneOrEmail});

  final String phoneOrEmail;

  @override
  State<VerifyCode> createState() => _VerifyCodeState();
}

class _VerifyCodeState extends State<VerifyCode> {
  static const _primary = Color(0xFF007AFF);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _api = ApiClient(TokenStore());
  Timer? _resendTimer;
  int _resendSeconds = 120;
  bool _loading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_loading) return;
    if (_controller.text.length != 6) {
      setState(() => _errorText = 'Enter the 6-digit code.');
      _showError('Enter the 6-digit code.');
      return;
    }

    final code = _controller.text;
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _loading = true;
        _errorText = null;
      });
      await _api.verifyResetCode(widget.phoneOrEmail, code);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ResetPassword(phoneOrEmail: widget.phoneOrEmail, code: code),
        ),
      );
    } catch (e) {
      _showError(_errorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds != 0 || _loading) return;
    try {
      setState(() => _loading = true);
      await _api.forgotPassword(widget.phoneOrEmail);
      if (!mounted) return;
      _showError('Code resent.');
      _startResendTimer();
    } catch (e) {
      _showError(_errorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _onTextChanged(String value) {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
    setState(() {});
    if (value.length == 6) {
      _verify();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessage(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
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
                'Enter the 6-digit code sent to your phone or email.',
                style: TextStyle(fontSize: 18, color: _textMuted, height: 1.4),
              ),
              const SizedBox(height: 32),
              Center(
                child: SizedBox(
                  height: 60,
                  width: 338,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(6, (index) {
                          final text = _controller.text;
                          final hasDigit = index < text.length;
                          final isFocused = _focusNode.hasFocus &&
                              (index == text.length ||
                                  (index == 5 && text.length == 6));

                          return Container(
                            width: 48,
                            height: 60,
                            margin: EdgeInsets.only(right: index < 5 ? 10 : 0),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isFocused ? _primary : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              hasDigit ? text[index] : '-',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color:
                                    hasDigit
                                        ? _textDark
                                        : const Color(0xFF94A3B8),
                              ),
                            ),
                          );
                        }),
                      ),
                      Positioned.fill(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 6,
                          autofocus: true,
                          showCursor: false,
                          enableInteractiveSelection: false,
                          onChanged: _onTextChanged,
                          style: const TextStyle(
                            color: Colors.transparent,
                            fontSize: 1,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            counterText: '',
                            filled: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _errorText!,
                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                  ),
                ),
              ],
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
                  onPressed: _loading ? null : _verify,
                  child: Text(
                    _loading ? 'Please wait...' : 'Verify',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _resendSeconds == 0 && !_loading ? _resend : null,
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
