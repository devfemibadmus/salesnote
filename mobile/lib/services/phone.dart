import 'package:phone_number/phone_number.dart';

class PhoneService {
  PhoneService._();

  static final PhoneNumberUtil _util = PhoneNumberUtil();

  static String _buildInputForValidation(String raw, String? countryPhoneCode) {
    final input = raw.trim();
    // ignore: avoid_print
    print('PhoneService._buildInputForValidation raw="$raw" trimmed="$input" countryPhoneCode="$countryPhoneCode"');
    if (input.isEmpty) return '';

    if (input.startsWith('+')) {
      final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
      final result = digits.isEmpty ? '' : '+$digits';
      // ignore: avoid_print
      print('PhoneService._buildInputForValidation startsWithPlus digits="$digits" result="$result"');
      return result;
    }

    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    if (countryPhoneCode != null && countryPhoneCode.trim().isNotEmpty) {
      final normalizedCountryCode = countryPhoneCode.trim();
      if (digits.startsWith('00$normalizedCountryCode')) {
        final result = '+${digits.substring(2)}';
        // ignore: avoid_print
        print('PhoneService._buildInputForValidation withInternationalPrefix digits="$digits" result="$result"');
        return result;
      }

      if (digits.startsWith(normalizedCountryCode)) {
        final result = '+$digits';
        // ignore: avoid_print
        print('PhoneService._buildInputForValidation withExistingCountryCode digits="$digits" result="$result"');
        return result;
      }

      var national = digits;
      if (national.startsWith('0')) {
        national = national.substring(1);
      }
      final result = '+$normalizedCountryCode$national';
      // ignore: avoid_print
      print('PhoneService._buildInputForValidation withCountry digits="$digits" national="$national" result="$result"');
      return result;
    }

    final result = digits;
    // ignore: avoid_print
    print('PhoneService._buildInputForValidation fallback digits="$digits" result="$result"');
    return result;
  }

  static Future<String?> normalizeE164(
    String raw,
    String regionCode, {
    String? countryPhoneCode,
  }) async {
    final input = _buildInputForValidation(raw, countryPhoneCode);
    // ignore: avoid_print
    print('PhoneService.normalizeE164 raw="$raw" regionCode="$regionCode" countryPhoneCode="$countryPhoneCode" builtInput="$input"');
    if (input.isEmpty) return null;
    try {
      final parsed = await _util.parse(input, regionCode: regionCode);
      final e164 = parsed.e164;
      // ignore: avoid_print
      print('PhoneService.normalizeE164 parsedE164="$e164"');
      if (e164.isEmpty) return null;
      if (countryPhoneCode != null &&
          countryPhoneCode.trim().isNotEmpty &&
          !e164.startsWith('+${countryPhoneCode.trim()}')) {
        // ignore: avoid_print
        print('PhoneService.normalizeE164 rejectedByCountryCode expected="+${countryPhoneCode.trim()}" actual="$e164"');
        return null;
      }
      // ignore: avoid_print
      print('PhoneService.normalizeE164 result="$e164"');
      return e164;
    } catch (_) {
      // ignore: avoid_print
      print('PhoneService.normalizeE164 parseError raw="$raw" regionCode="$regionCode" countryPhoneCode="$countryPhoneCode"');
      return null;
    }
  }

  static Future<bool> isValid(
    String raw,
    String regionCode, {
    String? countryPhoneCode,
  }) async {
    final normalized = await normalizeE164(
      raw,
      regionCode,
      countryPhoneCode: countryPhoneCode,
    );
    // ignore: avoid_print
    print('PhoneService.isValid raw="$raw" regionCode="$regionCode" countryPhoneCode="$countryPhoneCode" normalized="$normalized"');
    if (normalized == null) return false;
    try {
      final parsed = await _util.parse(normalized, regionCode: regionCode);
      final mobileCapable = parsed.type == PhoneNumberType.MOBILE ||
          parsed.type == PhoneNumberType.FIXED_LINE_OR_MOBILE;
      final result = await _util.validate(normalized, regionCode: regionCode);
      // ignore: avoid_print
      print(
        'PhoneService.isValid validateResult=$result normalized="$normalized" '
        'parsedType="${parsed.type}" mobileCapable=$mobileCapable',
      );
      return result && mobileCapable;
    } catch (_) {
      // ignore: avoid_print
      print('PhoneService.isValid validateError normalized="$normalized" regionCode="$regionCode"');
      return false;
    }
  }

  static Future<String?> regionCodeFromE164(String raw) async {
    final input = raw.trim();
    if (!input.startsWith('+')) return null;
    try {
      final parsed = await _util.parse(input, regionCode: 'US');
      final code = parsed.regionCode.trim().toUpperCase();
      if (code.isEmpty) return null;
      return code;
    } catch (_) {
      return null;
    }
  }
}
