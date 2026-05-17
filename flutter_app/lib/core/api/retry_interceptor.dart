import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// A Dio Interceptor that automatically retries failed requests.
///
/// 🧠 What this does:
/// If a request fails due to a temporary network issue,
/// this interceptor will:
///   1. Wait for some time (backoff)
///   2. Retry the same request
///   3. Repeat until maxRetries is reached
///
/// ✅ This improves reliability on bad networks
/// ❌ But we must be careful to NOT retry unsafe requests (like POST)
class RetryInterceptor extends Interceptor {
  final Dio dio;

  /// Maximum number of retry attempts
  final int maxRetries;

  /// Initial delay before retrying (used to calculate backoff)
  final Duration initialDelay;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    /// 🔹 STEP 1: Get the original request
    final requestOptions = err.requestOptions;

    /// 🔹 STEP 2: Get retry count from request metadata
    /// We store retryCount inside `extra` so it travels with the request
    final extra = requestOptions.extra;
    int retryCount = extra['retryCount'] ?? 0;

    /// 🔹 STEP 3: Safety checks before retrying

    /// ❌ Do not retry if request was manually cancelled
    if (requestOptions.cancelToken?.isCancelled ?? false) {
      return super.onError(err, handler);
    }

    /// ❌ Do not retry unsafe HTTP methods (like POST)
    /// Retrying POST can cause duplicate actions (e.g., double payment)
    if (!_isSafeMethod(requestOptions.method)) {
      return super.onError(err, handler);
    }

    /// ❌ Do not retry file uploads (FormData can break on retry)
    if (requestOptions.data is FormData) {
      return super.onError(err, handler);
    }

    /// 🔹 STEP 4: Check if we should retry
    if (_shouldRetry(err) && retryCount < maxRetries) {
      retryCount++;

      /// Save updated retry count back into request
      extra['retryCount'] = retryCount;

      /// 🔹 STEP 5: Calculate delay (quadratic backoff)
      /// Example:
      /// 1st retry → 500ms
      /// 2nd retry → 2000ms
      /// 3rd retry → 4500ms
      final delay = initialDelay * (retryCount * retryCount);

      debugPrint(
        '[RETRY] Attempt $retryCount '
        '${requestOptions.method} ${requestOptions.uri} '
        'after ${delay.inMilliseconds}ms',
      );

      /// 🔹 STEP 6: Wait before retrying
      await Future.delayed(delay);

      try {
        /// 🔹 STEP 7: Retry the request
        ///
        /// We use `dio.fetch()` instead of `dio.request()`
        /// because it preserves the FULL original request:
        /// - headers
        /// - baseUrl
        /// - query params
        /// - body
        /// - everything
        final response = await dio.fetch(
          requestOptions..extra = extra,
        );

        /// 🔹 STEP 8: If retry succeeds
        /// We RESOLVE the error and return the response
        /// → Caller will think request succeeded normally
        return handler.resolve(response);
      } on DioException catch (e) {
        /// 🔹 STEP 9: If retry fails again
        /// Pass error back into interceptor chain
        return super.onError(e, handler);
      }
    }

    /// 🔹 STEP 10: If not retryable OR max retries reached
    /// Let the error continue normally
    return super.onError(err, handler);
  }

  /// 🧠 Determines whether an error is worth retrying
  ///
  /// We ONLY retry temporary/network-related issues
  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||

        /// Dio sometimes marks network errors as "unknown"
        /// so we check if the underlying error is a SocketException
        (err.type == DioExceptionType.unknown && err.error is SocketException);
  }

  /// 🧠 Only allow retry for safe HTTP methods
  ///
  /// GET  → safe (just fetching data)
  /// HEAD → safe
  ///
  /// POST → NOT safe (can create duplicate data)
  /// PUT  → depends (usually avoided)
  /// DELETE → risky
  bool _isSafeMethod(String method) {
    return method.toUpperCase() == 'GET' || method.toUpperCase() == 'HEAD';
  }
}
