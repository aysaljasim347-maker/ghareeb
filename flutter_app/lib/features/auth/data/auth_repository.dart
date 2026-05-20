import 'package:reliefnet_app/core/api/api_client.dart';
import 'package:reliefnet_app/core/api/api_constants.dart';
import 'package:reliefnet_app/features/auth/domain/user_model.dart';

/// Authentication API data layer.
class AuthRepository {
  final ApiClient _client;

  AuthRepository({required ApiClient client}) : _client = client;

  /// Register a new user.
  Future<({UserModel user, String token})> register({
    String? email,
    String? phone,
    required String password,
    required String name,
    required String role,
    String? cnic,
  }) async {
    final response = await _client.post(
      ApiConstants.register,
      data: {
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'password': password,
        'name': name,
        'role': role,
        if (cnic != null) 'cnic': cnic,
      },
    );

    final data = response.data as Map<String, dynamic>;
    return (
      user: UserModel.fromJson(data['user']),
      token: data['token'] as String,
    );
  }

  /// Login with email/phone + password.
  Future<({UserModel user, String token})> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final response = await _client.post(
      ApiConstants.login,
      data: {
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'password': password,
      },
    );

    final data = response.data as Map<String, dynamic>;
    return (
      user: UserModel.fromJson(data['user']),
      token: data['token'] as String,
    );
  }

  /// Get current user profile.
  Future<UserModel> getProfile() async {
    final response = await _client.get(ApiConstants.me);
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }
}
