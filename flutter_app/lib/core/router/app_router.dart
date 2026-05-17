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
import 'package:disasteraid_app/screens/beneficiary/task_detail_screen.dart';
import 'package:disasteraid_app/screens/beneficiary/edit_task_screen.dart';
import 'package:disasteraid_app/screens/beneficiary/emergency_request_screen.dart';
import 'package:disasteraid_app/screens/beneficiary/notifications_screen.dart';

// ── Donor screens ──
import 'package:disasteraid_app/screens/donor/campaigns_screen.dart';
import 'package:disasteraid_app/screens/donor/campaign_detail_screen.dart';
import 'package:disasteraid_app/screens/donor/ngo_profile_screen.dart';
import 'package:disasteraid_app/screens/donor/donation_history_screen.dart';
import 'package:disasteraid_app/screens/donor/payment_screen.dart';
import 'package:disasteraid_app/screens/donor/impact_dashboard_screen.dart';
import 'package:disasteraid_app/screens/donor/activity_feed_screen.dart';
import 'package:disasteraid_app/screens/donor/followed_campaigns_screen.dart';

// ── Volunteer screens ──
import 'package:disasteraid_app/screens/volunteer/volunteer_dashboard_screen.dart';
import 'package:disasteraid_app/screens/volunteer/activity_timeline_screen.dart';
import 'package:disasteraid_app/screens/volunteer/volunteer_profile_screen.dart';
import 'package:disasteraid_app/screens/volunteer/task_detail_screen.dart';
import 'package:disasteraid_app/screens/volunteer/proof_upload_screen.dart';

// ── NGO screens ──
import 'package:disasteraid_app/screens/ngo/ngo_dashboard_screen.dart';
import 'package:disasteraid_app/screens/ngo/ngo_impact_dashboard_screen.dart';
import 'package:disasteraid_app/screens/ngo/ngo_campaigns_screen.dart';
import 'package:disasteraid_app/screens/ngo/campaign_report_screen.dart';
import 'package:disasteraid_app/screens/ngo/ngo_withdrawal_screen.dart';

// ── Coordinator screens ──
import 'package:disasteraid_app/screens/coordinator/coordinator_tasks_screen.dart';
import 'package:disasteraid_app/screens/coordinator/coordinator_submitted_tasks_screen.dart';
import 'package:disasteraid_app/screens/coordinator/coordinator_delivery_review_screen.dart';
import 'package:disasteraid_app/screens/coordinator/coordinator_task_detail_screen.dart';
import 'package:disasteraid_app/screens/coordinator/coordinator_map_screen.dart';
import 'package:disasteraid_app/screens/coordinator/coordinator_volunteer_screen.dart';
import 'package:disasteraid_app/screens/coordinator/coordinator_intelligence_dashboard_screen.dart';
import 'package:disasteraid_app/screens/coordinator/coordinator_fraud_signals_screen.dart';
import 'package:disasteraid_app/screens/coordinator/coordinator_escalation_history_screen.dart';
import 'package:disasteraid_app/screens/coordinator/coordinator_notification_screen.dart';
import 'package:disasteraid_app/screens/coordinator/coordinator_broadcast_screen.dart';
import 'package:disasteraid_app/screens/coordinator/coordinator_live_dashboard_screen.dart';

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
          GoRoute(
            path: '/beneficiary/task/:id',
            builder: (_, state) => BeneficiaryTaskDetailScreen(
              taskId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/beneficiary/task/:id/edit',
            builder: (_, state) => EditTaskScreen(
              taskId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/beneficiary/emergency-request',
            builder: (_, __) => const EmergencyRequestScreen(),
          ),
          GoRoute(
            path: '/beneficiary/notifications',
            builder: (_, __) => const NotificationsScreen(),
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
          GoRoute(
            path: '/donor/impact',
            builder: (_, __) => const ImpactDashboardScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/donor/payment/:campaignId',
        builder: (_, state) => PaymentScreen(
          campaignId: int.parse(state.pathParameters['campaignId']!),
        ),
      ),
      GoRoute(
        path: '/donor/campaign/:id',
        builder: (_, state) => CampaignDetailScreen(
          campaignId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/donor/ngo/:ngoId',
        builder: (_, state) => NgoProfileScreen(
          ngoId: int.parse(state.pathParameters['ngoId']!),
        ),
      ),
      GoRoute(
        path: '/donor/activity',
        builder: (_, __) => const ActivityFeedScreen(),
      ),
      GoRoute(
        path: '/donor/followed',
        builder: (_, __) => const FollowedCampaignsScreen(),
      ),

      // ── Volunteer Shell ──
      ShellRoute(
        builder: (context, state, child) =>
            DashboardShell(role: 'VOLUNTEER', child: child),
        routes: [
          GoRoute(
            path: '/volunteer/dashboard',
            builder: (_, __) => const VolunteerDashboardScreen(),
          ),
          GoRoute(
            path: '/volunteer/tasks',
            builder: (_, __) => const TasksScreen(),
          ),
          GoRoute(
            path: '/volunteer/activity',
            builder: (_, __) => const ActivityTimelineScreen(),
          ),
          GoRoute(
            path: '/volunteer/profile',
            builder: (_, __) => const VolunteerProfileScreen(),
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

      // ── NGO Shell ──
      ShellRoute(
        builder: (context, state, child) =>
            DashboardShell(role: 'NGO', child: child),
        routes: [
          GoRoute(
            path: '/ngo/dashboard',
            builder: (_, __) => const NgoDashboardScreen(),
          ),
          GoRoute(
            path: '/ngo/campaigns',
            builder: (_, __) => const NgoCampaignsScreen(),
          ),
          GoRoute(
            path: '/ngo/impact',
            builder: (_, __) => const NgoImpactDashboardScreen(),
          ),
        ],
      ),

      // ── NGO sub-routes (no shell — full-screen) ──
      GoRoute(
        path: '/ngo/withdrawals',
        builder: (_, __) => const NgoWithdrawalScreen(),
      ),
      GoRoute(
        path: '/ngo/campaign-report/:id',
        builder: (_, state) => CampaignReportScreen(
          campaignId: int.parse(state.pathParameters['id']!),
        ),
      ),

      // ── Coordinator Shell ──
      ShellRoute(
        builder: (context, state, child) =>
            DashboardShell(role: 'COORDINATOR', child: child),
        routes: [
          GoRoute(
            path: '/coordinator/tasks',
            builder: (_, __) => const CoordinatorTasksScreen(),
          ),
          GoRoute(
            path: '/coordinator/map',
            builder: (_, __) => const CoordinatorMapScreen(),
          ),
          GoRoute(
            path: '/coordinator/volunteers',
            builder: (_, __) => const CoordinatorVolunteerScreen(),
          ),
          GoRoute(
            path: '/coordinator/review',
            builder: (_, __) => const CoordinatorSubmittedTasksScreen(),
          ),
          GoRoute(
            path: '/coordinator/intelligence',
            builder: (_, __) => const CoordinatorIntelligenceDashboard(),
          ),
          GoRoute(
            path: '/coordinator/signals',
            builder: (_, __) => const CoordinatorFraudSignalsScreen(),
          ),
          GoRoute(
            path: '/coordinator/escalations',
            builder: (_, __) => const CoordinatorEscalationHistoryScreen(),
          ),
          GoRoute(
            path: '/coordinator/notifications',
            builder: (_, __) => const CoordinatorNotificationScreen(),
          ),
          GoRoute(
            path: '/coordinator/broadcast',
            builder: (_, __) => const CoordinatorBroadcastScreen(),
          ),
          GoRoute(
            path: '/coordinator/live',
            builder: (_, __) => const CoordinatorLiveDashboardScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/coordinator/review/:id',
        builder: (_, state) => CoordinatorDeliveryReviewScreen(
          taskId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/coordinator/task/:id',
        builder: (_, state) => CoordinatorTaskDetailScreen(
          taskId: int.parse(state.pathParameters['id']!),
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
      return '/volunteer/dashboard';
    case UserRole.ngo:
      return '/ngo/dashboard';
    case UserRole.coordinator:
      return '/coordinator/tasks';
    default:
      return '/dashboard';
  }
}
