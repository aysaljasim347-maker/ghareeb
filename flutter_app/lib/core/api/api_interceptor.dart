import 'package:dio/dio.dart';
import 'package:reliefnet_app/core/storage/secure_storage.dart';

/// ---------------------------------------------------------------------------
/// 🛡️ AUTH INTERCEPTOR (JWT HANDLER)
/// ---------------------------------------------------------------------------
///
/// 🧠 WHAT IS THIS FILE?
/// This is a Dio Interceptor that automatically handles authentication.
///
/// Instead of manually adding a token in every API request,
/// this class does it for you automatically.
///
/// It also listens for "401 Unauthorized" errors
/// and clears the saved login token when the user is no longer valid.
///
/// ---------------------------------------------------------------------------
/// 🧠 SIMPLE IDEA:
///
/// Every request goes through 2 checkpoints:
///
/// 1️⃣ BEFORE REQUEST IS SENT (onRequest)
///    → Attach token if available
///
/// 2️⃣ IF REQUEST FAILS (onError)
///    → If token is invalid (401), remove it
///
/// ---------------------------------------------------------------------------
class AuthInterceptor extends Interceptor {
  /// 🔐 This service is responsible for storing and reading the JWT token
  /// from secure storage (like encrypted phone storage / keychain).
  final SecureStorageService storage;

  AuthInterceptor({required this.storage});

  // -------------------------------------------------------------------------
  // 📤 1. ON REQUEST (BEFORE API CALL IS SENT)
  // -------------------------------------------------------------------------
  //
  // 🧠 This function runs EVERY TIME your app sends a request.
  //
  // Example:
  //   GET /profile
  //   GET /posts
  //   POST /login
  //
  // Before any of these leave your app, this function runs first.
  // -------------------------------------------------------------------------
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    /// 🔹 STEP 1: Read token from secure storage
    ///
    /// This token is usually saved after login:
    /// Example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    final token = await storage.getToken();

    /// 🔹 STEP 2: If token exists, attach it to request headers
    ///
    /// This tells the backend:
    /// "This user is logged in"
    ///
    /// Final HTTP header becomes:
    /// Authorization: Bearer <token>
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    /// 🔹 STEP 3: Continue request flow
    ///
    /// Without this line, the request will NEVER be sent.
    handler.next(options);
  }

  // -------------------------------------------------------------------------
  // ❌ 2. ON ERROR (WHEN REQUEST FAILS)
  // -------------------------------------------------------------------------
  //
  // 🧠 This function runs when the server returns an error response.
  //
  // Example:
  //   200 → success (this method is NOT called)
  //   500 → server error (this method is called)
  //   401 → unauthorized (this method is called)
  //
  // We mainly care about 401 here.
  // -------------------------------------------------------------------------
  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    /// 🔹 STEP 1: Check if error is "401 Unauthorized"
    ///
    /// 🧠 Meaning:
    /// The server is saying:
    /// "This token is invalid or expired"
    if (err.response?.statusCode == 401) {
      /// 🔹 STEP 2: Remove stored token
      ///
      /// Why?
      /// Because keeping an invalid token will keep failing requests.
      ///
      /// So we clean it up to reset authentication state.
      await storage.deleteToken();

      /// 🔹 STEP 3: IMPORTANT NOTE (Architecture idea)
      ///
      /// We are NOT navigating to login screen here.
      ///
      /// Instead:
      /// → The app's state management / router will detect
      ///   "no token exists" and redirect user automatically.
      ///
      /// This keeps UI logic separate from networking logic.
    }

    /// 🔹 STEP 4: Pass error forward
    ///
    /// This tells Dio:
    /// "We are done handling this error, continue normal error flow"
    handler.next(err);
  }
}
