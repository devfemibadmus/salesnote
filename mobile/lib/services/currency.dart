import 'dart:ui' as ui;

import 'package:country_picker/country_picker.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import 'cache/local.dart';
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
    return formatForCode(
      code,
      amount,
      decimalDigits: decimalDigits,
      fallbackLocale: locale,
    );
  }

  static String formatForCode(
    String? code,
    num amount, {
    int? decimalDigits,
    String? fallbackLocale,
  }) {
    final normalizedCode = code?.trim().toUpperCase();
    final locale =
        (normalizedCode == null ? null : _currencyToLocale[normalizedCode]) ??
        fallbackLocale ??
        _currentLocale();
    try {
      if (normalizedCode != null && normalizedCode.isNotEmpty) {
        return NumberFormat.currency(
          locale: locale,
          name: normalizedCode,
          symbol: _currencySymbol(normalizedCode),
          decimalDigits: decimalDigits,
        ).format(amount);
      }
      return NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: decimalDigits,
      ).format(amount);
    } catch (_) {
      if (normalizedCode != null && normalizedCode.isNotEmpty) {
        return NumberFormat.currency(
          locale: locale,
          name: normalizedCode,
          symbol: _currencySymbol(normalizedCode),
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
    return symbolForCode(code);
  }

  static String symbolForCode(String? code) {
    final normalizedCode = code?.trim().toUpperCase();
    if (normalizedCode != null && normalizedCode.isNotEmpty) {
      return _currencySymbol(normalizedCode);
    }
    return ' ';
  }

  static double heuristicUnitPriceFloorForCode(String? code) {
    final normalizedCode = code?.trim().toUpperCase();
    switch (normalizedCode) {
      case 'IDR':
      case 'LAK':
      case 'MMK':
      case 'VND':
        return 1000;
      case 'BIF':
      case 'CDF':
      case 'CLP':
      case 'DJF':
      case 'GNF':
      case 'GHS':
      case 'ISK':
      case 'JPY':
      case 'KES':
      case 'KMF':
      case 'KRW':
      case 'MGA':
      case 'MWK':
      case 'NGN':
      case 'PYG':
      case 'RWF':
      case 'SLL':
      case 'TZS':
      case 'UGX':
      case 'XAF':
      case 'XOF':
        return 100;
      default:
        return 10;
    }
  }

  static String? currencyCodeForRegion(String? regionCode) {
    final normalized = regionCode?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final country = CountryParser.tryParseCountryCode(normalized);
    final phoneCode = country?.phoneCode.trim();
    if (phoneCode == null || phoneCode.isEmpty) {
      return null;
    }
    return _currencyCodeFromPhoneCode(phoneCode);
  }

  static String? _resolveCurrencyCode() {
    final shop = _loadShop();
    final code = shop?.currencyCode.trim().toUpperCase();
    if (code != null && code.isNotEmpty) {
      return code;
    }
    final preferredCurrencyCode = LocalCache.getPreferredCurrencyCode();
    if (preferredCurrencyCode != null && preferredCurrencyCode.isNotEmpty) {
      return preferredCurrencyCode;
    }
    final preferredRegionCode = LocalCache.getPreferredRegionCode();
    final preferredRegionCurrency = currencyCodeForRegion(preferredRegionCode);
    if (preferredRegionCurrency != null && preferredRegionCurrency.isNotEmpty) {
      return preferredRegionCurrency;
    }
    final localeRegionCode = ui.PlatformDispatcher.instance.locale.countryCode
        ?.trim()
        .toUpperCase();
    final localeCurrency = currencyCodeForRegion(localeRegionCode);
    if (localeCurrency != null && localeCurrency.isNotEmpty) {
      return localeCurrency;
    }
    return null;
  }

  static String _currentLocale() {
    final code = _resolveCurrencyCode();
    return (code == null ? null : _currencyToLocale[code]) ??
        Intl.getCurrentLocale();
  }

  static ShopProfile? _loadShop() {
    final settings = CacheLoader.loadSettingsSummaryCache();
    if (settings != null) return settings.shop;
    final home = CacheLoader.loadHomeSummaryCache();
    if (home != null) return home.shop;
    return null;
  }

  static String _currencySymbol(String code) {
    final locale = _currencyToLocale[code] ?? Intl.getCurrentLocale();
    try {
      final symbol = NumberFormat.simpleCurrency(
        locale: locale,
        name: code,
      ).currencySymbol;
      if (symbol.isNotEmpty && symbol != code) {
        return symbol;
      }
    } catch (_) {}
    try {
      final symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;
      if (symbol.isNotEmpty) {
        return symbol;
      }
    } catch (_) {
      return code;
    }
    return code;
  }

  static String? _currencyCodeFromPhoneCode(String phoneCode) {
    final digits = phoneCode.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }

    for (var length = digits.length; length >= 1; length--) {
      final candidate = digits.substring(0, length);
      final currency = _phoneCodeToCurrency[candidate];
      if (currency != null) {
        return currency;
      }
    }
    return null;
  }

  static const Map<String, String> _currencyToLocale = {
    'AED': 'en_AE',
    'AFN': 'fa_AF',
    'ALL': 'sq_AL',
    'AMD': 'hy_AM',
    'AOA': 'pt_AO',
    'ARS': 'es_AR',
    'AUD': 'en_AU',
    'AWG': 'nl_AW',
    'BAM': 'bs_BA',
    'BDT': 'bn_BD',
    'BGN': 'bg_BG',
    'BHD': 'ar_BH',
    'BIF': 'fr_BI',
    'BND': 'ms_BN',
    'BOB': 'es_BO',
    'BRL': 'pt_BR',
    'BWP': 'en_BW',
    'BYN': 'be_BY',
    'BZD': 'en_BZ',
    'CDF': 'fr_CD',
    'CHF': 'de_CH',
    'CLP': 'es_CL',
    'CNY': 'zh_CN',
    'COP': 'es_CO',
    'CRC': 'es_CR',
    'CUP': 'es_CU',
    'CVE': 'pt_CV',
    'CZK': 'cs_CZ',
    'DJF': 'fr_DJ',
    'DKK': 'da_DK',
    'DZD': 'ar_DZ',
    'EGP': 'ar_EG',
    'ETB': 'am_ET',
    'EUR': 'en_IE',
    'FJD': 'en_FJ',
    'FKP': 'en_FK',
    'GBP': 'en_GB',
    'GHS': 'en_GH',
    'GMD': 'en_GM',
    'GNF': 'fr_GN',
    'GTQ': 'es_GT',
    'GYD': 'en_GY',
    'HKD': 'zh_HK',
    'HNL': 'es_HN',
    'HTG': 'fr_HT',
    'HUF': 'hu_HU',
    'IDR': 'id_ID',
    'ILS': 'he_IL',
    'INR': 'en_IN',
    'IRR': 'fa_IR',
    'ISK': 'is_IS',
    'JOD': 'ar_JO',
    'JPY': 'ja_JP',
    'KES': 'en_KE',
    'KHR': 'km_KH',
    'KMF': 'fr_KM',
    'KPW': 'ko_KP',
    'KRW': 'ko_KR',
    'KWD': 'ar_KW',
    'LAK': 'lo_LA',
    'LKR': 'en_LK',
    'LRD': 'en_LR',
    'LSL': 'en_LS',
    'LYD': 'ar_LY',
    'MAD': 'fr_MA',
    'MDL': 'ro_MD',
    'MGA': 'fr_MG',
    'MKD': 'mk_MK',
    'MMK': 'my_MM',
    'MOP': 'zh_MO',
    'MRU': 'ar_MR',
    'MUR': 'en_MU',
    'MWK': 'en_MW',
    'MXN': 'es_MX',
    'MYR': 'ms_MY',
    'MZN': 'pt_MZ',
    'NAD': 'en_NA',
    'NGN': 'en_NG',
    'NIO': 'es_NI',
    'NOK': 'nb_NO',
    'NZD': 'en_NZ',
    'OMR': 'ar_OM',
    'PEN': 'es_PE',
    'PGK': 'en_PG',
    'PHP': 'en_PH',
    'PKR': 'en_PK',
    'PLN': 'pl_PL',
    'PYG': 'es_PY',
    'QAR': 'ar_QA',
    'RON': 'ro_RO',
    'RSD': 'sr_RS',
    'RUB': 'ru_RU',
    'RWF': 'en_RW',
    'SAR': 'ar_SA',
    'SBD': 'en_SB',
    'SCR': 'en_SC',
    'SDG': 'ar_SD',
    'SEK': 'sv_SE',
    'SGD': 'en_SG',
    'SHP': 'en_SH',
    'SLL': 'en_SL',
    'SOS': 'so_SO',
    'SRD': 'nl_SR',
    'SSP': 'en_SS',
    'STN': 'pt_ST',
    'SZL': 'en_SZ',
    'THB': 'th_TH',
    'TND': 'ar_TN',
    'TOP': 'en_TO',
    'TRY': 'tr_TR',
    'TWD': 'zh_TW',
    'TZS': 'sw_TZ',
    'UAH': 'uk_UA',
    'UGX': 'en_UG',
    'USD': 'en_US',
    'UYU': 'es_UY',
    'VES': 'es_VE',
    'VND': 'vi_VN',
    'VUV': 'en_VU',
    'WST': 'en_WS',
    'XAF': 'fr_CM',
    'XOF': 'fr_SN',
    'XPF': 'fr_PF',
    'ZAR': 'en_ZA',
    'ZMW': 'en_ZM',
  };

  static const Map<String, String> _phoneCodeToCurrency = {
    '971': 'AED',
    '966': 'SAR',
    '974': 'QAR',
    '973': 'BHD',
    '965': 'KWD',
    '968': 'OMR',
    '962': 'JOD',
    '972': 'ILS',
    '880': 'BDT',
    '886': 'TWD',
    '856': 'LAK',
    '855': 'KHR',
    '853': 'MOP',
    '852': 'HKD',
    '850': 'KPW',
    '692': 'USD',
    '691': 'USD',
    '689': 'XPF',
    '688': 'AUD',
    '687': 'XPF',
    '686': 'AUD',
    '685': 'WST',
    '683': 'NZD',
    '682': 'NZD',
    '681': 'XPF',
    '680': 'USD',
    '679': 'FJD',
    '678': 'VUV',
    '677': 'SBD',
    '676': 'TOP',
    '675': 'PGK',
    '673': 'BND',
    '670': 'USD',
    '599': 'USD',
    '598': 'UYU',
    '597': 'SRD',
    '596': 'EUR',
    '595': 'PYG',
    '594': 'EUR',
    '593': 'USD',
    '592': 'GYD',
    '591': 'BOB',
    '590': 'EUR',
    '509': 'HTG',
    '508': 'EUR',
    '507': 'USD',
    '506': 'CRC',
    '505': 'NIO',
    '504': 'HNL',
    '503': 'USD',
    '502': 'GTQ',
    '501': 'BZD',
    '500': 'FKP',
    '421': 'EUR',
    '420': 'CZK',
    '389': 'MKD',
    '387': 'BAM',
    '386': 'EUR',
    '385': 'EUR',
    '382': 'EUR',
    '381': 'RSD',
    '380': 'UAH',
    '377': 'EUR',
    '376': 'EUR',
    '375': 'BYN',
    '374': 'AMD',
    '373': 'MDL',
    '372': 'EUR',
    '371': 'EUR',
    '370': 'EUR',
    '359': 'BGN',
    '358': 'EUR',
    '357': 'EUR',
    '356': 'EUR',
    '355': 'ALL',
    '354': 'ISK',
    '353': 'EUR',
    '352': 'EUR',
    '351': 'EUR',
    '299': 'DKK',
    '298': 'DKK',
    '297': 'AWG',
    '290': 'SHP',
    '269': 'KMF',
    '268': 'SZL',
    '267': 'BWP',
    '266': 'LSL',
    '265': 'MWK',
    '264': 'NAD',
    '263': 'USD',
    '262': 'EUR',
    '261': 'MGA',
    '260': 'ZMW',
    '258': 'MZN',
    '257': 'BIF',
    '256': 'UGX',
    '255': 'TZS',
    '254': 'KES',
    '253': 'DJF',
    '252': 'SOS',
    '251': 'ETB',
    '250': 'RWF',
    '249': 'SDG',
    '248': 'SCR',
    '247': 'SHP',
    '246': 'USD',
    '245': 'XOF',
    '244': 'AOA',
    '243': 'CDF',
    '242': 'XAF',
    '241': 'XAF',
    '240': 'XAF',
    '239': 'STN',
    '238': 'CVE',
    '237': 'XAF',
    '236': 'XAF',
    '235': 'XAF',
    '234': 'NGN',
    '233': 'GHS',
    '232': 'SLL',
    '231': 'LRD',
    '230': 'MUR',
    '229': 'XOF',
    '228': 'XOF',
    '227': 'XOF',
    '226': 'XOF',
    '225': 'XOF',
    '224': 'GNF',
    '223': 'XOF',
    '222': 'MRU',
    '221': 'XOF',
    '220': 'GMD',
    '218': 'LYD',
    '216': 'TND',
    '213': 'DZD',
    '212': 'MAD',
    '211': 'SSP',
    '98': 'IRR',
    '95': 'MMK',
    '94': 'LKR',
    '93': 'AFN',
    '92': 'PKR',
    '91': 'INR',
    '90': 'TRY',
    '86': 'CNY',
    '84': 'VND',
    '82': 'KRW',
    '81': 'JPY',
    '66': 'THB',
    '65': 'SGD',
    '64': 'NZD',
    '63': 'PHP',
    '62': 'IDR',
    '61': 'AUD',
    '60': 'MYR',
    '58': 'VES',
    '57': 'COP',
    '56': 'CLP',
    '55': 'BRL',
    '54': 'ARS',
    '53': 'CUP',
    '52': 'MXN',
    '51': 'PEN',
    '49': 'EUR',
    '48': 'PLN',
    '47': 'NOK',
    '46': 'SEK',
    '45': 'DKK',
    '44': 'GBP',
    '43': 'EUR',
    '41': 'CHF',
    '40': 'RON',
    '39': 'EUR',
    '36': 'HUF',
    '34': 'EUR',
    '33': 'EUR',
    '32': 'EUR',
    '31': 'EUR',
    '30': 'EUR',
    '27': 'ZAR',
    '20': 'EGP',
    '7': 'RUB',
    '1': 'USD',
  };
}
