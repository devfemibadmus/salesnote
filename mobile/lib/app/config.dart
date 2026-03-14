class AppConfig {
  static const apiBaseUrl =
      'https://unwrathful-clayton-unplowed.ngrok-free.dev';
  // static const apiBaseUrl = 'https://api.salesnote.online';
  static const privacyPolicyUrl = 'https://salesnote.online';
  static const termsOfServiceUrl = 'https://salesnote.online';
  static const supportUrl = 'https://salesnote.online';
  static const apptUrl = 'https://app.salesnote.online';

  static Uri get apiBaseUri => Uri.parse(apiBaseUrl);

  static bool get usesNgrokTunnel =>
      apiBaseUri.host.toLowerCase().contains('ngrok');

  static Map<String, String> get defaultRequestHeaders => usesNgrokTunnel
      ? const {'ngrok-skip-browser-warning': '1'}
      : const <String, String>{};
}
