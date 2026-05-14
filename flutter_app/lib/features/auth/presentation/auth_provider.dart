import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:disasteraid_app/core/api/api_client.dart';
import 'package:disasteraid_app/core/storage/secure_storage.dart';
import 'package:disasteraid_app/features/auth/data/auth_repository.dart';
import 'package:disasteraid_app/features/auth/domain/user_model.dart';

// ── Repository Provider ──
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.read(apiClientProvider);
  return AuthRepository(client: client);
});

// ── Auth State ──
enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, UserModel? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

// ── Auth Notifier ──
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final SecureStorageService _storage;

  AuthNotifier({
    required AuthRepository repository,
    required SecureStorageService storage,
  })  : _repository = repository,
        _storage = storage,
        super(const AuthState()) {
    _checkAuth();
  }

  /// Check if user has a valid stored token.
  Future<void> _checkAuth() async {
    final token = await _storage.getToken();
    
    // SECURITY: Prevent overwriting state if a login/register flow already started
    if (state.status != AuthStatus.initial) return;

    if (token != null) {
      try {
        final user = await _repository.getProfile();
        state = AuthState(status: AuthStatus.authenticated, user: user);
      } catch (_) {
        await _storage.clearAll();
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Login with email or phone.
  Future<void> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final result = await _repository.login(
        email: email,
        phone: phone,
        password: password,
      );
      await _storage.saveToken(result.token);
      await _storage.saveUserRole(result.user.role);
      await _storage.saveUserId(result.user.id.toString());
      state = AuthState(status: AuthStatus.authenticated, user: result.user);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: _extractError(e),
      );
    }
  }

  /// Register a new user.
  Future<void> register({
    String? email,
    String? phone,
    required String password,
    required String name,
    required String role,
    String? cnic,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final result = await _repository.register(
        email: email,
        phone: phone,
        password: password,
        name: name,
        role: role,
        cnic: cnic,
      );
      await _storage.saveToken(result.token);
      await _storage.saveUserRole(result.user.role);
      await _storage.saveUserId(result.user.id.toString());
      state = AuthState(status: AuthStatus.authenticated, user: result.user);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: _extractError(e),
      );
    }
  }

  /// Logout.
  Future<void> logout() async {
    await _storage.clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _extractError(dynamic e) {
    if (e is Exception) {
      return e.toString().replaceAll('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }
}

// ── Provider ──
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.read(authRepositoryProvider);
  final storage = ref.read(secureStorageProvider);
  return AuthNotifier(repository: repository, storage: storage);
});
