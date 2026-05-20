import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/config/env.dart';
import 'package:reliefnet_app/core/api/api_interceptor.dart';
import 'package:reliefnet_app/core/api/observability_interceptor.dart';
import 'package:reliefnet_app/core/api/retry_interceptor.dart';
import 'package:reliefnet_app/core/storage/secure_storage.dart';

/// Provider for the Dio-based API client.
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.read(secureStorageProvider);
  return ApiClient(storage: storage);
});

/// Dio HTTP client wrapper with JWT authentication.
class ApiClient {
  late final Dio _dio;
  final SecureStorageService storage;

  ApiClient({required this.storage}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          // Do NOT force Content-Type here. Dio sets it automatically:
          //   Map  data  → application/json
          //   FormData   → multipart/form-data; boundary=...
          // Forcing application/json globally breaks multipart uploads.
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(RetryInterceptor(dio: _dio));
    _dio.interceptors.add(AuthInterceptor(storage: storage));
    _dio.interceptors.add(ObservabilityInterceptor(storage: storage));
    _dio.interceptors.add(LogInterceptor(
      requestBody: kDebugMode,
      responseBody: kDebugMode,
      logPrint: (obj) {
        if (kDebugMode) {
          String log = obj.toString();
          // SECURITY: Scrub passwords from logs
          if (log.contains('password')) {
            log = log.replaceAll(
                RegExp(r'"password":\s*".*?"'), '"password": "***"');
          }
          debugPrint('[API] $log');
        }
      },
    ));
  }

  Dio get dio => _dio;

  // ── Generic HTTP Methods ──

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.post(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<Response> patch(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio.patch(path, data: data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  void _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionError) {
      debugPrint('[CRITICAL] API Connection Error: Check CORS or Backend URL');
    }
    debugPrint('[API ERROR] ${e.message}');
    if (e.response != null) {
      debugPrint('[API ERROR DATA] ${e.response?.data}');
    }
  }
}
