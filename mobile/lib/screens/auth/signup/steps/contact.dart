import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ContactStep extends StatelessWidget {
  const ContactStep({
    super.key,
    required this.phoneController,
    required this.emailController,
    required this.enabled,
    this.country,
    this.phoneError,
    this.emailError,
    this.onPhoneChanged,
    this.onEmailChanged,
  });

  final TextEditingController phoneController;
  final TextEditingController emailController;
  final bool enabled;
  final Country? country;
  final String? phoneError;
  final String? emailError;
  final ValueChanged<String>? onPhoneChanged;
  final ValueChanged<String>? onEmailChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Contact Details',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          enabled: enabled,
          onChanged: onPhoneChanged,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            hintText: country == null
                ? 'Enter phone number'
                : 'Enter ${country!.name} phone number',
            filled: true,
            fillColor: Colors.white,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
        if (phoneError != null) ...[
          const SizedBox(height: 6),
          Text(
            phoneError!,
            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: enabled,
          onChanged: onEmailChanged,
          inputFormatters: [LengthLimitingTextInputFormatter(50)],
          decoration: InputDecoration(
            hintText: 'name@email.com',
            filled: true,
            fillColor: Colors.white,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            errorText: emailError,
          ),
        ),
      ],
    );
  }
}
