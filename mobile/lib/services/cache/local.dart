import 'dart:convert';

import 'package:hive/hive.dart';

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
  static const _shopLogoCacheBustKey = 'shop_logo_cache_bust';

  static Future<void> init() async {
    await Hive.openBox<String>(_receiptsBox);
    await Hive.openBox<String>(_receiptDetailBox);
    await Hive.openBox<String>(_salesDraftBox);
    await Hive.openBox<bool>(_settingsBox);
    await Hive.openBox<int>(_metaBox);
    await Hive.openBox<String>(_pageBox);
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

  static int getShopLogoCacheBust() {
    final box = Hive.box<int>(_metaBox);
    return box.get(_shopLogoCacheBustKey) ?? 0;
  }

  static Future<void> setShopLogoCacheBust(int value) async {
    final box = Hive.box<int>(_metaBox);
    await box.put(_shopLogoCacheBustKey, value);
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
    required List<Map<String, dynamic>> sales,
    required int page,
    required bool hasMore,
  }) async {
    final box = Hive.box<String>(_pageBox);
    final key = includeItems ? 'items_page' : 'sales_page';
    await box.put(
      key,
      jsonEncode({'sales': sales, 'page': page, 'has_more': hasMore}),
    );
  }

  static Map<String, dynamic>? loadSalesPage({required bool includeItems}) {
    final box = Hive.box<String>(_pageBox);
    final key = includeItems ? 'items_page' : 'sales_page';
    final raw = box.get(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
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
