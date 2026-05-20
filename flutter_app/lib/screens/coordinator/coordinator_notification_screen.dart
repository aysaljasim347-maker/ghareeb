import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reliefnet_app/providers/notification_provider.dart';
import 'package:reliefnet_app/widgets/empty_state.dart';

class CoordinatorNotificationScreen extends ConsumerWidget {
  const CoordinatorNotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operational Alerts'),
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
              title: 'No recent updates',
              subtitle: 'Operational alerts and system notifications will appear here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return _NotificationTile(item: item);
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: _getBgColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _getBorderColor(context)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: _getIconColor(context).withValues(alpha: 0.2),
          child: Icon(_getIcon(), color: _getIconColor(context), size: 20),
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
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        onTap: item.taskId != 0 ? () => context.push('/coordinator/task/${item.taskId}') : null,
      ),
    );
  }

  IconData _getIcon() {
    switch (item.type) {
      case 'BROADCAST': return Icons.campaign;
      case 'TASK_STATUS_UPDATE': return Icons.update;
      case 'DELIVERY_SUBMITTED': return Icons.fact_check;
      default: return Icons.notifications;
    }
  }

  Color _getIconColor(BuildContext context) {
    switch (item.type) {
      case 'BROADCAST': return Colors.red;
      case 'DELIVERY_SUBMITTED': return Colors.blue;
      default: return Theme.of(context).colorScheme.primary;
    }
  }

  Color _getBgColor(BuildContext context) {
    if (item.type == 'BROADCAST') return Colors.red.shade50.withValues(alpha: 0.3);
    return Theme.of(context).colorScheme.surface;
  }

  Color _getBorderColor(BuildContext context) {
    if (item.type == 'BROADCAST') return Colors.red.shade100;
    return Colors.grey.shade200;
  }
}
