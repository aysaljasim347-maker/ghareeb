import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:disasteraid_app/features/auth/presentation/auth_provider.dart';
import 'package:disasteraid_app/core/theme/app_theme.dart';

/// Dashboard shell with bottom navigation.
class DashboardShell extends ConsumerWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final currentIndex = _calculateIndex(GoRouterState.of(context).matchedLocation);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => _onTabSelected(context, index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.task_outlined),
            selectedIcon: Icon(Icons.task),
            label: 'Tasks',
          ),
          const NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outlined),
            selectedIcon: const Icon(Icons.person),
            label: authState.user?.name ?? 'Profile',
          ),
        ],
      ),
      floatingActionButton: authState.user?.isVolunteer == false
          ? FloatingActionButton.extended(
              onPressed: () {
                // TODO: Navigate to create task / donate screen
              },
              icon: const Icon(Icons.add),
              label: Text(
                authState.user?.isDonor == true ? 'Donate' : 'New Task',
              ),
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  int _calculateIndex(String location) {
    if (location.startsWith('/tasks')) return 1;
    if (location.startsWith('/chat')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onTabSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/tasks');
        break;
      case 2:
        context.go('/dashboard'); // Chat route TBD
        break;
      case 3:
        context.go('/dashboard'); // Profile route TBD
        break;
    }
  }
}
