class StorageBoxes {
  StorageBoxes._();

  static const receipts = 'receipts_cache';
  static const receiptDetail = 'receipt_detail_cache';
  static const salesDraft = 'sales_draft_cache';
  static const settings = 'settings_cache';
  static const meta = 'meta_cache';
  static const page = 'page_cache';

  static const all = <String>[
    receipts,
    receiptDetail,
    salesDraft,
    settings,
    meta,
    page,
  ];
}

class StorageKeys {
  StorageKeys._();

  static const onboardingComplete = 'onboarding_complete';
  static const notificationPromptCooldown = 'notification_prompt_cooldown';
  static const notificationOptOut = 'notification_opt_out';
  static const preferredRegionCode = 'preferred_region_code';
  static const preferredCurrencyCode = 'preferred_currency_code';
  static const cacheSchemaVersion = 'cache_schema_version';
  static const homeSummary = 'home_summary';
  static const settingsSummary = 'settings_summary';
  static const signatures = 'signatures';
  static const notifications = 'notifications';
  static const itemSuggestions = 'item_suggestions';
  static const liveCashierActionHistory = 'live_cashier_action_history';
  static const flagCacheVersion = 'flag_cache_version';

  static String salesPagePrefix({required bool includeItems}) =>
      includeItems ? 'items_page' : 'sales_page';

  static String salePreview(String saleId) => 'sale_preview_$saleId';

  static String cachedMedia(String url) => 'media:$url';
}

class StorageVersions {
  StorageVersions._();

  static const cacheSchema = 3;
  static const flagCache = 1;
}

class TokenStoreConstants {
  TokenStoreConstants._();

  static const tokenKey = 'auth_token';
  static const sessionKey = 'has_auth_session';
}

class DraftConstants {
  DraftConstants._();

  static const legacyNewSaleDraftKey = 'draft_new_sale';
  static const newSaleDraftIndexKey = 'draft_new_sale_index';
  static const newSaleDraftStoragePrefix = 'draft_new_sale_';
  static const newSaleDefaultDraftId = 'draft_1';
  static const newSaleDefaultDraftLabel = 'New Sale';
  static const newSaleDefaultOtherLabel = 'Others';
}
