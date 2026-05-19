import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:disasteraid_app/core/api/api_client.dart';
import 'package:disasteraid_app/core/api/api_constants.dart';
import 'package:disasteraid_app/models/goods_donation_model.dart';
import 'package:disasteraid_app/providers/goods_donation_provider.dart';
import 'package:disasteraid_app/widgets/error_view.dart';

class GoodsProofUploadScreen extends ConsumerStatefulWidget {
  final int donationId;
  const GoodsProofUploadScreen({super.key, required this.donationId});

  @override
  ConsumerState<GoodsProofUploadScreen> createState() =>
      _GoodsProofUploadScreenState();
}

class _GoodsProofUploadScreenState
    extends ConsumerState<GoodsProofUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  File? _proofPhoto;
  String? _proofPhotoUrl;
  bool _uploadingPhoto = false;
  bool _submitted = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _prefillQty(GoodsDonation d) {
    if (_qtyCtrl.text.isEmpty) {
      _qtyCtrl.text = d.quantity == d.quantity.toInt()
          ? d.quantity.toInt().toString()
          : d.quantity.toString();
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
        source: ImageSource.camera, imageQuality: 80);
    if (xFile == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final client = ref.read(apiClientProvider);
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          xFile.path,
          filename: File(xFile.path).uri.pathSegments.last,
        ),
      });
      final response = await client.post(
        ApiConstants.mediaUpload,
        data: formData,
      );
      final url = (response.data as Map<String, dynamic>)['url'] as String;
      if (mounted) {
        setState(() {
          _proofPhoto = File(xFile.path);
          _proofPhotoUrl = url;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Photo upload failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _submit(GoodsDonation donation) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_proofPhotoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add a proof photo before submitting.')),
      );
      return;
    }
    HapticFeedback.lightImpact();

    await ref.read(goodsDonationMutationProvider.notifier).markDelivered(
          donationId: donation.id,
          confirmedQty: double.parse(_qtyCtrl.text.trim()),
          note: _noteCtrl.text.trim(),
          proofPhotoUrl: _proofPhotoUrl,
        );

    final state = ref.read(goodsDonationMutationProvider);
    if (state.status == GoodsDonationMutationStatus.success) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() => _submitted = true);
    } else if (state.error != null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Submission Failed'),
          content: Text(state.error!),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final donationAsync =
        ref.watch(goodsDonationDetailProvider(widget.donationId));
    final mutation = ref.watch(goodsDonationMutationProvider);
    final isLoading = mutation.status == GoodsDonationMutationStatus.loading;

    if (_submitted) {
      return Scaffold(
        body: SafeArea(
          child: _SuccessView(
            onGoToTasks: () => context.go('/volunteer/tasks'),
          ),
        ),
      );
    }

    return donationAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Mark as Picked Up')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Mark as Picked Up')),
        body: ErrorView(
          message: 'Could not load task details.',
          onRetry: () => ref
              .invalidate(goodsDonationDetailProvider(widget.donationId)),
        ),
      ),
      data: (donation) {
        _prefillQty(donation);
        return Scaffold(
          appBar: AppBar(title: const Text('Mark as Picked Up')),
          body: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Item summary ──
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.teal.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.inventory_2_outlined,
                                      color: Colors.teal),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        donation.itemName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        donation.donorName,
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
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Proof photo ──
                        Text('Proof Photo',
                            style:
                                Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Take a clear photo of the collected items.',
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                        _PhotoBox(
                          proofPhoto: _proofPhoto,
                          isUploading: _uploadingPhoto,
                          onAdd: _pickAndUploadPhoto,
                          onRemove: () => setState(() {
                            _proofPhoto = null;
                            _proofPhotoUrl = null;
                          }),
                        ),
                        const SizedBox(height: 24),

                        // ── Confirmed qty ──
                        Text('Confirmed Quantity',
                            style:
                                Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: TextFormField(
                                controller: _qtyCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Quantity *',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (v) {
                                  final n = double.tryParse(v ?? '');
                                  if (n == null || n <= 0) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(donation.unit,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Expected: ${_qtyLabel(donation.quantity)} ${donation.unit}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                        const SizedBox(height: 24),

                        // ── Note ──
                        Text('Pickup Note',
                            style:
                                Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _noteCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                            hintText:
                                'Any condition issues, partial pickup, etc.',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),

                        // ── Info ──
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'After you submit, the coordinator will review your pickup and approve it. '
                                  'Make sure your photo clearly shows the items collected.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Submit button ──
                Container(
                  padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      12 + MediaQuery.of(context).padding.bottom),
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
                      onPressed:
                          isLoading ? null : () => _submit(donation),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.green),
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        isLoading ? 'Submitting…' : 'Submit Pickup Report',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _qtyLabel(double qty) =>
      qty == qty.toInt() ? qty.toInt().toString() : qty.toString();
}

class _PhotoBox extends StatelessWidget {
  final File? proofPhoto;
  final bool isUploading;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _PhotoBox({
    required this.proofPhoto,
    required this.isUploading,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (isUploading) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (proofPhoto != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              proofPhoto!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onAdd,
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 40, color: cs.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              'Tap to take a photo',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            Text(
              '(Required)',
              style: TextStyle(
                  color: Colors.red.shade400,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VoidCallback onGoToTasks;
  const _SuccessView({required this.onGoToTasks});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.check_circle, size: 56, color: Colors.green),
            ),
            const SizedBox(height: 24),
            Text(
              'Pickup Reported!',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Your pickup report has been submitted. '
              'The coordinator will review and approve it shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onGoToTasks,
                style:
                    FilledButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Back to Tasks'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
