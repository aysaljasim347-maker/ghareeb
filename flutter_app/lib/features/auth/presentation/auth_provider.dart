import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/core/api/api_client.dart';
import 'package:reliefnet_app/core/socket/socket_provider.dart';
import 'package:reliefnet_app/core/storage/secure_storage.dart';
import 'package:reliefnet_app/features/auth/data/auth_repository.dart';
import 'package:reliefnet_app/features/auth/domain/user_model.dart';

// ── Repository provider ────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(client: ref.read(apiClientProvider));
});

// ── State ──────────────────────────────────────────────────────────────────────

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

  AuthState copyWith({AuthStatus? status, UserModel? user, String? error}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final SecureStorageService _storage;
  final Ref _ref; // ref.read only — never ref.watch inside a StateNotifier

  AuthNotifier({
    required AuthRepository repository,
    required SecureStorageService storage,
    required Ref ref,
  })  : _repository = repository,
        _storage = storage,
        _ref = ref,
        super(const AuthState()) {
    _checkAuth();
  }

  // ── Startup ──────────────────────────────────────────────────────────────────

  Future<void> _checkAuth() async {
    final token = await _storage.getToken();

    // Guard: a concurrent login/register call may have already resolved auth.
    if (state.status != AuthStatus.initial) return;

    if (token == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final user = await _repository.getProfile();
      state = AuthState(status: AuthStatus.authenticated, user: user);
      // Token is valid — connect the socket now that the token is confirmed.
      await _ref.read(socketServiceProvider).connect();
    } catch (_) {
      await _storage.clearAll();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────────

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
      // Token is now in storage — connect the socket after state update so
      // any listeners that react to authenticated status can start watching.
      await _ref.read(socketServiceProvider).connect();
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: _extractError(e),
      );
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────────

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
      await _ref.read(socketServiceProvider).connect();
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: _extractError(e),
      );
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    // Disconnect the socket BEFORE clearing the token — allows a clean
    // leave_room / disconnect handshake with the server.
    _ref.read(socketServiceProvider).disconnect();
    await _storage.clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _extractError(dynamic e) {
    if (e is Exception) {
      return e.toString().replaceAll('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    repository: ref.read(authRepositoryProvider),
    storage: ref.read(secureStorageProvider),
    ref: ref,
  );
});
