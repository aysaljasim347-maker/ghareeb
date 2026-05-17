import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:disasteraid_app/providers/coordinator_intelligence_provider.dart';
import 'package:disasteraid_app/screens/coordinator/coordinator_tasks_screen.dart';

class CoordinatorBroadcastScreen extends ConsumerStatefulWidget {
  const CoordinatorBroadcastScreen({super.key});

  @override
  ConsumerState<CoordinatorBroadcastScreen> createState() =>
      _CoordinatorBroadcastScreenState();
}

class _CoordinatorBroadcastScreenState
    extends ConsumerState<CoordinatorBroadcastScreen> {
  final _messageController = TextEditingController();
  String _scope = 'TASK';
  String _urgency = 'MEDIUM';
  int? _targetId;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    if (_messageController.text.isEmpty || _targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    try {
      await ref.read(intelligenceActionProvider.notifier).broadcast(
            scope: _scope,
            targetId: _targetId.toString(),
            message: _messageController.text.trim(),
            urgency: _urgency,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broadcast sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(coordinatorTasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Broadcast')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scope', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _scope,
              items: ['TASK', 'CAMPAIGN', 'NGO']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _scope = v!),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            const Text('Target', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            tasksAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error loading targets'),
              data: (tasks) => DropdownButtonFormField<int>(
                hint: const Text('Select target ID'),
                initialValue: _targetId,
                items: tasks
                    .map((t) => DropdownMenuItem(
                        value: t.id, child: Text('${t.title} (#${t.id})')))
                    .toList(),
                onChanged: (v) => setState(() => _targetId = v),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Urgency',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'LOW', label: Text('Low')),
                ButtonSegment(value: 'MEDIUM', label: Text('Medium')),
                ButtonSegment(value: 'HIGH', label: Text('High')),
              ],
              selected: {_urgency},
              onSelectionChanged: (val) => setState(() => _urgency = val.first),
            ),
            const SizedBox(height: 24),
            const Text('Message',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter operational alert message...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _sendBroadcast,
                icon: const Icon(Icons.send),
                label: const Text('Dispatch Alert',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
