import 'package:disasteraid_app/features/auth/domain/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:disasteraid_app/features/auth/presentation/auth_provider.dart';
import 'package:disasteraid_app/features/auth/presentation/login_screen.dart';
import 'package:disasteraid_app/features/auth/presentation/register_screen.dart';
import 'package:disasteraid_app/features/tasks/presentation/tasks_screen.dart';
import 'package:disasteraid_app/core/shell/dashboard_shell.dart';

// ── Beneficiary screens ──
import 'package:disasteraid_app/screens/beneficiary/create_task_screen.dart';
import 'package:disasteraid_app/screens/beneficiary/my_tasks_screen.dart';

// ── Donor screens ──
import 'package:disasteraid_app/screens/donor/campaigns_screen.dart';
import 'package:disasteraid_app/screens/donor/donation_history_screen.dart';
import 'package:disasteraid_app/screens/donor/payment_screen.dart';

// ── Volunteer screens ──
import 'package:disasteraid_app/screens/volunteer/task_detail_screen.dart';
import 'package:disasteraid_app/screens/volunteer/proof_upload_screen.dart';

// ── Shared screens ──
import 'package:disasteraid_app/screens/shared/chat_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isAuthenticated = authState.status == AuthStatus.authenticated;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register';

      if (authState.status == AuthStatus.initial) return null;

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) {
        return _roleHome(authState.user?.role);
      }

      return null;
    },
    routes: [
      // ── Auth ──
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),

      // ── Beneficiary Shell ──
      ShellRoute(
        builder: (context, state, child) =>
            DashboardShell(role: 'BENEFICIARY', child: child),
        routes: [
          GoRoute(
            path: '/beneficiary/tasks',
            builder: (_, __) => const MyTasksScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/beneficiary/create-task',
        builder: (_, __) => const CreateTaskScreen(),
      ),

      // ── Donor Shell ──
      ShellRoute(
        builder: (context, state, child) =>
            DashboardShell(role: 'DONOR', child: child),
        routes: [
          GoRoute(
            path: '/donor/campaigns',
            builder: (_, __) => const CampaignsScreen(),
          ),
          GoRoute(
            path: '/donor/donations',
            builder: (_, __) => const DonationHistoryScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/donor/payment/:campaignId',
        builder: (_, state) => PaymentScreen(
          campaignId: int.parse(state.pathParameters['campaignId']!),
        ),
      ),

      // ── Volunteer Shell ──
      ShellRoute(
        builder: (context, state, child) =>
            DashboardShell(role: 'VOLUNTEER', child: child),
        routes: [
          GoRoute(
            path: '/volunteer/tasks',
            builder: (_, __) => const TasksScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/volunteer/task/:id',
        builder: (_, state) => VolunteerTaskDetailScreen(
          taskId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/volunteer/proof/:taskId',
        builder: (_, state) => ProofUploadScreen(
          taskId: int.parse(state.pathParameters['taskId']!),
        ),
      ),

      // ── Shared ──
      GoRoute(
        path: '/chat/:taskId',
        builder: (_, state) => ChatScreen(
          taskId: int.parse(state.pathParameters['taskId']!),
          taskTitle: state.uri.queryParameters['title'],
        ),
      ),

      // ── Legacy / generic task routes ──
      ShellRoute(
        builder: (context, state, child) =>
            DashboardShell(role: null, child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const TasksScreen(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (_, __) => const TasksScreen(),
          ),
        ],
      ),
    ],
  );
});

String _roleHome(UserRole? role) {
  switch (role) {
    case UserRole.beneficiary:
      return '/beneficiary/tasks';
    case UserRole.donor:
      return '/donor/campaigns';
    case UserRole.volunteer:
      return '/volunteer/tasks';
    default:
      return '/dashboard';
  }
}
