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
      id: json['id'],
      email: json['email'],
      phone: json['phone'],
      name: json['name'],
      role: json['role'],
      cnic: json['cnic'],
      locale: json['locale'] ?? 'en',
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
      user: UserProfile.fromJson(json['user']),
      token: json['token'],
    );
  }
}
