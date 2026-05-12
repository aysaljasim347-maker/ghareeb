import 'package:dio/dio.dart';
import 'package:disasteraid_app/core/storage/secure_storage.dart';

/// Dio interceptor that attaches JWT token to every request
/// and handles 401 responses.
class AuthInterceptor extends Interceptor {
  final SecureStorageService storage;

  AuthInterceptor({required this.storage});

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // Token expired or invalid — clear stored credentials
      await storage.deleteToken();
      // The router will redirect to login when auth state changes
    }
    handler.next(err);
  }
}
