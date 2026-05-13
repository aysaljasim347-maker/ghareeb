import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:disasteraid_app/features/auth/presentation/auth_provider.dart';

/// Role-aware bottom navigation shell.
class DashboardShell extends ConsumerWidget {
  final Widget child;
  final String? role;

  const DashboardShell({super.key, required this.child, this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final effectiveRole = role ?? authState.user?.role;
    final loc = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: child,
      bottomNavigationBar:
          _buildNavBar(context, effectiveRole, loc, ref, authState),
      floatingActionButton:
          _buildFab(context, effectiveRole),
    );
  }

  Widget? _buildFab(BuildContext context, String? role) {
    switch (role) {
      case 'BENEFICIARY':
        return FloatingActionButton.extended(
          onPressed: () => context.push('/beneficiary/create-task'),
          icon: const Icon(Icons.add),
          label: const Text('New Request'),
          backgroundColor: const Color(0xFFFF6B35),
          foregroundColor: Colors.white,
        );
      case 'DONOR':
        return null;
      default:
        return null;
    }
  }

  Widget? _buildNavBar(
    BuildContext context,
    String? role,
    String loc,
    WidgetRef ref,
    AuthState authState,
  ) {
    switch (role) {
      case 'BENEFICIARY':
        return NavigationBar(
          selectedIndex: _beneficiaryIndex(loc),
          onDestinationSelected: (i) => _beneficiaryNav(context, i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'My Requests',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_outlined),
              selectedIcon: Icon(Icons.chat),
              label: 'Chat',
            ),
          ],
        );

      case 'DONOR':
        return NavigationBar(
          selectedIndex: _donorIndex(loc),
          onDestinationSelected: (i) => _donorNav(context, i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: 'Campaigns',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'My Donations',
            ),
          ],
        );

      case 'VOLUNTEER':
        return NavigationBar(
          selectedIndex: _volunteerIndex(loc),
          onDestinationSelected: (i) => _volunteerNav(context, i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Tasks',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_outlined),
              selectedIcon: Icon(Icons.chat),
              label: 'Chat',
            ),
          ],
        );

      default:
        return NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (i) {},
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: authState.user?.name ?? 'Home',
            ),
          ],
        );
    }
  }

  // ── Index helpers ──

  int _beneficiaryIndex(String loc) {
    if (loc.startsWith('/beneficiary/tasks')) return 0;
    if (loc.startsWith('/chat')) return 1;
    return 0;
  }

  int _donorIndex(String loc) {
    if (loc.startsWith('/donor/campaigns')) return 0;
    if (loc.startsWith('/donor/donations')) return 1;
    return 0;
  }

  int _volunteerIndex(String loc) {
    if (loc.startsWith('/volunteer/tasks')) return 0;
    if (loc.startsWith('/chat')) return 1;
    return 0;
  }

  // ── Nav helpers ──

  void _beneficiaryNav(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/beneficiary/tasks');
        break;
      case 1:
        context.go('/chat/0');
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
    }
  }

  void _volunteerNav(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/volunteer/tasks');
        break;
      case 1:
        context.go('/chat/0');
        break;
    }
  }
}
