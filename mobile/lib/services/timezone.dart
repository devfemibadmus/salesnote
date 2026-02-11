import 'package:flutter_timezone/flutter_timezone.dart';

class TimezoneService {
  static String? _cached;

  static Future<String> getDeviceTimezone() async {
    if (_cached != null && _cached!.isNotEmpty) {
      return _cached!;
    }
    final tz = await FlutterTimezone.getLocalTimezone();
    final identifier = tz.identifier;
    if (identifier.isEmpty) {
      throw Exception('Unable to detect device timezone.');
    }
    _cached = identifier;
    return identifier;
  }
}
