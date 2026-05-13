enum UserRole {
  donor('DONOR'),
  beneficiary('BENEFICIARY'),
  volunteer('VOLUNTEER'),
  ngo('NGO'),
  coordinator('COORDINATOR'),
  admin('ADMIN'),
  unknown('UNKNOWN');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (e) => e.value == value?.toUpperCase(),
      orElse: () => UserRole.unknown,
    );
  }
}

/// User model representing the authenticated user.
class UserModel {
  final int id;
  final String? email;
  final String? phone;
  final String name;
  final UserRole role;
  final String? cnic;
  final String? locale;
  final String? createdAt;

  const UserModel({
    required this.id,
    this.email,
    this.phone,
    required this.name,
    required this.role,
    this.cnic,
    this.locale,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      name: json['name'] as String? ?? 'Unknown',
      role: UserRole.fromString(json['role'] as String?),
      cnic: json['cnic'] as String?,
      locale: json['locale'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'name': name,
      'role': role.value,
      'cnic': cnic,
      'locale': locale,
      'created_at': createdAt,
    };
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isNgo => role == UserRole.ngo;
  bool get isVolunteer => role == UserRole.volunteer;
  bool get isDonor => role == UserRole.donor;
  bool get isBeneficiary => role == UserRole.beneficiary;
  bool get isCoordinator => role == UserRole.coordinator;
}
