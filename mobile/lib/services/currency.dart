import 'package:intl/intl.dart';

import 'region.dart';

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

  static String? _resolveCurrencyCode() {
    final region = RegionService.resolveAccountRegionCode();
    final byRegion = _regionToCurrency[region];
    if (byRegion != null && byRegion.isNotEmpty) {
      return byRegion;
    }

    return null;
  }

  static String _currentLocale() {
    final region = RegionService.resolveAccountRegionCode();
    return 'en_$region';
  }

  static String _currencySymbol(String code) {
    try {
      final symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;
      return symbol.isEmpty ? code : symbol;
    } catch (_) {
      return code;
    }
  }

  // ISO-3166 region code => ISO-4217 currency code
  static const Map<String, String> _regionToCurrency = {
    'AD': 'EUR',
    'AE': 'AED',
    'AF': 'AFN',
    'AG': 'XCD',
    'AI': 'XCD',
    'AL': 'ALL',
    'AM': 'AMD',
    'AO': 'AOA',
    'AR': 'ARS',
    'AS': 'USD',
    'AT': 'EUR',
    'AU': 'AUD',
    'AW': 'AWG',
    'AX': 'EUR',
    'AZ': 'AZN',
    'BA': 'BAM',
    'BB': 'BBD',
    'BD': 'BDT',
    'BE': 'EUR',
    'BF': 'XOF',
    'BG': 'BGN',
    'BH': 'BHD',
    'BI': 'BIF',
    'BJ': 'XOF',
    'BL': 'EUR',
    'BM': 'BMD',
    'BN': 'BND',
    'BO': 'BOB',
    'BQ': 'USD',
    'BR': 'BRL',
    'BS': 'BSD',
    'BT': 'BTN',
    'BV': 'NOK',
    'BW': 'BWP',
    'BY': 'BYN',
    'BZ': 'BZD',
    'CA': 'CAD',
    'CC': 'AUD',
    'CD': 'CDF',
    'CF': 'XAF',
    'CG': 'XAF',
    'CH': 'CHF',
    'CI': 'XOF',
    'CK': 'NZD',
    'CL': 'CLP',
    'CM': 'XAF',
    'CN': 'CNY',
    'CO': 'COP',
    'CR': 'CRC',
    'CU': 'CUP',
    'CV': 'CVE',
    'CW': 'ANG',
    'CX': 'AUD',
    'CY': 'EUR',
    'CZ': 'CZK',
    'DE': 'EUR',
    'DJ': 'DJF',
    'DK': 'DKK',
    'DM': 'XCD',
    'DO': 'DOP',
    'DZ': 'DZD',
    'EC': 'USD',
    'EE': 'EUR',
    'EG': 'EGP',
    'EH': 'MAD',
    'ER': 'ERN',
    'ES': 'EUR',
    'ET': 'ETB',
    'FI': 'EUR',
    'FJ': 'FJD',
    'FK': 'FKP',
    'FM': 'USD',
    'FO': 'DKK',
    'FR': 'EUR',
    'GA': 'XAF',
    'GB': 'GBP',
    'GD': 'XCD',
    'GE': 'GEL',
    'GF': 'EUR',
    'GG': 'GBP',
    'GH': 'GHS',
    'GI': 'GIP',
    'GL': 'DKK',
    'GM': 'GMD',
    'GN': 'GNF',
    'GP': 'EUR',
    'GQ': 'XAF',
    'GR': 'EUR',
    'GS': 'GBP',
    'GT': 'GTQ',
    'GU': 'USD',
    'GW': 'XOF',
    'GY': 'GYD',
    'HK': 'HKD',
    'HM': 'AUD',
    'HN': 'HNL',
    'HR': 'EUR',
    'HT': 'HTG',
    'HU': 'HUF',
    'ID': 'IDR',
    'IE': 'EUR',
    'IL': 'ILS',
    'IM': 'GBP',
    'IN': 'INR',
    'IO': 'USD',
    'IQ': 'IQD',
    'IR': 'IRR',
    'IS': 'ISK',
    'IT': 'EUR',
    'JE': 'GBP',
    'JM': 'JMD',
    'JO': 'JOD',
    'JP': 'JPY',
    'KE': 'KES',
    'KG': 'KGS',
    'KH': 'KHR',
    'KI': 'AUD',
    'KM': 'KMF',
    'KN': 'XCD',
    'KP': 'KPW',
    'KR': 'KRW',
    'KW': 'KWD',
    'KY': 'KYD',
    'KZ': 'KZT',
    'LA': 'LAK',
    'LB': 'LBP',
    'LC': 'XCD',
    'LI': 'CHF',
    'LK': 'LKR',
    'LR': 'LRD',
    'LS': 'LSL',
    'LT': 'EUR',
    'LU': 'EUR',
    'LV': 'EUR',
    'LY': 'LYD',
    'MA': 'MAD',
    'MC': 'EUR',
    'MD': 'MDL',
    'ME': 'EUR',
    'MF': 'EUR',
    'MG': 'MGA',
    'MH': 'USD',
    'MK': 'MKD',
    'ML': 'XOF',
    'MM': 'MMK',
    'MN': 'MNT',
    'MO': 'MOP',
    'MP': 'USD',
    'MQ': 'EUR',
    'MR': 'MRU',
    'MS': 'XCD',
    'MT': 'EUR',
    'MU': 'MUR',
    'MV': 'MVR',
    'MW': 'MWK',
    'MX': 'MXN',
    'MY': 'MYR',
    'MZ': 'MZN',
    'NA': 'NAD',
    'NC': 'XPF',
    'NE': 'XOF',
    'NF': 'AUD',
    'NG': 'NGN',
    'NI': 'NIO',
    'NL': 'EUR',
    'NO': 'NOK',
    'NP': 'NPR',
    'NR': 'AUD',
    'NU': 'NZD',
    'NZ': 'NZD',
    'OM': 'OMR',
    'PA': 'PAB',
    'PE': 'PEN',
    'PF': 'XPF',
    'PG': 'PGK',
    'PH': 'PHP',
    'PK': 'PKR',
    'PL': 'PLN',
    'PM': 'EUR',
    'PN': 'NZD',
    'PR': 'USD',
    'PS': 'ILS',
    'PT': 'EUR',
    'PW': 'USD',
    'PY': 'PYG',
    'QA': 'QAR',
    'RE': 'EUR',
    'RO': 'RON',
    'RS': 'RSD',
    'RU': 'RUB',
    'RW': 'RWF',
    'SA': 'SAR',
    'SB': 'SBD',
    'SC': 'SCR',
    'SD': 'SDG',
    'SE': 'SEK',
    'SG': 'SGD',
    'SH': 'SHP',
    'SI': 'EUR',
    'SJ': 'NOK',
    'SK': 'EUR',
    'SL': 'SLE',
    'SM': 'EUR',
    'SN': 'XOF',
    'SO': 'SOS',
    'SR': 'SRD',
    'SS': 'SSP',
    'ST': 'STN',
    'SV': 'USD',
    'SX': 'ANG',
    'SY': 'SYP',
    'SZ': 'SZL',
    'TC': 'USD',
    'TD': 'XAF',
    'TF': 'EUR',
    'TG': 'XOF',
    'TH': 'THB',
    'TJ': 'TJS',
    'TK': 'NZD',
    'TL': 'USD',
    'TM': 'TMT',
    'TN': 'TND',
    'TO': 'TOP',
    'TR': 'TRY',
    'TT': 'TTD',
    'TV': 'AUD',
    'TW': 'TWD',
    'TZ': 'TZS',
    'UA': 'UAH',
    'UG': 'UGX',
    'UM': 'USD',
    'US': 'USD',
    'UY': 'UYU',
    'UZ': 'UZS',
    'VA': 'EUR',
    'VC': 'XCD',
    'VE': 'VES',
    'VG': 'USD',
    'VI': 'USD',
    'VN': 'VND',
    'VU': 'VUV',
    'WF': 'XPF',
    'WS': 'WST',
    'XK': 'EUR',
    'YE': 'YER',
    'YT': 'EUR',
    'ZA': 'ZAR',
    'ZM': 'ZMW',
    'ZW': 'USD',
  };
}
