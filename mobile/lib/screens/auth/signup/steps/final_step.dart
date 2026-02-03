import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FinalStep extends StatelessWidget {
  const FinalStep({
    super.key,
    required this.passwordController,
    required this.addressController,
    required this.showPassword,
    required this.onTogglePassword,
    required this.enabled,
    this.passwordError,
    this.addressError,
    this.onPasswordChanged,
    this.onAddressChanged,
  });

  final TextEditingController passwordController;
  final TextEditingController addressController;
  final bool showPassword;
  final VoidCallback onTogglePassword;
  final bool enabled;
  final String? passwordError;
  final String? addressError;
  final ValueChanged<String>? onPasswordChanged;
  final ValueChanged<String>? onAddressChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Final Step',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Password',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: passwordController,
          obscureText: !showPassword,
          enabled: enabled,
          onChanged: onPasswordChanged,
          inputFormatters: [LengthLimitingTextInputFormatter(20)],
          decoration: InputDecoration(
            hintText: 'Create a password',
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
            suffixIcon: IconButton(
              onPressed: onTogglePassword,
              icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
            ),
            errorText: passwordError,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Shop Address (optional)',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: addressController,
          maxLines: 4,
          enabled: enabled,
          onChanged: onAddressChanged,
          decoration: InputDecoration(
            hintText: 'e.g. Shop 12, Lagos Island Market',
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
            errorText: addressError,
          ),
        ),
      ],
    );
  }
}
