import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:disasteraid_app/features/auth/presentation/auth_provider.dart';
import 'package:disasteraid_app/providers/beneficiary_task_provider.dart';

class EmergencyRequestScreen extends ConsumerStatefulWidget {
  const EmergencyRequestScreen({super.key});

  @override
  ConsumerState<EmergencyRequestScreen> createState() =>
      _EmergencyRequestScreenState();
}

class _EmergencyRequestScreenState
    extends ConsumerState<EmergencyRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String _category = 'OTHER';

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    final body = {
      'title': '🚨 EMERGENCY: $_category Request',
      'description': _descriptionController.text.trim(),
      'category': _category,
      'urgency': 'CRITICAL',
      'source_type': 'BENEFICIARY_REQUEST',
      'is_emergency': true,
      // Default location logic can be added here if available
    };

    await ref.read(createTaskProvider.notifier).submit(
          userId: userId,
          body: body,
        );

    if (mounted &&
        ref.read(createTaskProvider).status == CreateTaskStatus.success) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency request broadcasted!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createTaskProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Request'),
        backgroundColor: Colors.red.shade50,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This will alert nearby volunteers immediately.',
                        style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('What is needed urgently?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ['FOOD', 'MEDICAL', 'SHELTER', 'RESCUE', 'OTHER']
                    .map((cat) {
                  final isSelected = _category == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: Colors.red.shade100,
                    onSelected: (val) => setState(() => _category = cat),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Brief Details',
                  hintText: 'e.g. Trapped in building or need oxygen',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (v) => v == null || v.isEmpty
                    ? 'Please describe the emergency'
                    : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed:
                      state.status == CreateTaskStatus.loading ? null : _submit,
                  child: state.status == CreateTaskStatus.loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'SEND EMERGENCY ALERT',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
