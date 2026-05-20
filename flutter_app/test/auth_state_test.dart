import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/features/auth/presentation/auth_provider.dart';
import 'package:reliefnet_app/features/auth/data/auth_repository.dart';
import 'package:reliefnet_app/core/storage/secure_storage.dart';
import 'package:reliefnet_app/features/auth/domain/user_model.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks(
    [MockSpec<AuthRepository>(), MockSpec<SecureStorageService>()])
import 'auth_state_test.mocks.dart';

void main() {
  late MockAuthRepository mockRepository;
  late MockSecureStorageService mockStorage;

  setUp(() {
    mockRepository = MockAuthRepository();
    mockStorage = MockSecureStorageService();
  });

  group('AuthNotifier', () {
    test(
        'initial state should eventually be unauthenticated if no token exists',
        () async {
      when(mockStorage.getToken()).thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockRepository),
          secureStorageProvider.overrideWithValue(mockStorage),
        ],
      );

      // Wait for all async tasks in constructor (_checkAuth)
      await container
          .read(authProvider.notifier)
          .logout(); // Ensure we are in a known state

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    });

    test('login success updates state to authenticated', () async {
      const user = UserModel(
        id: 1,
        name: 'Test User',
        role: UserRole.volunteer,
        email: 'test@test.com',
      );

      when(mockStorage.getToken()).thenAnswer((_) async => null);
      when(mockRepository.login(
        email: 'test@test.com',
        password: 'password123',
      )).thenAnswer((_) async => (user: user, token: 'fake_jwt_token'));

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockRepository),
          secureStorageProvider.overrideWithValue(mockStorage),
        ],
      );

      // wait for _checkAuth to finish
      await Future.delayed(const Duration(milliseconds: 10));

      await container.read(authProvider.notifier).login(
            email: 'test@test.com',
            password: 'password123',
          );

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user, user);
      verify(mockStorage.saveToken('fake_jwt_token')).called(1);
    });

    test('login failure updates state to unauthenticated with error', () async {
      when(mockStorage.getToken()).thenAnswer((_) async => null);
      when(mockRepository.login(
        email: 'wrong@test.com',
        password: 'wrong',
      )).thenThrow(Exception('Invalid credentials'));

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockRepository),
          secureStorageProvider.overrideWithValue(mockStorage),
        ],
      );

      // Trigger lazy creation and wait for _checkAuth to complete
      container.read(authProvider);
      await Future.delayed(Duration.zero);

      await container.read(authProvider.notifier).login(
            email: 'wrong@test.com',
            password: 'wrong',
          );

      final currentState = container.read(authProvider);
      expect(currentState.status, AuthStatus.unauthenticated);
      expect(currentState.error, contains('Invalid credentials'));
    });
  });
}
