import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:reliefnet_app/core/storage/secure_storage.dart';

/// Interceptor for logging failed requests and performance metrics.
class ObservabilityInterceptor extends Interceptor {
  final SecureStorageService storage;

  ObservabilityInterceptor({required this.storage});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final statusCode = response?.statusCode;
    final path = err.requestOptions.path;
    final method = err.requestOptions.method;
    final role = await storage.getUserRole() ?? 'UNKNOWN';

    // Log the failure
    debugPrint('[OBSERVABILITY] Request Failed: $method $path');
    debugPrint('  Status: $statusCode');
    debugPrint('  Role: $role');
    debugPrint('  Message: ${err.message}');

    if (response?.data != null) {
      debugPrint('  Data: ${response?.data}');
    }

    // Capture Request ID if provided by backend
    final requestId = response?.headers.value('X-Request-Id');
    if (requestId != null) {
      debugPrint('  Backend RequestId: $requestId');
    }

    super.onError(err, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      final path = response.requestOptions.path;
      final method = response.requestOptions.method;
      debugPrint('[OBSERVABILITY] Request Success: $method $path (${response.statusCode})');
    }
    super.onResponse(response, handler);
  }
}
