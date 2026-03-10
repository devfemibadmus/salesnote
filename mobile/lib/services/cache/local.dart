import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models.dart';

class LocalCache {
  static const _receiptsBox = 'receipts_cache';
  static const _receiptDetailBox = 'receipt_detail_cache';
  static const _salesDraftBox = 'sales_draft_cache';
  static const _settingsBox = 'settings_cache';
  static const _metaBox = 'meta_cache';
  static const _pageBox = 'page_cache';
  static const _onboardingKey = 'onboarding_complete';
  static const _notificationPromptCooldownKey = 'notification_prompt_cooldown';
  static const _notificationOptOutKey = 'notification_opt_out';
  static const _preferredRegionCodeKey = 'preferred_region_code';
  static const _cacheSchemaVersionKey = 'cache_schema_version';
  static const _cacheSchemaVersion = 3;
  static Future<void>? _initFuture;
  static const _allBoxes = <String>[
    _receiptsBox,
    _receiptDetailBox,
    _salesDraftBox,
    _settingsBox,
    _metaBox,
    _pageBox,
  ];

  static Future<void> init() async {
    _initFuture ??= _initializeWithRecovery().catchError((error) {
      _initFuture = null;
      throw error;
    });
    return _initFuture!;
  }

  static Future<void> _initializeWithRecovery() async {
    await _migrateCacheSchemaIfNeeded();
    try {
      await _openAllBoxes();
    } catch (_) {
      await _deleteAllHiveArtifacts();
      await _openAllBoxes();
    }
  }

  static Future<void> _migrateCacheSchemaIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_cacheSchemaVersionKey) ?? 0;
    if (storedVersion == _cacheSchemaVersion) {
      return;
    }

    await _deleteAllHiveArtifacts();
    await prefs.setInt(_cacheSchemaVersionKey, _cacheSchemaVersion);
  }

  static Future<void> _openAllBoxes() async {
    await _openBoxSafely<String>(_receiptsBox);
    await _openBoxSafely<String>(_receiptDetailBox);
    await _openBoxSafely<String>(_salesDraftBox);
    await _openBoxSafely<bool>(_settingsBox);
    await _openBoxSafely<int>(_metaBox);
    await _openBoxSafely<String>(_pageBox);
  }

  static Future<void> _openBoxSafely<T>(String name) async {
    if (Hive.isBoxOpen(name)) return;

    try {
      await Hive.openBox<T>(name);
    } catch (error) {
      // Recover from incompatible or corrupted on-device Hive boxes left by older builds.
      await _deleteAllHiveArtifacts();
      await Hive.openBox<T>(name);
    }
  }

  static Future<void> _deleteBoxFiles(String name) async {
    final directory = await getApplicationDocumentsDirectory();
    final normalized = name.toLowerCase();
    await for (final entry in directory.list(followLinks: false)) {
      final fileName = entry.uri.pathSegments.isEmpty
          ? ''
          : entry.uri.pathSegments.last.toLowerCase();
      if (!fileName.startsWith(normalized)) {
        continue;
      }

      try {
        if (entry is File) {
          if (await entry.exists()) {
            await entry.delete();
          }
        } else if (entry is Directory) {
          if (await entry.exists()) {
            await entry.delete(recursive: true);
          }
        }
      } catch (_) {}
    }
  }

  static Future<void> _deleteAllHiveArtifacts() async {
    for (final name in _allBoxes) {
      await _deleteBoxFiles(name);
    }

    final directory = await getApplicationDocumentsDirectory();
    await for (final entry in directory.list(followLinks: false)) {
      final fileName = entry.uri.pathSegments.isEmpty
          ? ''
          : entry.uri.pathSegments.last.toLowerCase();
      final isHiveArtifact =
          fileName.endsWith('.hive') ||
          fileName.endsWith('.hivec') ||
          fileName.endsWith('.lock');
      if (!isHiveArtifact) {
        continue;
      }

      try {
        if (entry is File) {
          if (await entry.exists()) {
            await entry.delete();
          }
        } else if (entry is Directory) {
          if (await entry.exists()) {
            await entry.delete(recursive: true);
          }
        }
      } catch (_) {}
    }
  }

  static Future<void> saveReceipts(List<Map<String, dynamic>> receipts) async {
    final box = Hive.box<String>(_receiptsBox);
    await box.put('list', jsonEncode(receipts));
  }

  static List<Map<String, dynamic>> loadReceipts() {
    final box = Hive.box<String>(_receiptsBox);
    final raw = box.get('list');
    if (raw == null) return [];
    final data = jsonDecode(raw) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  static Future<void> saveReceiptDetail(
    String id,
    Map<String, dynamic> detail,
  ) async {
    final box = Hive.box<String>(_receiptDetailBox);
    await box.put(id, jsonEncode(detail));
  }

  static Map<String, dynamic>? loadReceiptDetail(String id) {
    final box = Hive.box<String>(_receiptDetailBox);
    final raw = box.get(id);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> saveDraft(String key, Map<String, dynamic> draft) async {
    final box = Hive.box<String>(_salesDraftBox);
    await box.put(key, jsonEncode(draft));
  }

  static Map<String, dynamic>? loadDraft(String key) {
    final box = Hive.box<String>(_salesDraftBox);
    final raw = box.get(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> clearDraft(String key) async {
    final box = Hive.box<String>(_salesDraftBox);
    await box.delete(key);
  }

  static Future<bool> isOnboardingComplete() async {
    final box = Hive.box<bool>(_settingsBox);
    return box.get(_onboardingKey) ?? false;
  }

  static Future<void> setOnboardingComplete(bool value) async {
    final box = Hive.box<bool>(_settingsBox);
    await box.put(_onboardingKey, value);
  }

  static Future<int> getNotificationPromptCooldown() async {
    final box = Hive.box<int>(_metaBox);
    return box.get(_notificationPromptCooldownKey) ?? 0;
  }

  static Future<void> setNotificationPromptCooldown(int value) async {
    final box = Hive.box<int>(_metaBox);
    await box.put(_notificationPromptCooldownKey, value < 0 ? 0 : value);
  }

  static Future<bool> isNotificationOptedOut() async {
    final box = Hive.box<bool>(_settingsBox);
    return box.get(_notificationOptOutKey) ?? false;
  }

  static Future<void> setNotificationOptedOut(bool value) async {
    final box = Hive.box<bool>(_settingsBox);
    await box.put(_notificationOptOutKey, value);
  }

  static String? getPreferredRegionCode() {
    final box = Hive.box<String>(_pageBox);
    final value = box.get(_preferredRegionCodeKey)?.trim().toUpperCase();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static Future<void> setPreferredRegionCode(String? code) async {
    final box = Hive.box<String>(_pageBox);
    final normalized = code?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) {
      await box.delete(_preferredRegionCodeKey);
      return;
    }
    await box.put(_preferredRegionCodeKey, normalized);
  }

  static Future<void> saveHomeSummary(Map<String, dynamic> data) async {
    final box = Hive.box<String>(_pageBox);
    await box.put('home_summary', jsonEncode(data));
  }

  static Map<String, dynamic>? loadHomeSummary() {
    final box = Hive.box<String>(_pageBox);
    final raw = box.get('home_summary');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> saveSalesPage({
    required bool includeItems,
    SaleStatus? status,
    required List<Map<String, dynamic>> sales,
    required int page,
    required bool hasMore,
  }) async {
    final box = Hive.box<String>(_pageBox);
    final key = _salesPageKey(includeItems: includeItems, status: status);
    await box.put(
      key,
      jsonEncode({'sales': sales, 'page': page, 'has_more': hasMore}),
    );
  }

  static Map<String, dynamic>? loadSalesPage({
    required bool includeItems,
    SaleStatus? status,
  }) {
    final box = Hive.box<String>(_pageBox);
    final key = _salesPageKey(includeItems: includeItems, status: status);
    final raw = box.get(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static String _salesPageKey({
    required bool includeItems,
    SaleStatus? status,
  }) {
    final prefix = includeItems ? 'items_page' : 'sales_page';
    final suffix = status == null ? 'all' : status.name;
    return '${prefix}_$suffix';
  }

  static Future<void> saveSettingsSummary(Map<String, dynamic> data) async {
    final box = Hive.box<String>(_pageBox);
    await box.put('settings_summary', jsonEncode(data));
  }

  static Map<String, dynamic>? loadSettingsSummary() {
    final box = Hive.box<String>(_pageBox);
    final raw = box.get('settings_summary');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> saveSignatures(
    List<Map<String, dynamic>> signatures,
  ) async {
    final box = Hive.box<String>(_pageBox);
    await box.put('signatures', jsonEncode(signatures));
  }

  static List<Map<String, dynamic>> loadSignatures() {
    final box = Hive.box<String>(_pageBox);
    final raw = box.get('signatures');
    if (raw == null) return <Map<String, dynamic>>[];
    final data = jsonDecode(raw) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  static Future<void> saveNotifications(
    List<Map<String, dynamic>> notifications,
  ) async {
    final box = Hive.box<String>(_pageBox);
    await box.put('notifications', jsonEncode(notifications));
  }

  static List<Map<String, dynamic>> loadNotifications() {
    final box = Hive.box<String>(_pageBox);
    final raw = box.get('notifications');
    if (raw == null) return <Map<String, dynamic>>[];
    final data = jsonDecode(raw) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  static Future<void> saveSalePreview(
    String saleId,
    Map<String, dynamic> sale,
  ) async {
    final box = Hive.box<String>(_pageBox);
    await box.put('sale_preview_$saleId', jsonEncode(sale));
  }

  static Map<String, dynamic>? loadSalePreview(String saleId) {
    final box = Hive.box<String>(_pageBox);
    final raw = box.get('sale_preview_$saleId');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> saveItemSuggestions(List<String> names) async {
    final box = Hive.box<String>(_pageBox);
    final normalized =
        names.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    await box.put('item_suggestions', jsonEncode(normalized));
  }

  static List<String> loadItemSuggestions() {
    final box = Hive.box<String>(_pageBox);
    final raw = box.get('item_suggestions');
    if (raw == null) return <String>[];
    final data = jsonDecode(raw) as List<dynamic>;
    return data
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static Future<void> saveCachedMedia(String url, Uint8List bytes) async {
    if (url.trim().isEmpty || bytes.isEmpty) return;
    final box = Hive.box<String>(_pageBox);
    await box.put('media:${url.trim()}', base64Encode(bytes));
  }

  static Uint8List? loadCachedMedia(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) return null;
    final box = Hive.box<String>(_pageBox);
    final raw = box.get('media:$normalized');
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteCachedMedia(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty) return;
    final box = Hive.box<String>(_pageBox);
    await box.delete('media:$normalized');
  }

  static Future<void> clearAll() async {
    final settingsBox = Hive.box<bool>(_settingsBox);
    final onboardingComplete = settingsBox.get(_onboardingKey) ?? false;
    final notificationOptOut = settingsBox.get(_notificationOptOutKey) ?? false;

    await Hive.box<String>(_receiptsBox).clear();
    await Hive.box<String>(_receiptDetailBox).clear();
    await Hive.box<String>(_salesDraftBox).clear();
    await settingsBox.clear();
    await Hive.box<int>(_metaBox).clear();
    await Hive.box<String>(_pageBox).clear();

    if (onboardingComplete) {
      await settingsBox.put(_onboardingKey, true);
    }
    if (notificationOptOut) {
      await settingsBox.put(_notificationOptOutKey, true);
    }
  }

}
