/// User model representing the authenticated user.
class UserModel {
  final int id;
  final String? email;
  final String? phone;
  final String name;
  final String role;
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
      id: json['id'] as int,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      name: json['name'] as String,
      role: json['role'] as String,
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
      'role': role,
      'cnic': cnic,
      'locale': locale,
      'created_at': createdAt,
    };
  }

  bool get isAdmin => role == 'ADMIN';
  bool get isNgo => role == 'NGO';
  bool get isVolunteer => role == 'VOLUNTEER';
  bool get isDonor => role == 'DONOR';
  bool get isBeneficiary => role == 'BENEFICIARY';
  bool get isCoordinator => role == 'COORDINATOR';
}
