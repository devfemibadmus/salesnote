import 'package:flutter/material.dart';

import '../app/navigator.dart';
import '../data/models.dart';
import '../screens/preview/preview.dart';
import 'api_client.dart';
import 'cache/loader.dart';
import 'notice.dart';
import 'token_store.dart';

class PreviewService {
  PreviewService._();

  static bool _opening = false;

  static Future<void> openById(String saleId) async {
    final navigator = AppNavigator.key.currentState;
    if (navigator == null || _opening) {
      return;
    }
    _opening = true;
    final api = ApiClient(TokenStore());

    try {
      final loadingRoute = MaterialPageRoute<void>(
        builder: (_) => const SalePreviewLoadingScreen(),
      );
      navigator.push(loadingRoute);

      final saleDetail = await CacheLoader.loadOrFetchSalePreview(api, saleId);
      if (saleDetail == null) {
        if (loadingRoute.isActive) {
          navigator.pop();
        }
        AppNotice.show(navigator.context, 'Unable to open sale preview.');
        return;
      }

      if (!loadingRoute.isActive) {
        return;
      }

      final settings = await CacheLoader.loadOrFetchSettingsSummary(api);
      final signatures = await CacheLoader.loadOrFetchSignatures(api);

      final shop = settings?.shop;
      SignatureItem? signature;
      for (final sig in signatures) {
        if (sig.id == saleDetail.signatureId) {
          signature = sig;
          break;
        }
      }

      final previewItems = saleDetail.items
          .map(
            (item) => PreviewSaleItem(
              productName: item.productName,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
            ),
          )
          .toList();
      final createdAt = DateTime.tryParse(saleDetail.createdAt)?.toLocal();

      final previewRoute = MaterialPageRoute<void>(
        builder: (_) => SalePreviewScreen(
          isCreatedSale: true,
          shop: shop,
          signature: signature,
          customerName: saleDetail.customerName ?? '',
          customerContact: saleDetail.customerContact ?? '',
          items: previewItems,
          subtotal: saleDetail.subtotal,
          discountAmount: saleDetail.discountAmount,
          vatAmount: saleDetail.vatAmount,
          serviceFeeAmount: saleDetail.serviceFeeAmount,
          deliveryFeeAmount: saleDetail.deliveryFeeAmount,
          roundingAmount: saleDetail.roundingAmount,
          otherAmount: saleDetail.otherAmount,
          otherLabel: saleDetail.otherLabel,
          total: saleDetail.total,
          receiptNumber: '#REC-$saleId',
          createdAt: createdAt,
        ),
      );

      await navigator.pushReplacement(previewRoute);
    } finally {
      api.dispose();
      _opening = false;
    }
  }
}
