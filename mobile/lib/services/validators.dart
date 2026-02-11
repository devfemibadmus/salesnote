import 'package:flutter/services.dart';

class Validators {
  static final RegExp _emailRegex =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$', caseSensitive: false);
  static final RegExp _e164Regex = RegExp(r'^\+[1-9]\d{7,14}$');

  static bool isValidEmail(String email) {
    final result = !(email.isEmpty || email.length > 50) && _emailRegex.hasMatch(email);
    // ignore: avoid_print
    print('Validators.isValidEmail input="$email" result=$result');
    return result;
  }

  static bool isValidE164(String phone) {
    final result = phone.isNotEmpty && _e164Regex.hasMatch(phone);
    // ignore: avoid_print
    print('Validators.isValidE164 input="$phone" result=$result');
    return result;
  }

  static bool isValidPhoneOrEmail(String input) {
    final trimmed = input.trim();
    final result = trimmed.contains('@')
        ? isValidEmail(trimmed)
        : isValidE164(trimmed);
    // ignore: avoid_print
    print('Validators.isValidPhoneOrEmail input="$input" trimmed="$trimmed" result=$result');
    return result;
  }

  static bool isValidShopName(String value) {
    final text = value.trim();
    final result = text.length >= 3 && text.length <= 40;
    // ignore: avoid_print
    print('Validators.isValidShopName input="$value" trimmed="$text" result=$result');
    return result;
  }

  static bool isValidSignatureName(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      // ignore: avoid_print
      print('Validators.isValidSignatureName input="$value" trimmed="$text" result=false');
      return false;
    }
    final lettersOnly = RegExp(r'^[A-Za-z ]+$').hasMatch(text);
    if (!lettersOnly) {
      // ignore: avoid_print
      print('Validators.isValidSignatureName input="$value" trimmed="$text" result=false');
      return false;
    }
    final lettersCount = text.replaceAll(' ', '').length;
    final result = lettersCount <= 10;
    // ignore: avoid_print
    print('Validators.isValidSignatureName input="$value" trimmed="$text" lettersCount=$lettersCount result=$result');
    return result;
  }
}

class E164InputFormatter extends TextInputFormatter {
  static const int _maxLen = 16; // + plus up to 15 digits

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (text.isEmpty) return newValue;

    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (i == 0 && ch == '+') {
        buffer.write(ch);
        continue;
      }
      if (RegExp(r'\d').hasMatch(ch)) {
        buffer.write(ch);
      }
    }

    var sanitized = buffer.toString();
    if (!sanitized.startsWith('+')) {
      sanitized = '+${sanitized.replaceAll('+', '')}';
    }

    if (sanitized.length > _maxLen) {
      sanitized = sanitized.substring(0, _maxLen);
    }

    return TextEditingValue(
      text: sanitized,
      selection: TextSelection.collapsed(offset: sanitized.length),
    );
  }
}
