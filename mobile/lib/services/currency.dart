import 'package:intl/intl.dart';

import '../data/models.dart';
import 'cache/loader.dart';

class CurrencyService {
  CurrencyService._();

  static ({String locale, String symbol}) resolveContext() {
    final locale = _currentLocale();
    final code = _resolveCurrencyCode();
    if (code != null) {
      return (locale: locale, symbol: _currencySymbol(code));
    }
    try {
      final symbol = NumberFormat.simpleCurrency(locale: locale).currencySymbol;
      return (locale: locale, symbol: symbol.isEmpty ? ' ' : symbol);
    } catch (_) {
      return (locale: locale, symbol: ' ');
    }
  }

  static String format(num amount, {int? decimalDigits}) {
    final locale = _currentLocale();
    final code = _resolveCurrencyCode();
    try {
      if (code != null) {
        return NumberFormat.currency(
          locale: locale,
          name: code,
          symbol: _currencySymbol(code),
          decimalDigits: decimalDigits,
        ).format(amount);
      }
      return NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: decimalDigits,
      ).format(amount);
    } catch (_) {
      if (code != null) {
        return NumberFormat.currency(
          locale: locale,
          name: code,
          symbol: _currencySymbol(code),
          decimalDigits: decimalDigits,
        ).format(amount);
      }
      return NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: decimalDigits,
      ).format(amount);
    }
  }

  static String symbol() {
    final code = _resolveCurrencyCode();
    if (code != null) {
      return _currencySymbol(code);
    }
    return ' ';
  }

  static String currencyCodeForRegion(
    String? regionCode, {
    String fallback = 'NGN',
  }) {
    final normalized = regionCode?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) {
      return fallback;
    }
    return _regionToCurrency[normalized] ?? fallback;
  }

  static String? _resolveCurrencyCode() {
    final shop = _loadShop();
    final code = shop?.currencyCode.trim().toUpperCase();
    if (code != null && code.isNotEmpty) {
      return code;
    }
    return null;
  }

  static String _currentLocale() {
    final code = _resolveCurrencyCode();
    return (code == null ? null : _currencyToLocale[code]) ?? 'en_NG';
  }

  static ShopProfile? _loadShop() {
    final settings = CacheLoader.loadSettingsSummaryCache();
    if (settings != null) return settings.shop;
    final home = CacheLoader.loadHomeSummaryCache();
    if (home != null) return home.shop;
    return null;
  }

  static String _currencySymbol(String code) {
    try {
      final symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;
      return symbol.isEmpty ? code : symbol;
    } catch (_) {
      return code;
    }
  }

  static const Map<String, String> _currencyToLocale = {
    'AED': 'en_AE',
    'ARS': 'es_AR',
    'AUD': 'en_AU',
    'BDT': 'bn_BD',
    'BHD': 'ar_BH',
    'BRL': 'pt_BR',
    'CAD': 'en_CA',
    'CHF': 'de_CH',
    'CLP': 'es_CL',
    'CNY': 'zh_CN',
    'COP': 'es_CO',
    'CZK': 'cs_CZ',
    'DKK': 'da_DK',
    'EGP': 'ar_EG',
    'ETB': 'am_ET',
    'EUR': 'en_IE',
    'GBP': 'en_GB',
    'GHS': 'en_GH',
    'HKD': 'zh_HK',
    'HUF': 'hu_HU',
    'IDR': 'id_ID',
    'ILS': 'he_IL',
    'INR': 'en_IN',
    'JPY': 'ja_JP',
    'KES': 'en_KE',
    'KRW': 'ko_KR',
    'KWD': 'ar_KW',
    'MAD': 'fr_MA',
    'MXN': 'es_MX',
    'MYR': 'ms_MY',
    'NGN': 'en_NG',
    'NOK': 'nb_NO',
    'NZD': 'en_NZ',
    'OMR': 'ar_OM',
    'PHP': 'en_PH',
    'PKR': 'en_PK',
    'PLN': 'pl_PL',
    'QAR': 'ar_QA',
    'RON': 'ro_RO',
    'RUB': 'ru_RU',
    'RWF': 'en_RW',
    'SAR': 'ar_SA',
    'SEK': 'sv_SE',
    'SGD': 'en_SG',
    'THB': 'th_TH',
    'TRY': 'tr_TR',
    'TZS': 'sw_TZ',
    'UGX': 'en_UG',
    'USD': 'en_US',
    'VND': 'vi_VN',
    'ZAR': 'en_ZA',
  };

  static const Map<String, String> _regionToCurrency = {
    'AE': 'AED',
    'AR': 'ARS',
    'AU': 'AUD',
    'BD': 'BDT',
    'BH': 'BHD',
    'BR': 'BRL',
    'CA': 'CAD',
    'CH': 'CHF',
    'CL': 'CLP',
    'CN': 'CNY',
    'CO': 'COP',
    'CZ': 'CZK',
    'DK': 'DKK',
    'EC': 'USD',
    'EG': 'EGP',
    'ET': 'ETB',
    'EU': 'EUR',
    'GB': 'GBP',
    'GH': 'GHS',
    'HK': 'HKD',
    'HU': 'HUF',
    'ID': 'IDR',
    'IE': 'EUR',
    'IL': 'ILS',
    'IN': 'INR',
    'JP': 'JPY',
    'KE': 'KES',
    'KR': 'KRW',
    'KW': 'KWD',
    'MA': 'MAD',
    'MX': 'MXN',
    'MY': 'MYR',
    'NG': 'NGN',
    'NO': 'NOK',
    'NZ': 'NZD',
    'OM': 'OMR',
    'PA': 'USD',
    'PH': 'PHP',
    'PK': 'PKR',
    'PL': 'PLN',
    'QA': 'QAR',
    'RO': 'RON',
    'RU': 'RUB',
    'RW': 'RWF',
    'SA': 'SAR',
    'SE': 'SEK',
    'SG': 'SGD',
    'SV': 'USD',
    'TH': 'THB',
    'TR': 'TRY',
    'TZ': 'TZS',
    'UG': 'UGX',
    'US': 'USD',
    'VN': 'VND',
    'ZA': 'ZAR',
  };
}
