# Flutter Frontend Testing Audit - DisasterAid V2.1
**Date:** 2026-05-12
**Auditor:** Senior QA Engineer & Flutter Testing Specialist
**Scope:** Flutter (Dart), Riverpod, Dio

## 🔴 Critical Test Gaps

### 1. Missing Auth State Transition Tests
**Issue:** The `AuthNotifier` (Riverpod) handles complex logic: checking stored tokens, login/register API calls, and updating `AuthState`. There are ZERO tests for these transitions.
**Why it matters:** If the logic to persist a token after login breaks, the user will be logged out on every app restart. This is a business-critical flow.
**Suggested Test Case:**
```dart
test('login success updates state to authenticated and saves token', () async {
  final container = createContainer(overrides: [
    authRepositoryProvider.overrideWithValue(MockAuthRepository(success: true)),
  ]);
  
  await container.read(authProvider.notifier).login(email: 't@t.com', password: '123');
  
  expect(container.read(authProvider).status, AuthStatus.authenticated);
  verify(mockStorage.saveToken(any)).called(1);
});
```

### 2. Missing Widget Tests for Critical Forms
**Issue:** `LoginScreen` and `RegisterScreen` have validation logic and loading states. None of these are verified.
**Why it matters:** A UI change could accidentally break the "Sign In" button (e.g., keeping it disabled) or stop showing validation errors, leading to a broken user experience that manual QA might miss.
**Suggested Test Case:**
```dart
testWidgets('Login button shows loading indicator during API call', (tester) async {
  await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginScreen())));
  
  await tester.enterText(find.byType(TextFormField).first, 'test@test.com');
  await tester.enterText(find.byType(TextFormField).last, 'password123');
  await tester.tap(find.text('Sign In'));
  
  await tester.pump();
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

### 3. Untested Side-Effects (Invalidation Logic)
**Issue:** The `ClaimNotifier` in `tasks_provider.dart` invalidates the `availableTasksProvider` after a successful claim. This logic is not verified.
**Why it matters:** If the invalidation logic fails, the "Available Tasks" list will show outdated information (tasks that are already claimed), leading to confusing UI and 409 errors from the backend.

---

## 🟠 Medium Test Gaps

### 1. API Error Handling in UI
**Issue:** The app uses `ref.listen` in `LoginScreen` to show Snackbars on error. There are no tests verifying that the Snackbar actually appears when the API returns a 401 or 500.
**Suggested Improvement:** Add widget tests that mock a failing repository and assert `find.byType(SnackBar)`.

### 2. Deep Linking / Navigation Testing
**Issue:** The app uses `go_router` for navigation (e.g., `/tasks/:id`). There are no tests verifying that the router correctly parses params and shows the `TaskDetailScreen`.

---

## 🟢 Minor Improvements

1. **Theme Verification:** No tests ensure that `AppTheme` colors are correctly applied to widgets.
2. **Model Serialization Edge Cases:** While model tests exist, they don't cover "extra" fields in JSON (which should be ignored) or malformed date strings.

---

## ⚠️ Testing Risks

*   **Token Expiry Race Conditions:** If a JWT expires while the user is mid-action, the app relies on `AuthInterceptor` to clear state. Without tests, this logic might "flicker" or cause a crash during the transition.
*   **PostGIS Data Precision:** The `TaskModel` casts coordinates to `double`. If the backend sends coordinates in an unexpected format, the app might crash in the `fromJson` factory.

---

## 🛠 Suggested Test Cases

### 1. Repository Mocking (Riverpod)
```dart
test('TasksRepository.getAvailableTasks handles API errors gracefully', () async {
  final mockClient = MockApiClient();
  when(mockClient.get(any)).thenThrow(DioException(...));
  
  final repo = TasksRepository(client: mockClient);
  expect(() => repo.getAvailableTasks(), throwsA(isA<DioException>()));
});
```

### 2. Validation UI Test
```dart
testWidgets('Login shows validation error on empty email', (tester) async {
  await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginScreen())));
  await tester.tap(find.text('Sign In'));
  await tester.pump();
  
  expect(find.text('Email is required'), findsOneWidget);
});
```
