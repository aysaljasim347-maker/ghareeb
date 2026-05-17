import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:disasteraid_app/providers/coordinator_volunteers_provider.dart';
import 'package:disasteraid_app/widgets/empty_state.dart';
import 'package:disasteraid_app/widgets/error_view.dart';

class CoordinatorVolunteerScreen extends ConsumerWidget {
  const CoordinatorVolunteerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volunteersAsync = ref.watch(coordinatorVolunteersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Volunteers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(coordinatorVolunteersProvider),
          ),
        ],
      ),
      body: volunteersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(
          message: 'Could not load volunteers.',
          onRetry: () => ref.invalidate(coordinatorVolunteersProvider),
        ),
        data: (volunteers) {
          if (volunteers.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'No volunteers found',
              subtitle: 'Volunteers assigned to your tasks will appear here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: volunteers.length,
            itemBuilder: (context, index) {
              final volunteer = volunteers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(volunteer.name[0].toUpperCase()),
                        ),
                        title: Text(volunteer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(volunteer.email, style: const TextStyle(fontSize: 12)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: volunteer.status == 'ACTIVE' ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            volunteer.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: volunteer.status == 'ACTIVE' ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(label: 'Active Tasks', value: volunteer.activeTasks.toString()),
                          _StatItem(label: 'Completed', value: volunteer.completedTasks.toString()),
                          _StatItem(label: 'Rating', value: volunteer.rating.toStringAsFixed(1)),
                        ],
                      ),
                      if (volunteer.lastActivity != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Last Activity: ${DateFormat('MMM D, HH:mm').format(DateTime.parse(volunteer.lastActivity!))}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
