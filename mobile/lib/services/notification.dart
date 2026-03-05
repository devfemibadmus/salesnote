import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/navigator.dart';
import '../app/routes.dart';
import 'cache/local.dart';

class InAppNotification {
  const InAppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAtMillis,
    required this.isRead,
  });

  final String id;
  final String title;
  final String body;
  final String kind;
  final int createdAtMillis;
  final bool isRead;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'kind': kind,
    'created_at_millis': createdAtMillis,
    'is_read': isRead,
  };

  static InAppNotification fromJson(Map<String, dynamic> json) {
    return InAppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Salesnote',
      body: json['body']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'general',
      createdAtMillis:
          int.tryParse(json['created_at_millis']?.toString() ?? '') ??
          DateTime.now().millisecondsSinceEpoch,
      isRead: json['is_read'] == true,
    );
  }
}

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'salesnote_alerts_v1',
    'Salesnote Notifications',
    description: 'Default channel for Salesnote notifications',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('salesnote_notification'),
  );

  static Future<void> init() async {
    if (_initialized) {
      return;
    }
    _refreshUnreadCount();
    await _initLocalNotifications();
    await _initFirebaseMessaging();
    _initialized = true;
  }

  static Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationPayload(response.payload);
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channel);
  }

  static Future<void> _initFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) async {
      await _saveIncomingNotification(message.data, message.notification);
      await _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _saveIncomingNotification(message.data, message.notification);
      _handleNotificationData(message.data, message.notification);
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      await _saveIncomingNotification(
        initialMessage.data,
        initialMessage.notification,
      );
      _handleNotificationData(initialMessage.data, initialMessage.notification);
    }
  }

  static Future<void> subscribe() async {
    await requestPermission();
  }

  static Future<AuthorizationStatus> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus;
  }

  static Future<AuthorizationStatus> getPermissionStatus() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus;
  }

  static Future<bool> hasGrantedPermission() async {
    final status = await getPermissionStatus();
    return isPermissionGranted(status);
  }

  static bool isPermissionGranted(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  static Future<bool> ensurePermissionEnabled(BuildContext context) async {
    await init();
    var status = await getPermissionStatus();
    if (isPermissionGranted(status)) {
      return true;
    }

    if (!context.mounted) {
      return false;
    }
    final allow = await showPermissionPrompt(context);
    if (!allow) {
      return false;
    }

    status = await requestPermission();
    return isPermissionGranted(status);
  }

  static Future<String?> getDeviceToken() async {
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    final apnsReady = await _waitForApnsTokenIfNeeded();
    if (!apnsReady) return null;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      return token;
    } catch (e) {
      if (_isApnsNotReadyError(e)) return null;
      rethrow;
    }
  }

  static Future<String?> getDeviceTokenWithRetry({
    int attempts = 8,
    Duration delay = const Duration(seconds: 1),
  }) async {
    Object? lastError;
    for (var i = 0; i < attempts; i++) {
      try {
        final token = await getDeviceToken();
        if (token != null && token.trim().isNotEmpty) {
          return token;
        }
      } catch (e) {
        lastError = e;
        if (kDebugMode) {
          debugPrint('FCM token attempt ${i + 1}/$attempts failed: $e');
        }
      }
      if (i < attempts - 1) {
        await Future.delayed(delay);
      }
    }
    if (lastError != null && !_isApnsNotReadyError(lastError)) {
      throw lastError;
    }
    return null;
  }

  /// Returns true if the APNS token is available (or not needed).
  static Future<bool> _waitForApnsTokenIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return true;
    for (var i = 0; i < 20; i++) {
      try {
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns != null && apns.trim().isNotEmpty) return true;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('APNS token check #${i + 1} error: $e');
        }
      }
      if (i < 19) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    if (kDebugMode) {
      debugPrint('APNS token was not received after 10 s — skipping FCM token');
    }
    return false;
  }

  static bool _isApnsNotReadyError(Object error) {
    return error.toString().toLowerCase().contains('apns-token-not-set');
  }

  static Future<void> clearLocalState() async {
    unreadCount.value = 0;
    await _localNotifications.cancelAll();
  }

  static List<InAppNotification> loadInbox() {
    final raw = LocalCache.loadNotifications();
    return raw.map(InAppNotification.fromJson).toList();
  }

  static Future<void> markAllRead() async {
    final list = loadInbox();
    final next = list
        .map(
          (n) => InAppNotification(
            id: n.id,
            title: n.title,
            body: n.body,
            kind: n.kind,
            createdAtMillis: n.createdAtMillis,
            isRead: true,
          ),
        )
        .toList();
    await LocalCache.saveNotifications(next.map((e) => e.toJson()).toList());
    _refreshUnreadCount();
  }

  static Future<void> markRead(String id) async {
    final list = loadInbox();
    var changed = false;
    final next = list.map((n) {
      if (n.id != id || n.isRead) return n;
      changed = true;
      return InAppNotification(
        id: n.id,
        title: n.title,
        body: n.body,
        kind: n.kind,
        createdAtMillis: n.createdAtMillis,
        isRead: true,
      );
    }).toList();
    if (!changed) return;
    await LocalCache.saveNotifications(next.map((e) => e.toJson()).toList());
    _refreshUnreadCount();
  }

  static Future<bool> showPermissionPrompt(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xFF6B7280).withValues(alpha: 0.55),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCE7F3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications,
                  size: 40,
                  color: Color(0xFF007AFF),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'STAY UPDATED',
                style: TextStyle(
                  fontSize: 18,
                  letterSpacing: 1.2,
                  color: Color(0xFF007AFF),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enable Notifications',
                style: TextStyle(
                  fontSize: 21,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Get daily insights on your shop's performance. We'll notify you how today's sales compare to yesterday and how your week is going.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.45,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 62,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Allow Notifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Not now',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? 'Salesnote';
    final body = notification?.body ?? '';
    final payload = _encodePayload(message.data, title, body);

    const androidDetails = AndroidNotificationDetails(
      'salesnote_alerts_v1',
      'Salesnote Notifications',
      channelDescription: 'Default channel for Salesnote notifications',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('salesnote_notification'),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      sound: 'salesnote_notification.caf',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  static void _handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }
    try {
      final data = Map<String, dynamic>.from(Uri.splitQueryString(payload));
      _handleNotificationData(data, null);
    } catch (_) {}
  }

  static void _handleNotificationData(
    Map<String, dynamic> data,
    RemoteNotification? notification,
  ) {
    final navigator = AppNavigator.key.currentState;
    if (navigator == null) {
      return;
    }

    navigator.pushNamed(AppRoutes.notification);
  }

  static String _encodePayload(
    Map<String, dynamic> data,
    String title,
    String body,
  ) {
    final merged = {...data, 'title': title, 'body': body};
    return Uri(
      queryParameters: merged.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    ).query;
  }

  static Future<void> _saveIncomingNotification(
    Map<String, dynamic> data,
    RemoteNotification? notification,
  ) async {
    final title =
        data['title']?.toString() ?? notification?.title ?? 'Salesnote';
    final body = data['body']?.toString() ?? notification?.body ?? '';
    final kind = data['type']?.toString() ?? 'general';
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = data['id']?.toString() ?? '${now}_${title.hashCode}';

    final list = loadInbox();
    final next = <InAppNotification>[
      InAppNotification(
        id: id,
        title: title,
        body: body,
        kind: kind,
        createdAtMillis: now,
        isRead: false,
      ),
      ...list.where((e) => e.id != id),
    ];

    if (next.length > 200) {
      next.removeRange(200, next.length);
    }

    await LocalCache.saveNotifications(next.map((e) => e.toJson()).toList());
    _refreshUnreadCount();
  }

  static void _refreshUnreadCount() {
    final count = loadInbox().where((e) => !e.isRead).length;
    unreadCount.value = count;
  }
}
