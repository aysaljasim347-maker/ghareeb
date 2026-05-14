import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Interceptor that retries failed requests with exponential backoff.
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration initialDelay;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    var extra = err.requestOptions.extra;
    var retryCount = extra['retryCount'] ?? 0;

    if (_shouldRetry(err) && retryCount < maxRetries) {
      retryCount++;
      extra['retryCount'] = retryCount;

      // Exponential backoff: 500ms, 1000ms, 2000ms...
      final delay = initialDelay * (retryCount * retryCount);
      
      debugPrint('[RETRY] Attempt $retryCount for ${err.requestOptions.path} after ${delay.inMilliseconds}ms');

      await Future.delayed(delay);

      try {
        final response = await dio.request(
          err.requestOptions.path,
          data: err.requestOptions.data,
          queryParameters: err.requestOptions.queryParameters,
          options: Options(
            method: err.requestOptions.method,
            headers: err.requestOptions.headers,
            extra: extra,
          ),
        );
        return handler.resolve(response);
      } on DioException catch (e) {
        return super.onError(e, handler);
      }
    }

    return super.onError(err, handler);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        (err.type == DioExceptionType.unknown && err.error is SocketException);
  }
}
