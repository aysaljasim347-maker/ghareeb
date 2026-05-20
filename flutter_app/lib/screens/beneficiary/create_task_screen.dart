import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:reliefnet_app/core/theme/app_theme.dart';
import 'package:reliefnet_app/features/auth/presentation/auth_provider.dart';
import 'package:reliefnet_app/providers/beneficiary_task_provider.dart';

class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _imagePicker = ImagePicker();

  final List<File> _selectedImages = [];
  String _urgency = 'MEDIUM';
  double? _latitude;
  double? _longitude;
  String? _locationText;

  static const _maxImages = 5;

  static const _categories = [
    _CategoryOption(value: 'FOOD', label: 'Food', emoji: '🍞'),
    _CategoryOption(value: 'MEDICAL', label: 'Medical', emoji: '💊'),
    _CategoryOption(value: 'SHELTER', label: 'Shelter', emoji: '🏠'),
    _CategoryOption(value: 'OTHER', label: 'Other', emoji: '📦'),
  ];

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= _maxImages) return;
    final source = await _showImageSourceSheet();
    if (source == null) return;

    final xFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 80,
    );
    if (xFile == null) return;

    HapticFeedback.lightImpact();
    setState(() => _selectedImages.add(File(xFile.path)));
  }

  Future<ImageSource?> _showImageSourceSheet() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLocation() async {
    final result = await showModalBottomSheet<_LocationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LocationPickerSheet(),
    );
    if (result != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _locationText = result.displayText;
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick a location before submitting.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    final values = _formKey.currentState!.value;
    final userId = ref.read(authProvider).user?.id;

    final body = <String, dynamic>{
      'source_type': 'BENEFICIARY_REQUEST',
      'title': (values['title'] as String).trim(),
      'description': (values['description'] as String?)?.trim(),
      'category': values['category'] as String?,
      'urgency': _urgency,
      'latitude': _latitude,
      'longitude': _longitude,
      'location_text': _locationText,
      'family_size': int.tryParse(values['family_size'] as String? ?? '1') ?? 1,
      'items_needed': <dynamic>[],
      'budget_pkr': 0,
    };

    await ref
        .read(createTaskProvider.notifier)
        .submit(userId: userId ?? 0, body: body);
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createTaskProvider);

    ref.listen<CreateTaskState>(createTaskProvider, (_, next) {
      if (next.status == CreateTaskStatus.success) {
        HapticFeedback.heavyImpact();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request submitted. An NGO will review it shortly.'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 4),
          ),
        );
        context.pop();
      }
    });

    final isLoading = createState.status == CreateTaskStatus.loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Help'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          if (createState.status == CreateTaskStatus.error &&
              createState.error != null)
            _ErrorBanner(message: createState.error!),
          Expanded(
            child: FormBuilder(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title ──
                    FormBuilderTextField(
                      name: 'title',
                      decoration: const InputDecoration(
                        labelText: 'Title *',
                        hintText: 'Brief summary of what you need',
                        helperText: 'Minimum 5 characters',
                        counterText: '',
                      ),
                      maxLength: 200,
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(
                            errorText: 'Title is required'),
                        FormBuilderValidators.minLength(5,
                            errorText: 'Minimum 5 characters'),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // ── Description ──
                    FormBuilderTextField(
                      name: 'description',
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe what you need in detail...',
                        alignLabelWithHint: true,
                      ),
                      minLines: 3,
                      maxLines: 6,
                    ),
                    const SizedBox(height: 16),

                    // ── Category ──
                    FormBuilderDropdown<String>(
                      name: 'category',
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories
                          .map((c) => DropdownMenuItem(
                                value: c.value,
                                child: Row(children: [
                                  Text(c.emoji,
                                      style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 12),
                                  Text(c.label),
                                ]),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),

                    // ── Urgency ──
                    const _SectionLabel('Urgency'),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'LOW',
                              label: Text('Low'),
                              icon: Icon(Icons.arrow_downward, size: 16),
                            ),
                            ButtonSegment(
                              value: 'MEDIUM',
                              label: Text('Medium'),
                              icon: Icon(Icons.remove, size: 16),
                            ),
                            ButtonSegment(
                              value: 'HIGH',
                              label: Text('High'),
                              icon: Icon(Icons.arrow_upward, size: 16),
                            ),
                            ButtonSegment(
                              value: 'CRITICAL',
                              label: Text('Critical'),
                              icon: Icon(Icons.warning_amber, size: 16),
                            ),
                          ],
                          selected: {_urgency},
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return _urgencyColor(_urgency);
                              }
                              return null;
                            }),
                          ),
                          onSelectionChanged: (value) {
                            HapticFeedback.lightImpact();
                            setState(() => _urgency = value.first);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Location ──
                    const _SectionLabel('Location *'),
                    const SizedBox(height: 8),
                    _LocationTile(
                      locationText: _locationText,
                      isLoading: false,
                      onTap: _pickLocation,
                    ),
                    const SizedBox(height: 16),

                    // ── Images ──
                    const _SectionLabel('Photos (optional, max $_maxImages)'),
                    const SizedBox(height: 8),
                    _ImageGrid(
                      images: _selectedImages,
                      maxImages: _maxImages,
                      onAdd: _pickImage,
                      onRemove: (i) =>
                          setState(() => _selectedImages.removeAt(i)),
                    ),
                    const SizedBox(height: 16),

                    // ── Family Size ──
                    FormBuilderTextField(
                      name: 'family_size',
                      initialValue: '1',
                      decoration: const InputDecoration(
                        labelText: 'Family Size',
                        hintText: 'Number of people',
                        prefixIcon: Icon(Icons.people),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.numeric(),
                        FormBuilderValidators.min(1,
                            errorText: 'Must be at least 1'),
                      ]),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),

          // ── Sticky Submit ──
          _SubmitBar(isLoading: isLoading, onSubmit: _submit),
        ],
      ),
    );
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'LOW':
        return AppTheme.urgencyLow;
      case 'MEDIUM':
        return AppTheme.urgencyMedium;
      case 'HIGH':
        return AppTheme.urgencyHigh;
      case 'CRITICAL':
        return AppTheme.urgencyCritical;
      default:
        return AppTheme.primaryColor;
    }
  }
}

// ── Sub-widgets ──

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: AppTheme.errorColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  final String? locationText;
  final bool isLoading;
  final VoidCallback onTap;

  const _LocationTile({
    required this.locationText,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(12),
          color: cs.surfaceContainerHighest,
        ),
        child: Row(
          children: [
            Icon(
              locationText != null
                  ? Icons.location_on
                  : Icons.add_location_alt,
              color: locationText != null ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isLoading
                  ? const Text('Getting location...')
                  : Text(
                      locationText ?? 'Pick Location',
                      style: TextStyle(
                        color: locationText != null
                            ? cs.onSurface
                            : cs.onSurfaceVariant,
                      ),
                    ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  final List<File> images;
  final int maxImages;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _ImageGrid({
    required this.images,
    required this.maxImages,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showAdd = images.length < maxImages;
    final itemCount = images.length + (showAdd ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == images.length && showAdd) {
          return GestureDetector(
            onTap: onAdd,
            child: Container(
              decoration: BoxDecoration(
                border:
                    Border.all(color: cs.outline, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12),
                color: cs.surfaceContainerHighest,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate,
                      size: 32, color: cs.primary),
                  const SizedBox(height: 4),
                  Text('Add Photo',
                      style: TextStyle(fontSize: 11, color: cs.primary)),
                ],
              ),
            ),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(images[index], fit: BoxFit.cover),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => onRemove(index),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onSubmit;

  const _SubmitBar({required this.isLoading, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: isLoading ? null : onSubmit,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Request',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ── Location Picker Sheet ──

class _LocationResult {
  final double latitude;
  final double longitude;
  final String displayText;

  const _LocationResult({
    required this.latitude,
    required this.longitude,
    required this.displayText,
  });
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet();

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _mapController = MapController();
  LatLng _selected = const LatLng(33.6844, 73.0479);
  bool _hasSelection = false;
  bool _locating = false;

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location permission denied. Enable it in Settings.'),
            ),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final latlng = LatLng(pos.latitude, pos.longitude);
      _mapController.move(latlng, 14);
      setState(() {
        _selected = latlng;
        _hasSelection = true;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get location.')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _confirm() {
    Navigator.pop(
      context,
      _LocationResult(
        latitude: _selected.latitude,
        longitude: _selected.longitude,
        displayText:
            '${_selected.latitude.toStringAsFixed(4)}, ${_selected.longitude.toStringAsFixed(4)}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Pick Location',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                const Spacer(),
                TextButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 18),
                  label: const Text('My Location'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selected,
                initialZoom: 10,
                onTap: (_, point) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selected = point;
                    _hasSelection = true;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.reliefnet.app',
                ),
                if (_hasSelection)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selected,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _hasSelection ? _confirm : null,
                child: const Text('Confirm Location'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryOption {
  final String value;
  final String label;
  final String emoji;

  const _CategoryOption(
      {required this.value, required this.label, required this.emoji});
}
