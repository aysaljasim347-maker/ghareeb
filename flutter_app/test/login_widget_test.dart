import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/features/auth/presentation/login_screen.dart';
import 'package:reliefnet_app/features/auth/presentation/auth_provider.dart';
import 'package:reliefnet_app/features/auth/data/auth_repository.dart';
import 'package:reliefnet_app/core/storage/secure_storage.dart';
import 'package:reliefnet_app/features/auth/domain/user_model.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:go_router/go_router.dart';

@GenerateNiceMocks([MockSpec<AuthRepository>(), MockSpec<SecureStorageService>()])
import 'login_widget_test.mocks.dart';

void main() {
  late MockAuthRepository mockRepository;
  late MockSecureStorageService mockStorage;

  setUp(() {
    mockRepository = MockAuthRepository();
    mockStorage = MockSecureStorageService();
    when(mockStorage.getToken()).thenAnswer((_) async => null);
  });

  Widget createTestWidget() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const Scaffold(body: Text('Dashboard')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepository),
        secureStorageProvider.overrideWithValue(mockStorage),
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('shows validation errors when fields are empty', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows loading indicator during login and navigates on success', (tester) async {
      when(mockRepository.login(
        email: 'test@test.com',
        password: 'password123',
      )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return (
          user: const UserModel(id: 1, name: 'T', role: UserRole.donor),
          token: 't'
        );
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'test@test.com');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      
      await tester.tap(find.text('Sign In'));
      await tester.pump(); // Start frame

      // Check for loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      await tester.pumpAndSettle(); // Finish animations and navigation

      // Should be on dashboard
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('shows error snackbar on login failure', (tester) async {
      when(mockRepository.login(
        email: 'wrong@test.com',
        password: 'wrong',
      )).thenThrow(Exception('Access Denied'));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'wrong@test.com');
      await tester.enterText(find.byType(TextFormField).last, 'wrong');
      
      await tester.tap(find.text('Sign In'));
      await tester.pump(); // Start request
      await tester.pump(); // Transition to error state
      await tester.pump(const Duration(milliseconds: 100)); // Show Snackbar

      expect(find.textContaining('Access Denied'), findsOneWidget);
    });
  });
}
