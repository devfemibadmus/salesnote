import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app/navigator.dart';
import '../app/routes.dart';
import '../app/config.dart';
import '../data/models.dart';
import 'cache/local.dart';
import 'media.dart';
import 'notification.dart';
import 'token_store.dart';

class ApiClient {
  ApiClient(this._tokenStore);

  final TokenStore _tokenStore;
  http.Client _client = http.Client();

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  void cancelInFlight() {
    _client.close();
    _client = http.Client();
  }

  void dispose() {
    _client.close();
  }

  Future<http.Response> _timedRequest(
    String method,
    Uri uri,
    Future<http.Response> Function() send,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await send();
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint(
          'API TIME $method $uri -> ${stopwatch.elapsedMilliseconds}ms [${response.statusCode}]',
        );
      }
      return response;
    } catch (e) {
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint(
          'API TIME $method $uri -> ${stopwatch.elapsedMilliseconds}ms [ERROR: $e]',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, String>> _headers() async {
    final token = await _tokenStore.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<ApiResponse<T>> _handle<T>(
    http.Response response,
    T Function(dynamic) map,
  ) async {
    if (kDebugMode) {
      debugPrint(
        'API ${response.request?.method} ${response.request?.url} '
        '-> ${response.statusCode} ${response.body}',
      );
    }
    final decoded = _tryDecodeJson(response.body);
    if (decoded is Map<String, dynamic>) {
      if (response.statusCode == 401) {
        final message = (decoded['error'] as Map<String, dynamic>?)?['message']
            ?.toString();
        await _handleUnauthorized(response);
        throw ApiException(
          message?.isNotEmpty == true
              ? message!
              : 'Your session has expired. Please sign in again.',
          statusCode: 401,
        );
      }
      final success = decoded['success'] == true;
      if (!success) {
        final error = decoded['error'] as Map<String, dynamic>?;
        final message = error?['message']?.toString();
        throw ApiException(
          message?.isNotEmpty == true ? message! : 'Something went wrong.',
          statusCode: response.statusCode,
        );
      }
      return ApiResponse<T>(data: map(decoded['data']));
    }

    final rawMessage = response.body.trim();
    if (response.statusCode == 401) {
      await _handleUnauthorized(response);
      throw ApiException(
        rawMessage.isNotEmpty
            ? rawMessage
            : 'Your session has expired. Please sign in again.',
        statusCode: 401,
      );
    }
    if (rawMessage.isNotEmpty) {
      throw ApiException(rawMessage, statusCode: response.statusCode);
    }
    throw ApiException(
      'Something went wrong.',
      statusCode: response.statusCode,
    );
  }

  dynamic _tryDecodeJson(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleUnauthorized(http.Response response) async {
    final path = response.request?.url.path ?? '';
    if (_isAuthEndpoint(path)) return;
    await _tokenStore.clear();
    await LocalCache.clearAll();
    await NotificationService.clearLocalState();
    final navigator = AppNavigator.key.currentState;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil(AppRoutes.auth, (_) => false);
  }

  bool _isAuthEndpoint(String path) {
    return path.startsWith('/auth/login') ||
        path.startsWith('/auth/register') ||
        path.startsWith('/auth/forgot-password') ||
        path.startsWith('/auth/reset-password') ||
        path.startsWith('/auth/verify-code') ||
        path.startsWith('/auth/refresh');
  }

  Future<AuthResult> login(
    String phoneOrEmail,
    String password, {
    String? deviceName,
    String? devicePlatform,
    String? deviceOs,
  }) async {
    final payload = <String, dynamic>{
      'phone_or_email': phoneOrEmail,
      'password': password,
    };
    if (deviceName != null && deviceName.isNotEmpty) {
      payload['device_name'] = deviceName;
    }
    if (devicePlatform != null && devicePlatform.isNotEmpty) {
      payload['device_platform'] = devicePlatform;
    }
    if (deviceOs != null && deviceOs.isNotEmpty) {
      payload['device_os'] = deviceOs;
    }
    final uri = _uri('/auth/login');
    final headers = await _headers();
    final response = await _timedRequest(
      'POST',
      uri,
      () => _client.post(uri, headers: headers, body: jsonEncode(payload)),
    );
    final result = await _handle(response, (data) => AuthResult.fromJson(data));
    await _tokenStore.saveToken(result.data.accessToken);
    return result.data;
  }

  Future<AuthResult> register(RegisterInput input) async {
    final uri = _uri('/auth/register');
    final headers = await _headers();
    final response = await _timedRequest(
      'POST',
      uri,
      () =>
          _client.post(uri, headers: headers, body: jsonEncode(input.toJson())),
    );
    await _handle(response, (data) => data);
    return AuthResult(
      accessToken: '',
      shop: ShopProfile(
        id: '',
        name: input.shopName,
        phone: input.phone,
        currencyCode: input.currencyCode,
        liveAgentTokensUsed: 0,
        liveAgentTokensAvailable: 3000000,
        email: input.email,
        address: input.address,
        logoUrl: input.logoUrl,
        timezone: input.timezone,
        createdAt: '',
        bankAccounts: const [],
      ),
    );
  }

  Future<AuthResult> verifySignupCode(
    RegisterInput input,
    String code, {
    String? deviceName,
    String? devicePlatform,
    String? deviceOs,
  }) async {
    final uri = _uri('/auth/register/verify');
    final headers = await _headers();
    final payload = <String, dynamic>{
      ...input.toJson(),
      'code': code,
      'device_name': deviceName,
      'device_platform': devicePlatform,
      'device_os': deviceOs,
    };
    final response = await _timedRequest(
      'POST',
      uri,
      () => _client.post(uri, headers: headers, body: jsonEncode(payload)),
    );
    final result = await _handle(response, (data) => AuthResult.fromJson(data));
    await _tokenStore.saveToken(result.data.accessToken);
    return result.data;
  }

  Future<void> forgotPassword(String phoneOrEmail) async {
    final uri = _uri('/auth/forgot-password');
    final headers = await _headers();
    final response = await _timedRequest(
      'POST',
      uri,
      () => _client.post(
        uri,
        headers: headers,
        body: jsonEncode({'phone_or_email': phoneOrEmail}),
      ),
    );
    await _handle(response, (data) => data);
  }

  Future<void> verifyResetCode(String phoneOrEmail, String code) async {
    final uri = _uri('/auth/verify-code');
    final headers = await _headers();
    final response = await _timedRequest(
      'POST',
      uri,
      () => _client.post(
        uri,
        headers: headers,
        body: jsonEncode({'phone_or_email': phoneOrEmail, 'code': code}),
      ),
    );
    await _handle(response, (data) => data);
  }

  Future<void> resetPassword(
    String phoneOrEmail,
    String code,
    String newPassword,
  ) async {
    final uri = _uri('/auth/reset-password');
    final headers = await _headers();
    final response = await _timedRequest(
      'POST',
      uri,
      () => _client.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'phone_or_email': phoneOrEmail,
          'code': code,
          'new_password': newPassword,
        }),
      ),
    );
    await _handle(response, (data) => data);
  }

  Future<void> subscribeFcm(String? token) async {
    if (token == null || token.trim().isEmpty) return;
    final uri = _uri('/shop/subscribe');
    final headers = await _headers();
    final response = await _timedRequest(
      'POST',
      uri,
      () => _client.post(
        uri,
        headers: headers,
        body: jsonEncode({'fcm_token': token.trim()}),
      ),
    );
    await _handle(response, (data) => data);
  }

  Future<void> unsubscribeFcm() async {
    final uri = _uri('/shop/subscribe');
    final headers = await _headers();
    final response = await _timedRequest(
      'POST',
      uri,
      () => _client.post(
        uri,
        headers: headers,
        body: jsonEncode({'fcm_token': ''}),
      ),
    );
    await _handle(response, (data) => data);
  }

  Future<ShopProfile> getShop() async {
    final uri = _uri('/shop');
    final headers = await _headers();
    final response = await _timedRequest(
      'GET',
      uri,
      () => _client.get(uri, headers: headers),
    );
    final result = await _handle(
      response,
      (data) => ShopProfile.fromJson(data),
    );
    await MediaService.warmImage(result.data.logoUrl);
    return result.data;
  }

  Future<ShopProfile> updateShop(ShopUpdateInput input) async {
    final uri = _uri('/shop');
    final headers = await _headers();
    final response = await _timedRequest(
      'PATCH',
      uri,
      () => _client.patch(
        uri,
        headers: headers,
        body: jsonEncode(input.toJson()),
      ),
    );
    final result = await _handle(
      response,
      (data) => ShopProfile.fromJson(data),
    );
    await MediaService.warmImage(result.data.logoUrl);
    return result.data;
  }

  Future<ShopProfile> uploadShopLogo(String imagePath) async {
    final uri = _uri('/shop');
    final token = await _tokenStore.getToken();
    final request = http.MultipartRequest('PATCH', uri)
      ..files.add(await http.MultipartFile.fromPath('logo', imagePath));

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final stopwatch = Stopwatch()..start();
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    stopwatch.stop();
    if (kDebugMode) {
      debugPrint(
        'API TIME PATCH $uri -> ${stopwatch.elapsedMilliseconds}ms [${response.statusCode}]',
      );
    }

    final result = await _handle(
      response,
      (data) => ShopProfile.fromJson(data),
    );
    await MediaService.warmImage(result.data.logoUrl);
    return result.data;
  }

  Future<List<SignatureItem>> listSignatures() async {
    final uri = _uri('/signatures');
    final headers = await _headers();
    final response = await _timedRequest(
      'GET',
      uri,
      () => _client.get(uri, headers: headers),
    );
    final result = await _handle(
      response,
      (data) => (data as List).map((e) => SignatureItem.fromJson(e)).toList(),
    );
    await MediaService.warmImages(result.data.map((e) => e.imageUrl));
    return result.data;
  }

  Future<SignatureItem> createSignature(SignatureInput input) async {
    final uri = _uri('/signatures');
    final headers = await _headers();
    final response = await _timedRequest(
      'POST',
      uri,
      () =>
          _client.post(uri, headers: headers, body: jsonEncode(input.toJson())),
    );
    final result = await _handle(
      response,
      (data) => SignatureItem.fromJson(data),
    );
    await MediaService.warmImage(result.data.imageUrl);
    return result.data;
  }

  Future<SignatureItem> uploadSignature({
    required String name,
    required String imagePath,
  }) async {
    final uri = _uri('/signatures');
    final token = await _tokenStore.getToken();
    final request = http.MultipartRequest('POST', uri)
      ..fields['name'] = name
      ..files.add(await http.MultipartFile.fromPath('image', imagePath));

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final stopwatch = Stopwatch()..start();
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    stopwatch.stop();
    if (kDebugMode) {
      debugPrint(
        'API TIME POST $uri -> ${stopwatch.elapsedMilliseconds}ms [${response.statusCode}]',
      );
    }
    final result = await _handle(
      response,
      (data) => SignatureItem.fromJson(data),
    );
    await MediaService.warmImage(result.data.imageUrl);
    return result.data;
  }

  Future<void> deleteSignature(String id) async {
    final uri = _uri('/signatures/$id');
    final headers = await _headers();
    final response = await _timedRequest(
      'DELETE',
      uri,
      () => _client.delete(uri, headers: headers),
    );
    await _handle(response, (data) => data);
  }

  Future<List<SuggestionItem>> listSuggestions(String key, String query) async {
    final uri = _uri('/suggestions').replace(
      queryParameters: {
        'key': key,
        'q': query,
        'limit': '10',
      },
    );
    final headers = await _headers();
    final response = await _timedRequest(
      'GET',
      uri,
      () => _client.get(uri, headers: headers),
    );
    final result = await _handle(
      response,
      (data) => (data as List).map((e) => SuggestionItem.fromJson(e)).toList(),
    );
    return result.data;
  }

  Future<void> storeSuggestion(SuggestionInput input) async {
    final uri = _uri('/suggestions');
    final headers = await _headers();
    final response = await _timedRequest(
      'POST',
      uri,
      () =>
          _client.post(uri, headers: headers, body: jsonEncode(input.toJson())),
    );
    await _handle(response, (data) => data);
  }

  Future<Sale> createSale(SaleInput input) async {
    final uri = _uri('/sales');
    final headers = await _headers();
    final response = await _timedRequest(
      'POST',
      uri,
      () =>
          _client.post(uri, headers: headers, body: jsonEncode(input.toJson())),
    );
    final result = await _handle(response, (data) => Sale.fromJson(data));
    return result.data;
  }

  Future<Sale> updateSale(String id, SaleUpdateInput input) async {
    final uri = _uri('/sales/$id');
    final headers = await _headers();
    final response = await _timedRequest(
      'PATCH',
      uri,
      () => _client.patch(
        uri,
        headers: headers,
        body: jsonEncode(input.toJson()),
      ),
    );
    final result = await _handle(response, (data) => Sale.fromJson(data));
    return result.data;
  }

  Future<void> deleteSale(String id) async {
    final uri = _uri('/sales/$id');
    final headers = await _headers();
    final response = await _timedRequest(
      'DELETE',
      uri,
      () => _client.delete(uri, headers: headers),
    );
    await _handle(response, (data) => data);
  }

  Future<List<Sale>> listSales({
    int? page,
    int? perPage,
    bool includeItems = true,
    SaleStatus? status,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final salesUri = () {
      final uri = _uri('/sales');
      final normalizedSearch = searchQuery?.trim();
      if (page == null &&
          perPage == null &&
          (normalizedSearch == null || normalizedSearch.isEmpty) &&
          startDate == null &&
          endDate == null) {
        return uri;
      }
      final query = <String, String>{};
      if (page != null) query['page'] = page.toString();
      if (perPage != null) query['per_page'] = perPage.toString();
      query['include_items'] = includeItems.toString();
      if (status != null) {
        query['status'] = status.name;
      }
      if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
        query['q'] = normalizedSearch;
      }
      if (startDate != null) {
        query['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        query['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      return uri.replace(queryParameters: query);
    }();
    final headers = await _headers();
    final response = await _timedRequest(
      'GET',
      salesUri,
      () => _client.get(salesUri, headers: headers),
    );
    final result = await _handle(
      response,
      (data) => (data as List).map((e) => Sale.fromJson(e)).toList(),
    );
    return result.data;
  }

  Future<Sale> getSale(String id) async {
    final uri = _uri('/sales/$id');
    final headers = await _headers();
    final response = await _timedRequest(
      'GET',
      uri,
      () => _client.get(uri, headers: headers),
    );
    final result = await _handle(response, (data) => Sale.fromJson(data));
    return result.data;
  }

  Future<ReceiptDetail> createReceipt(ReceiptCreateInput input) async {
    final uri = _uri('/receipts');
    final headers = await _headers();
    final response = await _timedRequest(
      'POST',
      uri,
      () =>
          _client.post(uri, headers: headers, body: jsonEncode(input.toJson())),
    );
    final result = await _handle(
      response,
      (data) => ReceiptDetail.fromJson(data),
    );
    return result.data;
  }

  Future<List<ReceiptItem>> listReceipts() async {
    final uri = _uri('/receipts');
    final headers = await _headers();
    final response = await _timedRequest(
      'GET',
      uri,
      () => _client.get(uri, headers: headers),
    );
    final result = await _handle(
      response,
      (data) => (data as List).map((e) => ReceiptItem.fromJson(e)).toList(),
    );
    return result.data;
  }

  Future<ReceiptDetail> getReceipt(String id) async {
    final uri = _uri('/receipts/$id');
    final headers = await _headers();
    final response = await _timedRequest(
      'GET',
      uri,
      () => _client.get(uri, headers: headers),
    );
    final result = await _handle(
      response,
      (data) => ReceiptDetail.fromJson(data),
    );
    return result.data;
  }

  Future<AnalyticsSummary> getAnalytics() async {
    final uri = _uri('/analytics/summary');
    final headers = await _headers();
    final response = await _timedRequest(
      'GET',
      uri,
      () => _client.get(uri, headers: headers),
    );
    final result = await _handle(
      response,
      (data) => AnalyticsSummary.fromJson(data),
    );
    return result.data;
  }

  Future<HomeSummary> getHomeSummary() async {
    final uri = _uri('/home');
    final headers = await _headers();
    final response = await _timedRequest(
      'GET',
      uri,
      () => _client.get(uri, headers: headers),
    );
    final result = await _handle(
      response,
      (data) => HomeSummary.fromJson(data),
    );
    await MediaService.warmImage(result.data.shop.logoUrl);
    return result.data;
  }

  Future<SettingsSummary> getSettingsSummary() async {
    final uri = _uri('/settings');
    final headers = await _headers();
    final response = await _timedRequest(
      'GET',
      uri,
      () => _client.get(uri, headers: headers),
    );
    final result = await _handle(
      response,
      (data) => SettingsSummary.fromJson(data),
    );
    await MediaService.warmImage(result.data.shop.logoUrl);
    return result.data;
  }

  Future<List<DeviceSession>> listDevices() async {
    final uri = _uri('/devices');
    final headers = await _headers();
    final response = await _timedRequest(
      'GET',
      uri,
      () => _client.get(uri, headers: headers),
    );
    final result = await _handle(
      response,
      (data) => (data as List).map((e) => DeviceSession.fromJson(e)).toList(),
    );
    return result.data;
  }

  Future<void> removeDevice(String id) async {
    final uri = _uri('/devices/$id');
    final headers = await _headers();
    final response = await _timedRequest(
      'DELETE',
      uri,
      () => _client.delete(uri, headers: headers),
    );
    await _handle(response, (data) => data);
  }
}

class ApiResponse<T> {
  ApiResponse({required this.data});
  final T data;
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
