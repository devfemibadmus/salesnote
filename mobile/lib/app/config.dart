class AppConfig {
  // static const apiBaseUrl = 'https://unwrathful-clayton-unplowed.ngrok-free.dev';
  static const apiBaseUrl = 'https://api.salesnote.online';
  static const privacyPolicyUrl = 'https://salesnote.online';
  static const termsOfServiceUrl = 'https://salesnote.online';
  static const supportUrl = 'https://salesnote.online';
  static const apptUrl = 'https://app.salesnote.online';
  static const flagIconBaseUrl = 'https://flagpedia.net/data/flags/icon';
  static const defaultFlagIconSize = '72x54';
  static const Map<String, String> liveCashierCueUrls = <String, String>{
    'action_started':
        'https://github.com/5a9awneh/ms-teams-sounds/raw/refs/heads/main/Notifications/Vibe.mp3',
    'reconnecting':
        'https://github.com/5a9awneh/ms-teams-sounds/raw/refs/heads/main/Notifications/Pluck.mp3',
    'reconnected':
        'https://github.com/5a9awneh/ms-teams-sounds/raw/refs/heads/main/Notifications/Nudge.mp3',
    'session_closed':
        'https://github.com/5a9awneh/ms-teams-sounds/raw/refs/heads/main/Notifications/Pluck.mp3',
    'mic_muted': 'https://soundcn.xyz/r/switch-off.json',
    'mic_unmuted': 'https://soundcn.xyz/r/switch-on.json',
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
