import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:reliefnet_app/models/inkind_model.dart';
import 'package:reliefnet_app/providers/inkind_provider.dart';
import 'package:reliefnet_app/widgets/error_view.dart';

class InKindDetailScreen extends ConsumerWidget {
  final int donationId;
  const InKindDetailScreen({super.key, required this.donationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donationAsync = ref.watch(inKindDonationProvider(donationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Donation Details')),
      body: donationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (donation) => _DetailBody(donation: donation),
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  final InKindDonation donation;
  const _DetailBody({required this.donation});

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _showMap = false;
  bool _showRequestForm = false;

  final _messageCtrl = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  @override
  void dispose() {
    _messageCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(inKindNotifierProvider.notifier);
    try {
      await notifier.submitRequest(
        widget.donation.id,
        message: _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      );
      if (mounted) {
        setState(() => _showRequestForm = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('already requested')
            ? 'You have already requested this item.'
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final donation = widget.donation;
    final theme = Theme.of(context);
    final isLoading =
        ref.watch(inKindNotifierProvider).isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo
          if (donation.photoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: donation.photoUrl!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.31),
              ),
              child: Icon(Icons.volunteer_activism,
                  size: 72, color: theme.colorScheme.primary),
            ),

          const SizedBox(height: 20),

          Text(donation.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),

          if (donation.description != null) ...[
            const SizedBox(height: 10),
            Text(donation.description!, style: theme.textTheme.bodyMedium),
          ],

          const SizedBox(height: 16),

          // Donor info
          _InfoRow(icon: Icons.person_outline, label: 'Posted by', value: donation.donorName),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.location_on_outlined, label: 'Pickup location', value: donation.addressText),

          const SizedBox(height: 16),

          // Map button
          OutlinedButton.icon(
            onPressed: () => setState(() => _showMap = !_showMap),
            icon: Icon(_showMap ? Icons.map : Icons.map_outlined),
            label: Text(_showMap ? 'Hide Map' : 'View Pickup Location'),
          ),

          if (_showMap) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 260,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(donation.latitude, donation.longitude),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.reliefnet.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(donation.latitude, donation.longitude),
                          width: 48,
                          height: 48,
                          child: const Icon(Icons.location_pin, size: 48, color: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          if (donation.isAvailable) ...[
            if (!_showRequestForm) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => setState(() => _showRequestForm = true),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Request This Item'),
                ),
              ),
            ] else ...[
              Text('Request This Item', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _messageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Message (optional)',
                        hintText: 'Why do you need this item?',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone number *',
                        hintText: 'e.g. 03001234567',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().length < 7) {
                          return 'Phone number is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isLoading ? null : () => setState(() => _showRequestForm = false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: isLoading ? null : _submit,
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Submit Request'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('This item has already been claimed', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                ],
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(color: Colors.grey)),
                TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
