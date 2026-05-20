import 'package:reliefnet_app/utils/safe_parser.dart';

class UserProfile {
  final int id;
  final String? email;
  final String? phone;
  final String name;
  final String role;
  final String? cnic;
  final String? locale;

  UserProfile({
    required this.id,
    this.email,
    this.phone,
    required this.name,
    required this.role,
    this.cnic,
    this.locale,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: SafeParser.paramInt(json['id']),
      email: json['email'] != null ? SafeParser.toStringSafe(json['email']) : null,
      phone: json['phone'] != null ? SafeParser.toStringSafe(json['phone']) : null,
      name: SafeParser.toStringSafe(json['name'], defaultValue: 'User'),
      role: SafeParser.toStringSafe(json['role'], defaultValue: 'DONOR'),
      cnic: json['cnic'] != null ? SafeParser.toStringSafe(json['cnic']) : null,
      locale: SafeParser.toStringSafe(json['locale'], defaultValue: 'en'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'name': name,
      'role': role,
      'cnic': cnic,
      'locale': locale,
    };
  }
}

class AuthResponse {
  final UserProfile user;
  final String token;

  AuthResponse({required this.user, required this.token});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      token: SafeParser.toStringSafe(json['token']),
    );
  }
}
