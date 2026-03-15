class PagingConstants {
  PagingConstants._();

  static const listPerPage = 20;
  static const filteredListPerPage = 200;
  static const newSaleRefreshPerPage = 20;
  static const liveCashierSalesWindowPerPage = 100;
  static const liveCashierSalesWindowMaxPages = 15;
}

class TimingConstants {
  TimingConstants._();

  static const secureStorageTimeout = Duration(seconds: 3);
  static const startupFlagWarmTimeout = Duration(seconds: 20);
  static const liveCashierCueNetworkTimeout = Duration(seconds: 8);
  static const liveCashierCueActionCooldown = Duration(milliseconds: 700);
  static const liveCashierCueReconnectingCooldown = Duration(seconds: 3);
  static const liveCashierCueReconnectedCooldown = Duration(milliseconds: 900);
  static const liveCashierCueMicToggleCooldown = Duration(milliseconds: 200);
  static const liveCashierSocketPingInterval = Duration(seconds: 20);
  static const liveCashierSalesWindowCacheTtl = Duration(seconds: 12);
}

class LimitConstants {
  LimitConstants._();

  static const liveCashierSalesWindowCacheMaxEntries = 12;
  static const newSaleMaxAmount = 9_999_999_999.99;
}

class NotificationConstants {
  NotificationConstants._();

  static const legacyChannelId = 'salesnote_alerts_v1';
  static const channelId = 'salesnote_alerts_v2';
  static const channelName = 'Salesnote Notifications';
  static const channelDescription =
      'Default channel for Salesnote notifications';
}
