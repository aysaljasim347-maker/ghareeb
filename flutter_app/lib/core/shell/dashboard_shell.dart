import 'package:reliefnet_app/features/auth/domain/user_model.dart';
import 'package:reliefnet_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reliefnet_app/features/auth/presentation/auth_provider.dart';
import 'package:reliefnet_app/providers/chat_provider.dart';
import 'package:reliefnet_app/providers/notification_provider.dart';

/// Role-aware bottom navigation shell.
class DashboardShell extends ConsumerWidget {
  final Widget child;
  final String? role;

  const DashboardShell({super.key, required this.child, this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final UserRole? effectiveRole =
        role != null ? UserRole.fromString(role!) : authState.user?.role;
    final loc = GoRouterState.of(context).matchedLocation;

    // Listen for real-time notifications
    ref.listen<List<AppNotification>>(notificationProvider, (prev, next) {
      if (next.length > (prev?.length ?? 0)) {
        final latest = next.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(latest.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(latest.message),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View',
              onPressed: () => _navigateToNotification(context, effectiveRole, latest),
            ),
          ),
        );
      }
    });

    return Scaffold(
      body: child,
      bottomNavigationBar:
          _buildNavBar(context, effectiveRole, loc, ref, authState),
      floatingActionButton: _buildFab(context, effectiveRole),
    );
  }

  void _navigateToNotification(
    BuildContext context,
    UserRole? role,
    AppNotification notification,
  ) {
    switch (role) {
      case UserRole.beneficiary:
        if (notification.taskId > 0) {
          context.push('/beneficiary/task/${notification.taskId}');
        } else {
          context.push('/beneficiary/notifications');
        }
        break;
      case UserRole.coordinator:
        context.push('/coordinator/notifications');
        break;
      case UserRole.volunteer:
        if (notification.taskId > 0) {
          context.push('/volunteer/task/${notification.taskId}');
        } else {
          context.push('/volunteer/activity');
        }
        break;
      default:
        break;
    }
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        ref.invalidate(chatProvider);
        ref.read(authProvider.notifier).logout();
      }
    });
  }

  void _showMoreSheet(
    BuildContext context,
    WidgetRef ref,
    AuthState authState,
    UserRole? role,
  ) {
    final name = authState.user?.name ?? 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final roleLabel = role?.name.toUpperCase() ?? '';

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            // drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: roleLabel.isNotEmpty
                  ? Text(roleLabel, style: const TextStyle(fontSize: 12))
                  : null,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_outlined, color: Colors.red),
              title: const Text('Sign out',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.of(ctx).pop();
                _showLogoutDialog(context, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget? _buildFab(BuildContext context, UserRole? role) {
    switch (role) {
      case UserRole.beneficiary:
        return FloatingActionButton.extended(
          heroTag: 'shell_new_request_fab',
          onPressed: () => context.push('/beneficiary/create-task'),
          icon: const Icon(Icons.add),
          label: const Text('New Request'),
          backgroundColor: AppTheme.accentColor,
          foregroundColor: Colors.white,
        );
      case UserRole.donor:
        return FloatingActionButton.extended(
          heroTag: 'shell_donate_item_fab',
          onPressed: () => context.push('/donor/inkind/create'),
          icon: const Icon(Icons.volunteer_activism),
          label: const Text('Donate Item'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        );
      default:
        return null;
    }
  }

  Widget? _buildNavBar(
    BuildContext context,
    UserRole? role,
    String loc,
    WidgetRef ref,
    AuthState authState,
  ) {
    switch (role) {
      case UserRole.beneficiary:
        return NavigationBar(
          selectedIndex: _beneficiaryIndex(loc),
          onDestinationSelected: (i) {
            if (i == 2) {
              _showMoreSheet(context, ref, authState, role);
            } else {
              _beneficiaryNav(context, i);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'My Requests',
            ),
            NavigationDestination(
              icon: Icon(Icons.volunteer_activism_outlined),
              selectedIcon: Icon(Icons.volunteer_activism),
              label: 'InKind Board',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_outlined),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        );

      case UserRole.donor:
        return NavigationBar(
          selectedIndex: _donorIndex(loc),
          onDestinationSelected: (i) {
            if (i == 4) {
              _showMoreSheet(context, ref, authState, role);
            } else {
              _donorNav(context, i);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: 'Campaigns',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'Donations',
            ),
            NavigationDestination(
              icon: Icon(Icons.volunteer_activism_outlined),
              selectedIcon: Icon(Icons.volunteer_activism),
              label: 'InKind',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_graph_outlined),
              selectedIcon: Icon(Icons.auto_graph),
              label: 'Impact',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_outlined),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        );

      case UserRole.volunteer:
        return NavigationBar(
          selectedIndex: _volunteerIndex(loc),
          onDestinationSelected: (i) {
            if (i == 4) {
              _showMoreSheet(context, ref, authState, role);
            } else {
              _volunteerNav(context, i);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Impact',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'Discover',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_outlined),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        );

      case UserRole.ngo:
        return NavigationBar(
          selectedIndex: _ngoIndex(loc),
          onDestinationSelected: (i) {
            if (i == 3) {
              _showMoreSheet(context, ref, authState, role);
            } else {
              _ngoNav(context, i);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.business_center_outlined),
              selectedIcon: Icon(Icons.business_center),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: 'Campaigns',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'Impact',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_outlined),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        );

      case UserRole.coordinator:
        return NavigationBar(
          selectedIndex: _coordinatorIndex(loc),
          onDestinationSelected: (i) {
            if (i == 4) {
              _showMoreSheet(context, ref, authState, role);
            } else {
              _coordinatorNav(context, i);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.assignment_ind_outlined),
              selectedIcon: Icon(Icons.assignment_ind),
              label: 'Tasks',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check),
              label: 'Review',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Intelligence',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Volunteers',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_outlined),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        );

      default:
        return NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (i) {
            if (i == 1) _showMoreSheet(context, ref, authState, role);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: authState.user?.name ?? 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.more_horiz_outlined),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        );
    }
  }

  // ── Index helpers ──

  int _beneficiaryIndex(String loc) {
    if (loc.startsWith('/beneficiary/tasks')) return 0;
    if (loc.startsWith('/beneficiary/inkind')) return 1;
    return 0;
  }

  int _donorIndex(String loc) {
    if (loc.startsWith('/donor/campaigns')) return 0;
    if (loc.startsWith('/donor/donations')) return 1;
    if (loc.startsWith('/donor/inkind')) return 2;
    if (loc.startsWith('/donor/impact')) return 3;
    return 0;
  }

  int _volunteerIndex(String loc) {
    if (loc.startsWith('/volunteer/dashboard')) return 0;
    if (loc.startsWith('/volunteer/tasks')) return 1;
    if (loc.startsWith('/volunteer/activity')) return 2;
    if (loc.startsWith('/volunteer/profile')) return 3;
    return 0;
  }

  int _ngoIndex(String loc) {
    if (loc.startsWith('/ngo/dashboard')) return 0;
    if (loc.startsWith('/ngo/campaigns')) return 1;
    if (loc.startsWith('/ngo/impact')) return 2;
    return 0;
  }

  int _coordinatorIndex(String loc) {
    if (loc.startsWith('/coordinator/tasks')) return 0;
    if (loc.startsWith('/coordinator/review')) return 1;
    if (loc.startsWith('/coordinator/intelligence')) return 2;
    if (loc.startsWith('/coordinator/volunteers')) return 3;
    return 0;
  }

  // ── Nav helpers ──

  void _beneficiaryNav(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/beneficiary/tasks');
        break;
      case 1:
        context.go('/beneficiary/inkind');
        break;
    }
  }

  void _donorNav(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/donor/campaigns');
        break;
      case 1:
        context.go('/donor/donations');
        break;
      case 2:
        context.go('/donor/inkind');
        break;
      case 3:
        context.go('/donor/impact');
        break;
    }
  }

  void _volunteerNav(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/volunteer/dashboard');
        break;
      case 1:
        context.go('/volunteer/tasks');
        break;
      case 2:
        context.go('/volunteer/activity');
        break;
      case 3:
        context.go('/volunteer/profile');
        break;
    }
  }

  void _ngoNav(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/ngo/dashboard');
        break;
      case 1:
        context.go('/ngo/campaigns');
        break;
      case 2:
        context.go('/ngo/impact');
        break;
    }
  }

  void _coordinatorNav(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/coordinator/tasks');
        break;
      case 1:
        context.go('/coordinator/review');
        break;
      case 2:
        context.go('/coordinator/intelligence');
        break;
      case 3:
        context.go('/coordinator/volunteers');
        break;
    }
  }
}
