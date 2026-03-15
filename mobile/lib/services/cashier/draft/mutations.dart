part of '../core.dart';

extension _LiveCashierOverlayDraftMutations on _LiveCashierOverlayState {
  double _inferredUnitPriceFloor({double? currentUnitPrice}) {
    final observedUnitPrices =
        _draftItems
            .map((item) => item.unitPrice)
            .whereType<double>()
            .where((price) => price > 0)
            .toList(growable: false)
          ..sort();
    final medianObservedPrice = observedUnitPrices.isEmpty
        ? null
        : observedUnitPrices[observedUnitPrices.length ~/ 2];
    final currencyFloor = CurrencyService.heuristicUnitPriceFloorForCode(
      _toolCurrencyCode(),
    );

    var inferredFloor = currencyFloor;
    if (medianObservedPrice != null && medianObservedPrice > 0) {
      inferredFloor = math.max(inferredFloor, medianObservedPrice * 0.25);
    }
    if (currentUnitPrice != null && currentUnitPrice > 0) {
      inferredFloor = math.max(inferredFloor, currentUnitPrice * 0.35);
    }
    return inferredFloor;
  }

  bool _looksLikeUnitPriceUpdate(
    double value, {
    required double inferredPriceFloor,
    double? currentUnitPrice,
  }) {
    if (value <= 0) {
      return false;
    }
    if (value >= inferredPriceFloor) {
      return true;
    }

    final hasFraction = value != value.roundToDouble();
    if (hasFraction && value >= math.max(1, inferredPriceFloor * 0.5)) {
      return true;
    }

    if (currentUnitPrice != null && currentUnitPrice > 0) {
      final currentPriceFloor = math.max(1, currentUnitPrice * 0.35);
      if (value >= currentPriceFloor) {
        return true;
      }
    }

    return false;
  }

  void _applyAddItem(String? name, String? quantityRaw, String? unitPriceRaw) {
    final productName = (name ?? '').trim();
    if (productName.isEmpty) return;
    final quantity = double.tryParse((quantityRaw ?? '').trim()) ?? 1;
    final unitPrice = double.tryParse((unitPriceRaw ?? '').trim());
    _draftItems.add(
      LiveAgentDraftItem(
        productName: productName,
        quantity: quantity <= 0 ? 1 : quantity,
        unitPrice: unitPrice,
      ),
    );
  }

  void _applyRemoveItem(String? rawIndex) {
    final index = _resolveDraftItemIndex(rawIndex);
    if (index == null || index < 0 || index >= _draftItems.length) return;
    _draftItems.removeAt(index);
  }

  void _applyUpdateItem(
    String? rawIndex,
    String? rawValue, {
    String? quantityRaw,
    String? unitPriceRaw,
    String? field,
  }) {
    final index = _resolveDraftItemIndex(rawIndex);
    if (index == null || index < 0 || index >= _draftItems.length) {
      return;
    }
    final current = _draftItems[index];
    final explicitQuantity = double.tryParse((quantityRaw ?? '').trim());
    final explicitUnitPrice = double.tryParse((unitPriceRaw ?? '').trim());
    final fallbackValue = double.tryParse((rawValue ?? '').trim());
    final normalizedField = (field ?? '').trim().toLowerCase();
    final inferredPriceFloor = _inferredUnitPriceFloor(
      currentUnitPrice: current.unitPrice,
    );

    double quantity = current.quantity;
    double? unitPrice = current.unitPrice;

    if (explicitQuantity != null) {
      quantity = explicitQuantity > 0 ? explicitQuantity : quantity;
    }
    if (explicitUnitPrice != null) {
      unitPrice = explicitUnitPrice;
    }

    if (explicitQuantity == null &&
        explicitUnitPrice == null &&
        fallbackValue != null) {
      if (normalizedField == 'quantity') {
        quantity = fallbackValue > 0 ? fallbackValue : quantity;
      } else if (normalizedField == 'unit_price' ||
          normalizedField == 'price') {
        unitPrice = fallbackValue;
      } else if (_looksLikeUnitPriceUpdate(
        fallbackValue,
        inferredPriceFloor: inferredPriceFloor,
        currentUnitPrice: current.unitPrice,
      )) {
        unitPrice = fallbackValue;
      } else {
        quantity = fallbackValue > 0 ? fallbackValue : quantity;
      }
    }

    _draftItems[index] = LiveAgentDraftItem(
      productName: current.productName,
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }

  void _applyCharge(String? chargeTypeRaw, String? amountRaw, {String? label}) {
    final amount = double.tryParse((amountRaw ?? '').trim());
    if (amount == null) return;
    switch ((chargeTypeRaw ?? '').trim().toLowerCase()) {
      case 'discount':
        _draftDiscountAmount = amount;
        break;
      case 'vat':
      case 'tax':
        _draftVatAmount = amount;
        break;
      case 'service_fee':
      case 'service fee':
        _draftServiceFeeAmount = amount;
        break;
      case 'delivery':
      case 'delivery_fee':
      case 'delivery fee':
        _draftDeliveryFeeAmount = amount;
        break;
      case 'rounding':
        _draftRoundingAmount = amount;
        break;
      case 'other':
        _draftOtherAmount = amount;
        final normalizedLabel = (label ?? '').trim();
        if (normalizedLabel.isNotEmpty) {
          _draftOtherLabel = normalizedLabel;
        }
        break;
      default:
        break;
    }
  }

  int? _resolveDraftItemIndex(String? rawIndex) {
    final value = (rawIndex ?? '').trim();
    if (value.isEmpty) return null;
    final parsedIndex = int.tryParse(value);
    if (parsedIndex != null) {
      return parsedIndex;
    }
    final lowered = value.toLowerCase();
    for (var i = 0; i < _draftItems.length; i++) {
      if (_draftItems[i].productName.toLowerCase() == lowered) {
        return i;
      }
    }
    return null;
  }
}
