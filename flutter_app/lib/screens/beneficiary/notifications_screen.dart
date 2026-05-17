import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:disasteraid_app/providers/notification_provider.dart';
import 'package:disasteraid_app/widgets/empty_state.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(notificationProvider.notifier).clear(),
              child: const Text('Clear All'),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'No notifications',
              subtitle: 'We\'ll notify you when your requests are updated.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: _getColor(item.type, context),
                      child: Icon(_getIcon(item.type), color: Colors.white, size: 20),
                    ),
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(item.message),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('MMM d, HH:mm').format(item.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => context.push('/beneficiary/task/${item.taskId}'),
                  ),
                );
              },
            ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'TASK_CLAIMED':
        return Icons.volunteer_activism;
      case 'DELIVERY_SUBMITTED':
        return Icons.local_shipping;
      case 'TASK_STATUS_UPDATE':
        return Icons.update;
      default:
        return Icons.notifications;
    }
  }

  Color _getColor(String type, BuildContext context) {
    switch (type) {
      case 'TASK_CLAIMED':
        return Colors.blue;
      case 'DELIVERY_SUBMITTED':
        return Colors.green;
      case 'TASK_STATUS_UPDATE':
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
}
