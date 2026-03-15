part of '../models.dart';

class AnalyticsPoint {
  AnalyticsPoint({
    required this.period,
    required this.total,
    required this.units,
  });

  final String period;
  final double total;
  final double units;

  factory AnalyticsPoint.fromJson(dynamic json) {
    return AnalyticsPoint(
      period: json['period'] as String,
      total: (json['total'] as num).toDouble(),
      units: (json['units'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'period': period,
    'total': total,
    'units': units,
  };
}

class ProductMovement {
  ProductMovement({
    required this.productName,
    required this.quantity,
    required this.sold30Days,
  });

  final String productName;
  final double quantity;
  final double sold30Days;

  factory ProductMovement.fromJson(dynamic json) {
    final quantity = (json['quantity'] as num).toDouble();
    return ProductMovement(
      productName: json['product_name'] as String,
      quantity: quantity,
      sold30Days: (json['sold_30_days'] as num?)?.toDouble() ?? quantity,
    );
  }

  Map<String, dynamic> toJson() => {
    'product_name': productName,
    'quantity': quantity,
    'sold_30_days': sold30Days,
  };
}

class AnalyticsSummary {
  AnalyticsSummary({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.fastMoving,
    required this.slowMoving,
  });

  final List<AnalyticsPoint> daily;
  final List<AnalyticsPoint> weekly;
  final List<AnalyticsPoint> monthly;
  final List<ProductMovement> fastMoving;
  final List<ProductMovement> slowMoving;

  factory AnalyticsSummary.fromJson(dynamic json) {
    return AnalyticsSummary(
      daily: (json['daily'] as List)
          .map((e) => AnalyticsPoint.fromJson(e))
          .toList(),
      weekly: (json['weekly'] as List)
          .map((e) => AnalyticsPoint.fromJson(e))
          .toList(),
      monthly: (json['monthly'] as List)
          .map((e) => AnalyticsPoint.fromJson(e))
          .toList(),
      fastMoving: (json['fast_moving'] as List)
          .map((e) => ProductMovement.fromJson(e))
          .toList(),
      slowMoving: (json['slow_moving'] as List)
          .map((e) => ProductMovement.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'daily': daily.map((e) => e.toJson()).toList(),
    'weekly': weekly.map((e) => e.toJson()).toList(),
    'monthly': monthly.map((e) => e.toJson()).toList(),
    'fast_moving': fastMoving.map((e) => e.toJson()).toList(),
    'slow_moving': slowMoving.map((e) => e.toJson()).toList(),
  };
}

class HomeSummary {
  HomeSummary({
    required this.shop,
    required this.analytics,
    required this.recentSales,
  });

  final ShopProfile shop;
  final AnalyticsSummary analytics;
  final List<Sale> recentSales;

  factory HomeSummary.fromJson(dynamic json) {
    return HomeSummary(
      shop: ShopProfile.fromJson(json['shop']),
      analytics: AnalyticsSummary.fromJson(json['analytics']),
      recentSales: (json['recent_sales'] as List)
          .map((e) => Sale.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'shop': shop.toJson(),
    'analytics': analytics.toJson(),
    'recent_sales': recentSales.map((e) => e.toJson()).toList(),
  };
}
