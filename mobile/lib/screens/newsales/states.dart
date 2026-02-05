part of 'newsales.dart';

class _DraftSlot {
  const _DraftSlot({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class _DraftSaleItem {
  const _DraftSaleItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productName;
  final double quantity;
  final double unitPrice;

  double get lineTotal => quantity * unitPrice;

  _DraftSaleItem copyWith({
    String? productName,
    double? quantity,
    double? unitPrice,
  }) {
    return _DraftSaleItem(
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}
