class AppConfig {
  static const apiBaseUrl =
      'https://unwrathful-clayton-unplowed.ngrok-free.dev';
  // static const apiBaseUrl = 'https://api.salesnote.online';
  static const privacyPolicyUrl = 'https://salesnote.online';
  static const termsOfServiceUrl = 'https://salesnote.online';
  static const supportUrl = 'https://salesnote.online';
  static const apptUrl = 'https://app.salesnote.online';
  static const flagIconBaseUrl = 'https://flagpedia.net/data/flags/icon';
  static const defaultFlagIconSize = '72x54';
  static const Map<String, String> liveCashierCueUrls = <String, String>{
    'action_started': 'https://soundcn.xyz/r/zap-two-tone.json',
    'reconnecting': 'https://soundcn.xyz/r/zap-three-tone-down.json',
    'reconnected': 'https://soundcn.xyz/r/zap-three-tone-up.json',
  };

  static Uri get apiBaseUri => Uri.parse(apiBaseUrl);

  static bool get usesNgrokTunnel =>
      apiBaseUri.host.toLowerCase().contains('ngrok');

  static String flagIconUrl(
    String countryCode, {
    String size = defaultFlagIconSize,
  }) {
    final code = countryCode.trim().toLowerCase();
    return '$flagIconBaseUrl/$size/$code.png';
  }

  static Map<String, String> get defaultRequestHeaders => usesNgrokTunnel
      ? const {'ngrok-skip-browser-warning': '1'}
      : const <String, String>{};
}
