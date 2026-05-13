import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:disasteraid_app/core/api/api_client.dart';
import 'package:disasteraid_app/core/api/api_constants.dart';

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

  bool get _canSubmit =>
      _photos.isNotEmpty && _position != null && !_uploading;

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
    HapticFeedback.lightImpact();

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);

      final formData = FormData();
      formData.fields.addAll([
        MapEntry('task_id', widget.taskId.toString()),
        MapEntry('latitude', _position!.latitude.toString()),
        MapEntry('longitude', _position!.longitude.toString()),
        if (_notesController.text.trim().isNotEmpty)
          MapEntry('notes', _notesController.text.trim()),
      ]);

      for (var i = 0; i < _photos.length; i++) {
        formData.files.add(MapEntry(
          'photos',
          await MultipartFile.fromFile(
            _photos[i].path,
            filename: 'photo_${i + 1}.jpg',
          ),
        ));
      }

      await client.dio.post(
        ApiConstants.deliveries,
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );

      HapticFeedback.heavyImpact();
      setState(() {
        _uploading = false;
        _success = true;
      });
    } catch (e) {
      setState(() {
        _uploading = false;
        _error = 'Upload failed. Please check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) return _SuccessView(onDone: () => context.pop());

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Delivery')),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFE53E3E).withValues(alpha: 0.1),
              child: Text(_error!,
                  style: const TextStyle(color: Color(0xFFE53E3E))),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Photo Picker ──
                  const _SectionTitle('Delivery Photos *'),
                  const SizedBox(height: 8),
                  if (_photos.isEmpty)
                    GestureDetector(
                      onTap: _addPhoto,
                      child: Container(
                        width: double.infinity,
                        height: 140,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to add photos',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Camera or gallery, max $_maxPhotos photos',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                                border: Border.all(
                                    color: Theme.of(context).colorScheme.outline),
                                borderRadius: BorderRadius.circular(12),
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ),
                              child: Icon(Icons.add_photo_alternate,
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
                                onTap: () =>
                                    setState(() => _photos.removeAt(index)),
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
                    ),
                  const SizedBox(height: 20),

                  // ── GPS Status ──
                  const _SectionTitle('GPS Location'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _position != null
                          ? const Color(0xFF38A169).withValues(alpha: 0.1)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _position != null
                            ? const Color(0xFF38A169)
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      children: [
                        _locating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                _position != null
                                    ? Icons.location_on
                                    : Icons.location_off,
                                color: _position != null
                                    ? const Color(0xFF38A169)
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _position != null
                                ? 'Location captured ✓ (${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)})'
                                : _locating
                                    ? 'Getting your location...'
                                    : 'Location not available',
                            style: TextStyle(
                              color: _position != null
                                  ? const Color(0xFF38A169)
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (_position == null && !_locating)
                          TextButton(
                            onPressed: _captureLocation,
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Notes ──
                  const _SectionTitle('Notes (optional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: 'Any additional details about the delivery...',
                      alignLabelWithHint: true,
                    ),
                    minLines: 3,
                    maxLines: 5,
                  ),

                  if (_uploading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 4),
                    Text(
                      'Uploading ${(_uploadProgress * 100).toInt()}%...',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 32),
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
              height: 52,
              child: FilledButton.icon(
                onPressed: _canSubmit ? _submit : null,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Submit Proof',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

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
