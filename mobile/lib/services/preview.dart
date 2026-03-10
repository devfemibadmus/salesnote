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
  static final ValueNotifier<int> cacheRevision = ValueNotifier<int>(0);

  static Future<void> openById(String saleId) async {
    final navigator = AppNavigator.key.currentState;
    if (navigator == null || _opening) {
      return;
    }
    final previewContext = navigator.context;
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
        if (previewContext.mounted) {
          AppNotice.show(previewContext, 'Unable to open sale preview.');
        }
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
          status: saleDetail.status,
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
          receiptNumber: '#${saleDetail.numberPrefix}-$saleId',
          createdAt: createdAt,
          onMarkAsPaid: saleDetail.isInvoice
              ? () => _markAsPaid(
                    api: api,
                    navigator: navigator,
                    saleId: saleId,
                    shop: shop,
                    signature: signature,
                  )
              : null,
          onDelete: saleDetail.isInvoice
              ? () => _deleteInvoice(
                    api: api,
                    navigator: navigator,
                    saleId: saleId,
                  )
              : null,
        ),
      );

      await navigator.pushReplacement(previewRoute);
    } finally {
      api.dispose();
      _opening = false;
    }
  }

  static Future<void> _markAsPaid({
    required ApiClient api,
    required NavigatorState navigator,
    required String saleId,
    required ShopProfile? shop,
    required SignatureItem? signature,
  }) async {
    final previewContext = navigator.context;
    try {
      final updatedSale = await api.updateSale(
        saleId,
        SaleUpdateInput(status: SaleStatus.paid),
      );
      await _updateSaleCaches(updatedSale);
      try {
        await CacheLoader.fetchAndCacheHomeSummary(api);
      } catch (_) {}
      _notifyCacheChanged();
      if (!previewContext.mounted || !navigator.mounted) return;
      AppNotice.show(previewContext, 'Invoice marked as paid.');
      await navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SalePreviewScreen(
            isCreatedSale: true,
            status: updatedSale.status,
            shop: shop,
            signature: signature,
            customerName: updatedSale.customerName ?? '',
            customerContact: updatedSale.customerContact ?? '',
            items: updatedSale.items
                .map(
                  (item) => PreviewSaleItem(
                    productName: item.productName,
                    quantity: item.quantity,
                    unitPrice: item.unitPrice,
                  ),
                )
                .toList(),
            subtotal: updatedSale.subtotal,
            discountAmount: updatedSale.discountAmount,
            vatAmount: updatedSale.vatAmount,
            serviceFeeAmount: updatedSale.serviceFeeAmount,
            deliveryFeeAmount: updatedSale.deliveryFeeAmount,
            roundingAmount: updatedSale.roundingAmount,
            otherAmount: updatedSale.otherAmount,
            otherLabel: updatedSale.otherLabel,
            total: updatedSale.total,
            receiptNumber: '#${updatedSale.numberPrefix}-${updatedSale.id}',
            createdAt: DateTime.tryParse(updatedSale.createdAt)?.toLocal(),
          ),
        ),
      );
    } catch (e) {
      if (!navigator.mounted) return;
      AppNotice.show(
        navigator.context,
        e is ApiException ? e.message : 'Unable to mark invoice as paid.',
      );
    }
  }

  static Future<void> _deleteInvoice({
    required ApiClient api,
    required NavigatorState navigator,
    required String saleId,
  }) async {
    final previewContext = navigator.context;
    try {
      await api.deleteSale(saleId);
      await _removeDeletedInvoiceCaches(saleId);
      _notifyCacheChanged();
      if (!previewContext.mounted || !navigator.mounted) return;
      AppNotice.show(previewContext, 'Invoice deleted.');
      navigator.pop();
    } catch (e) {
      if (!navigator.mounted) return;
      AppNotice.show(
        navigator.context,
        e is ApiException ? e.message : 'Unable to delete invoice.',
      );
    }
  }

  static Future<void> _updateSaleCaches(Sale updatedSale) async {
    await CacheLoader.saveSalePreviewCache(updatedSale);

    final invoiceCache = CacheLoader.loadSalesPageCache(
      includeItems: false,
      status: SaleStatus.invoice,
    );
    if (invoiceCache != null) {
      final next = invoiceCache.sales
          .where((sale) => sale.id != updatedSale.id)
          .toList();
      await CacheLoader.saveSalesPageCache(
        includeItems: false,
        status: SaleStatus.invoice,
        data: CachedSalesPage(
          sales: next,
          page: invoiceCache.page,
          hasMore: invoiceCache.hasMore,
        ),
      );
    }

    final salesCache = CacheLoader.loadSalesPageCache(
      includeItems: false,
      status: SaleStatus.paid,
    );
    if (salesCache != null) {
      final next = <Sale>[
        updatedSale,
        ...salesCache.sales.where((sale) => sale.id != updatedSale.id),
      ];
      await CacheLoader.saveSalesPageCache(
        includeItems: false,
        status: SaleStatus.paid,
        data: CachedSalesPage(
          sales: next,
          page: salesCache.page,
          hasMore: salesCache.hasMore,
        ),
      );
    }

    final itemsCache = CacheLoader.loadSalesPageCache(
      includeItems: true,
      status: SaleStatus.paid,
    );
    if (itemsCache != null) {
      final next = <Sale>[
        updatedSale,
        ...itemsCache.sales.where((sale) => sale.id != updatedSale.id),
      ];
      await CacheLoader.saveSalesPageCache(
        includeItems: true,
        status: SaleStatus.paid,
        data: CachedSalesPage(
          sales: next,
          page: itemsCache.page,
          hasMore: itemsCache.hasMore,
        ),
      );
    }
  }

  static Future<void> _removeDeletedInvoiceCaches(String saleId) async {
    final invoiceCache = CacheLoader.loadSalesPageCache(
      includeItems: false,
      status: SaleStatus.invoice,
    );
    if (invoiceCache != null) {
      final next = invoiceCache.sales
          .where((sale) => sale.id != saleId)
          .toList();
      await CacheLoader.saveSalesPageCache(
        includeItems: false,
        status: SaleStatus.invoice,
        data: CachedSalesPage(
          sales: next,
          page: invoiceCache.page,
          hasMore: invoiceCache.hasMore,
        ),
      );
    }
  }

  static void _notifyCacheChanged() {
    cacheRevision.value = cacheRevision.value + 1;
  }
}
