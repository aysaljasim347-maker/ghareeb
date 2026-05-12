import 'package:flutter_test/flutter_test.dart';
import 'package:disasteraid_app/features/auth/domain/user_model.dart';

void main() {
  group('UserModel', () {
    test('should create from JSON', () {
      final json = {
        'id': 1,
        'email': 'test@test.com',
        'phone': null,
        'name': 'Test User',
        'role': 'DONOR',
        'cnic': '3520112345678',
        'locale': 'en',
        'created_at': '2024-01-01T00:00:00Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 1);
      expect(user.email, 'test@test.com');
      expect(user.name, 'Test User');
      expect(user.role, 'DONOR');
      expect(user.isDonor, true);
      expect(user.isAdmin, false);
      expect(user.isVolunteer, false);
    });

    test('should serialize to JSON', () {
      const user = UserModel(
        id: 1,
        email: 'test@test.com',
        name: 'Test User',
        role: 'VOLUNTEER',
      );

      final json = user.toJson();

      expect(json['id'], 1);
      expect(json['email'], 'test@test.com');
      expect(json['name'], 'Test User');
      expect(json['role'], 'VOLUNTEER');
    });

    test('role helpers should return correct values', () {
      const admin = UserModel(id: 1, name: 'Admin', role: 'ADMIN');
      const ngo = UserModel(id: 2, name: 'NGO', role: 'NGO');
      const volunteer = UserModel(id: 3, name: 'Vol', role: 'VOLUNTEER');
      const donor = UserModel(id: 4, name: 'Donor', role: 'DONOR');
      const beneficiary = UserModel(id: 5, name: 'Ben', role: 'BENEFICIARY');
      const coordinator = UserModel(id: 6, name: 'Coord', role: 'COORDINATOR');

      expect(admin.isAdmin, true);
      expect(admin.isNgo, false);

      expect(ngo.isNgo, true);
      expect(volunteer.isVolunteer, true);
      expect(donor.isDonor, true);
      expect(beneficiary.isBeneficiary, true);
      expect(coordinator.isCoordinator, true);
    });

    test('should handle nullable fields', () {
      final json = {
        'id': 1,
        'email': null,
        'phone': '+923001234567',
        'name': 'Phone User',
        'role': 'BENEFICIARY',
      };

      final user = UserModel.fromJson(json);

      expect(user.email, null);
      expect(user.phone, '+923001234567');
      expect(user.cnic, null);
    });
  });
}
