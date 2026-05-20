import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reliefnet_app/config/env.dart';
import 'package:reliefnet_app/core/api/api_client.dart';
import 'package:reliefnet_app/core/api/api_constants.dart';
import 'package:reliefnet_app/core/theme/app_theme.dart';
import 'package:reliefnet_app/features/tasks/presentation/tasks_provider.dart';

class ProofUploadScreen extends ConsumerStatefulWidget {
  final int taskId;

  const ProofUploadScreen({super.key, required this.taskId});

  @override
  ConsumerState<ProofUploadScreen> createState() => _ProofUploadScreenState();
}

class _ProofUploadScreenState extends ConsumerState<ProofUploadScreen> {
  final _imagePicker = ImagePicker();
  final _notesController = TextEditingController();

  final List<File> _photos = [];
  Position? _position;
  bool _locating = false;
  bool _uploading = false;
  double _uploadProgress = 0;
  bool _success = false;
  String? _error;

  static const _maxPhotos = 8;

  bool get _canSubmit => _photos.isNotEmpty && _position != null && !_uploading;

  @override
  void initState() {
    super.initState();
    _captureLocation();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        setState(() => _position = pos);
      }
    } catch (_) {
      // silent — user can retry
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= _maxPhotos) return;
    final source = await showModalBottomSheet<ImageSource>(
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
    if (source == null) return;
    final xFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1080,
      imageQuality: 80,
    );
    if (xFile == null) return;
    HapticFeedback.lightImpact();
    setState(() => _photos.add(File(xFile.path)));
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    if (Env.cloudinaryCloudName.isEmpty || Env.cloudinaryUploadPreset.isEmpty) {
      setState(() => _error = 'Image upload not configured. Contact support.');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
      _error = null;
    });

    try {
      // Step 1: Upload each photo to Cloudinary (separate Dio — no JWT interceptor)
      final List<String> photoUrls = [];
      final cloudinaryDio = Dio();

      for (var i = 0; i < _photos.length; i++) {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(_photos[i].path),
          'upload_preset': Env.cloudinaryUploadPreset,
        });

        final response = await cloudinaryDio.post(
          'https://api.cloudinary.com/v1_1/${Env.cloudinaryCloudName}/image/upload',
          data: formData,
          onSendProgress: (sent, total) {
            if (total > 0 && mounted) {
              setState(
                  () => _uploadProgress = (i + sent / total) / _photos.length);
            }
          },
        );

        photoUrls.add(response.data['secure_url'] as String);
      }

      // Step 2: Submit delivery JSON to backend
      final client = ref.read(apiClientProvider);
      await client.post(
        ApiConstants.deliveries,
        data: {
          'task_id': widget.taskId,
          'photo_urls': photoUrls,
          'latitude': _position!.latitude,
          'longitude': _position!.longitude,
          if (_notesController.text.trim().isNotEmpty)
            'notes': _notesController.text.trim(),
        },
      );

      HapticFeedback.heavyImpact();
      if (mounted) {
        ref.invalidate(taskDetailProvider(widget.taskId));
        ref.invalidate(availableTasksProvider);
        setState(() {
          _uploading = false;
          _success = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = 'Upload failed. Please check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) return _SuccessView(onDone: () => context.pop());

    return Scaffold(
      appBar: AppBar(title: const Text('Submit Delivery Proof')),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppTheme.errorColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppTheme.errorColor, fontSize: 13)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepHeader('1', 'Capture Evidence'),
                  const SizedBox(height: 12),
                  _buildPhotoSection(context),
                  const SizedBox(height: 24),
                  _buildStepHeader('2', 'Validate Location'),
                  const SizedBox(height: 12),
                  _buildLocationPanel(context),
                  const SizedBox(height: 24),
                  _buildStepHeader('3', 'Delivery Notes'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: 'Describe what was delivered and to whom...',
                      alignLabelWithHint: true,
                    ),
                    minLines: 3,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 24),
                  if (_photos.isNotEmpty && _position != null) ...[
                    _buildStepHeader('4', 'Final Review'),
                    const SizedBox(height: 12),
                    _buildSummaryCard(context),
                  ],
                  if (_uploading) ...[
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _uploadProgress,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Uploading evidence... ${(_uploadProgress * 100).toInt()}%',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // ── Submit Bar ──
          Container(
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
              height: 56,
              child: FilledButton.icon(
                onPressed: _canSubmit ? _submit : null,
                icon: _uploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                    _uploading ? 'Processing...' : 'Confirm & Submit Proof',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(String number, String title) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection(BuildContext context) {
    if (_photos.isEmpty) {
      return GestureDetector(
        onTap: _addPhoto,
        child: Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                'Add Delivery Photos',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Take a photo of the aid items with the beneficiary',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _photos.length + (_photos.length < _maxPhotos ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _photos.length) {
          return GestureDetector(
            onTap: _addPhoto,
            child: Container(
              decoration: BoxDecoration(
                border:
                    Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Icon(Icons.add_photo_alternate_outlined,
                  color: Theme.of(context).colorScheme.primary),
            ),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_photos[index], fit: BoxFit.cover),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => setState(() => _photos.removeAt(index)),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLocationPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _position != null ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              _position != null ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          _locating
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(
                  _position != null ? Icons.location_on : Icons.location_off,
                  color: _position != null ? Colors.green : Colors.grey,
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _position != null
                      ? 'Location Verified'
                      : 'Location Not Found',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _position != null
                        ? Colors.green.shade900
                        : Colors.grey.shade800,
                  ),
                ),
                Text(
                  _position != null
                      ? 'GPS coordinates captured successfully.'
                      : _locating
                          ? 'Requesting GPS lock...'
                          : 'Enable location permissions to continue.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          if (_position == null && !_locating)
            TextButton(onPressed: _captureLocation, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Card(
      elevation: 0,
      color:
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.primaryContainer),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SummaryRow(label: 'Photos', value: '${_photos.length} captured'),
            const SizedBox(height: 8),
            const _SummaryRow(label: 'Location', value: 'GPS Data Ready'),
            const SizedBox(height: 8),
            _SummaryRow(
                label: 'Notes',
                value: _notesController.text.isEmpty
                    ? 'No notes added'
                    : 'Notes included'),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: const Color(0xFF38A169).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle,
                        size: 56, color: Color(0xFF38A169)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Delivery Confirmed!',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your proof has been submitted. The coordinator will review and verify it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onDone,
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
