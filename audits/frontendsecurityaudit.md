# Flutter Frontend Security Audit - DisasterAid V2.1 (Post-Remediation)
**Date:** 2026-05-12
**Auditor:** Senior Mobile Security Auditor
**Status:** All previous 🔴 Critical issues have been **RESOLVED**. This report identifies remaining second-order risks.

## 🔴 Critical Vulnerabilities
*None identified.* The critical leak of plain-text passwords in API logs has been successfully plugged with a robust regex scrubber.

## 🟠 Medium Risks

### 1. Hardcoded Localhost in API Constants
**Location:** `flutter_app/lib/core/api/api_constants.dart`
**Issue:** While `env.dart` now defaults to HTTPS, `ApiConstants.baseUrl` still contains a commented-out local IP and a hardcoded `http://localhost:3000/api`.
**Fix:** Remove all hardcoded URLs from `ApiConstants` and force the app to rely exclusively on the `Env.apiUrl` injected via `--dart-define`.

## 🟢 Minor Issues

### 1. Sensitive State in Memory (Persistent)
**Location:** `flutter_app/lib/features/auth/presentation/auth_provider.dart`
**Issue:** The `AuthState` still caches the full `UserModel` (name, phone, CNIC). 
**Fix:** (Deferred) Refactor state management to fetch detailed profile info only when navigating to the Profile screen, and use a minimal user object (ID, role) for global session management.

### 2. Lack of Jailbreak/Root Detection
**Issue:** The application does not check if it is running on a compromised device.
**Fix:** Integrate `flutter_jailbreak_detection` to warn users or restrict functionality on rooted devices to protect the `flutter_secure_storage` environment.

## ✅ Secure Practices Observed (Recently Fixed)

*   **FIXED: Log Scrubbing:** `ApiClient` now uses a custom `logPrint` logic that specifically replaces `"password": "..."` values with asterisks, and only logs during `kDebugMode`.
*   **FIXED: Secure Defaults:** `Env.apiUrl` now defaults to a production `https` endpoint, reducing the risk of MITM attacks during accidental insecure deployments.
*   **FIXED: UI Validation:** The login screen now enforces regex-based email patterns and a minimum password length, improving the security posture against simple malformed data.
*   **Secure Storage:** JWT tokens and user metadata are stored using platform-native encryption (EncryptedSharedPreferences / Keychain).
*   **Token Lifecycle:** `AuthInterceptor` correctly handles `401` errors by clearing local storage and forcing a logout state.
