import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:disasteraid_app/features/auth/presentation/auth_provider.dart';
import 'package:disasteraid_app/features/auth/presentation/login_screen.dart';
import 'package:disasteraid_app/features/auth/presentation/register_screen.dart';
import 'package:disasteraid_app/features/tasks/presentation/tasks_screen.dart';
import 'package:disasteraid_app/features/tasks/presentation/task_detail_screen.dart';
import 'package:disasteraid_app/core/shell/dashboard_shell.dart';

/// GoRouter provider with auth-based redirects.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.status == AuthStatus.authenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // Still loading auth — don't redirect yet
      if (authState.status == AuthStatus.initial) return null;

      // Not authenticated and not on auth route → go to login
      if (!isAuthenticated && !isAuthRoute) return '/login';

      // Authenticated and on auth route → go to dashboard
      if (isAuthenticated && isAuthRoute) return '/dashboard';

      return null;
    },
    routes: [
      // ── Auth Routes ──
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ── Dashboard Shell ──
      ShellRoute(
        builder: (context, state, child) => DashboardShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const TasksScreen(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TasksScreen(),
          ),
          GoRoute(
            path: '/tasks/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return TaskDetailScreen(taskId: id);
            },
          ),
        ],
      ),
    ],
  );
});
