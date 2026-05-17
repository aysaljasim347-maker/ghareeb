import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:disasteraid_app/features/tasks/domain/task_model.dart';
import 'package:disasteraid_app/providers/beneficiary_task_provider.dart';

class EditTaskScreen extends ConsumerStatefulWidget {
  final int taskId;

  const EditTaskScreen({super.key, required this.taskId});

  @override
  ConsumerState<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends ConsumerState<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  String? _category;
  TaskUrgency _urgency = TaskUrgency.medium;
  double? _latitude;
  double? _longitude;
  bool _initialized = false;
  bool _fetchingLocation = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _initFields(TaskModel task) {
    if (_initialized) return;
    _titleController.text = task.title;
    _descriptionController.text = task.description ?? '';
    _locationController.text = task.locationText ?? '';
    _category = task.category;
    _urgency = task.urgency;
    _latitude = task.latitude;
    _longitude = task.longitude;
    _initialized = true;
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _fetchingLocation = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated to current GPS')),
        );
      }
    } catch (e) {
      setState(() => _fetchingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final body = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _category,
      'urgency': _urgency.value,
      'location_text': _locationController.text.trim(),
      if (_latitude != null) 'latitude': _latitude,
      if (_longitude != null) 'longitude': _longitude,
    };

    await ref.read(taskActionProvider.notifier).update(widget.taskId, body);

    if (mounted && !ref.read(taskActionProvider).hasError) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(beneficiaryTaskDetailProvider(widget.taskId));
    final actionState = ref.watch(taskActionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Request'),
      ),
      body: taskAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (task) {
          _initFields(task);

          if (task.status != TaskStatus.open) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                      'This task cannot be edited because it is already claimed.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g. Need medical supplies',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: ['FOOD', 'MEDICAL', 'SHELTER', 'CLOTHING', 'OTHER']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Provide details about your needs',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: 'Location (Optional)',
                      hintText: 'Enter address or landmarks',
                      suffixIcon: IconButton(
                        icon: _fetchingLocation
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location),
                        onPressed:
                            _fetchingLocation ? null : _getCurrentLocation,
                        tooltip: 'Use current location',
                      ),
                    ),
                  ),
                  if (_latitude != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Coordinates: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text('Urgency',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SegmentedButton<TaskUrgency>(
                    segments: const [
                      ButtonSegment(value: TaskUrgency.low, label: Text('Low')),
                      ButtonSegment(
                          value: TaskUrgency.medium, label: Text('Medium')),
                      ButtonSegment(
                          value: TaskUrgency.high, label: Text('High')),
                    ],
                    selected: {_urgency},
                    onSelectionChanged: (val) =>
                        setState(() => _urgency = val.first),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: actionState.isLoading ? null : _submit,
                      child: actionState.isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
