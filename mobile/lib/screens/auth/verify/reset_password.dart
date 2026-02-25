import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../services/token_store.dart';

class ResetPassword extends StatefulWidget {
  const ResetPassword({
    super.key,
    required this.phoneOrEmail,
    required this.code,
  });

  final String phoneOrEmail;
  final String code;

  @override
  State<ResetPassword> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  static const _primary = Color(0xFF007AFF);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);

  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _api = ApiClient(TokenStore());
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _loading = false;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final password = _password.text;
    final confirm = _confirm.text;
    setState(() {
      _passwordError = null;
      _confirmError = null;
    });
    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required.');
      return;
    }
    if (password.length > 20) {
      setState(() => _passwordError = 'Password must be 20 characters or less.');
      return;
    }
    if (confirm.isEmpty) {
      setState(() => _confirmError = 'Confirm your password.');
      return;
    }
    if (confirm.length > 20) {
      setState(() => _confirmError = 'Confirm password must be 20 characters or less.');
      return;
    }
    if (password != confirm) {
      setState(() => _confirmError = 'Passwords do not match.');
      return;
    }
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _loading = true);
      await _api.resetPassword(widget.phoneOrEmail, widget.code, password.trim());
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Password reset successful. Please sign in.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      final message = e is ApiException ? e.message : e.toString();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            children: [
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Salesnote',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Reset Password',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'New Password',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _password,
                enabled: !_loading,
                obscureText: !_showPassword,
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: '• • • • • • • •',
                  hintStyle: const TextStyle(color: Color(0xFFCBD5F5)),
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
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                  ),
                  errorText: _passwordError,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Confirm New Password',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirm,
                enabled: !_loading,
                obscureText: !_showConfirm,
                onChanged: (_) {
                  if (_confirmError != null) {
                    setState(() => _confirmError = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: '• • • • • • • •',
                  hintStyle: const TextStyle(color: Color(0xFFCBD5F5)),
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
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _showConfirm = !_showConfirm),
                    icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                  ),
                  errorText: _confirmError,
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
                  onPressed: _loading ? null : _reset,
                  child: Text(
                    _loading ? 'Please wait...' : 'Reset password',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }
}
