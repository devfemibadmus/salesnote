import 'package:country_picker/country_picker.dart';

import 'cache/local.dart';

class RegionService {
  RegionService._();

  static const String _fallbackRegionCode = 'NG';

  static String getDeviceRegionCode() {
    return resolveAccountRegionCode();
  }

  static String resolveAccountRegionCode({
    String fallback = _fallbackRegionCode,
  }) {
    final normalizedFallback = fallback.trim().toUpperCase();
    final phone = _loadAccountPhone();
    final regionCode = regionCodeFromE164(phone);
    if (regionCode != null && regionCode.isNotEmpty) {
      return regionCode;
    }
    return normalizedFallback;
  }

  static Country resolveAccountCountry({
    String fallback = _fallbackRegionCode,
  }) {
    final fallbackRegionCode = fallback.trim().toUpperCase();
    final phone = _loadAccountPhone();
    final phoneCode = countryPhoneCodeFromE164(phone);
    if (phoneCode != null) {
      final fromPhone = CountryParser.tryParsePhoneCode(phoneCode);
      if (fromPhone != null) {
        return fromPhone;
      }
    }

    final fromRegion = CountryParser.tryParseCountryCode(
      resolveAccountRegionCode(fallback: fallbackRegionCode),
    );
    if (fromRegion != null) {
      return fromRegion;
    }
    return CountryParser.parseCountryCode(fallbackRegionCode);
  }

  static String invalidPhoneMessage({
    Country? country,
    String? regionCode,
  }) {
    final resolvedCountry =
        country ??
        (regionCode == null || regionCode.trim().isEmpty
            ? null
            : CountryParser.tryParseCountryCode(regionCode.trim().toUpperCase()));
    if (resolvedCountry == null) {
      return 'Enter a valid phone number.';
    }
    return 'Enter a valid ${resolvedCountry.name} phone number.';
  }

  static String? regionCodeFromE164(String? e164) {
    final phoneCode = countryPhoneCodeFromE164(e164);
    if (phoneCode == null) return null;
    final country = CountryParser.tryParsePhoneCode(phoneCode);
    return country?.countryCode.trim().toUpperCase();
  }

  static String? countryPhoneCodeFromE164(String? e164) {
    final normalized = e164?.trim() ?? '';
    if (!normalized.startsWith('+')) return null;
    final digits = normalized.substring(1).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    for (var length = 4; length >= 1; length--) {
      if (digits.length < length) continue;
      final candidate = digits.substring(0, length);
      if (CountryParser.tryParsePhoneCode(candidate) != null) {
        return candidate;
      }
    }
    return null;
  }

  static String? _loadAccountPhone() {
    final settings = LocalCache.loadSettingsSummary();
    final settingsPhone = settings?['shop']?['phone']?.toString().trim();
    if (settingsPhone != null && settingsPhone.isNotEmpty) {
      return settingsPhone;
    }

    final home = LocalCache.loadHomeSummary();
    final homePhone = home?['shop']?['phone']?.toString().trim();
    if (homePhone != null && homePhone.isNotEmpty) {
      return homePhone;
    }

    return null;
  }
}
