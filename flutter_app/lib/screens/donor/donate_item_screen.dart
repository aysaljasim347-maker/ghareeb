import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reliefnet_app/core/api/api_client.dart';
import 'package:reliefnet_app/core/api/api_constants.dart';
import 'package:reliefnet_app/models/goods_campaign_model.dart';
import 'package:reliefnet_app/providers/goods_campaign_provider.dart';
import 'package:reliefnet_app/providers/goods_donation_provider.dart';
import 'package:reliefnet_app/widgets/error_view.dart';
import 'package:reliefnet_app/widgets/shimmer_card.dart';

class DonateItemScreen extends ConsumerStatefulWidget {
  final int campaignId;
  const DonateItemScreen({super.key, required this.campaignId});

  @override
  ConsumerState<DonateItemScreen> createState() => _DonateItemScreenState();
}

class _DonateItemScreenState extends ConsumerState<DonateItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactCtrl = TextEditingController(text: '+92 300 1234567');

  double _qty = 1.0;
  double? _lat;
  double? _lng;
  String? _photoUrl;
  bool _uploadingPhoto = false;
  bool _locatingGps = false;
  bool _submitted = false;

  // Autocomplete state
  List<_NominatimResult> _suggestions = [];
  Timer? _debounce;
  bool _showSuggestions = false;

  final _nominatim = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    headers: {
      'User-Agent': 'ReliefNet/2.1 (workwithali786@gmail.com)',
      'Accept-Language': 'en',
    },
  ));

  @override
  void initState() {
    super.initState();
    // Pre-fill if we already have the campaign data cached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final campaignAsync =
          ref.read(goodsCampaignDetailProvider(widget.campaignId));
      campaignAsync.whenData((c) {
        if (mounted) _prefillFromCampaign(c);
      });
    });
  }

  @override
  void dispose() {
    _itemNameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _contactCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _prefillFromCampaign(GoodsCampaign c) {
    if (_itemNameCtrl.text.isEmpty) _itemNameCtrl.text = c.itemNeeded;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 75);
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
      if (mounted) setState(() => _photoUrl = url);
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

  Future<void> _useGpsLocation() async {
    setState(() => _locatingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied.');
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final res = await _nominatim.get('/reverse', queryParameters: {
        'lat': pos.latitude,
        'lon': pos.longitude,
        'format': 'json',
      });

      final address = res.data['display_name'] as String? ?? 'Current Location';

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _addressCtrl.text = address;
        _showSuggestions = false;
        _suggestions = [];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _locatingGps = false);
    }
  }

  void _onAddressChanged(String value) {
    _debounce?.cancel();
    if (value.length < 3) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _lat = null;
        _lng = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final res = await _nominatim.get('/search', queryParameters: {
          'q': value,
          'format': 'json',
          'limit': 5,
        });
        final results = (res.data as List)
            .map((e) => _NominatimResult(
                  displayName: e['display_name'] as String,
                  lat: double.parse(e['lat'] as String),
                  lon: double.parse(e['lon'] as String),
                ))
            .toList();
        if (mounted) {
          setState(() {
            _suggestions = results;
            _showSuggestions = results.isNotEmpty;
            _lat = null;
            _lng = null;
          });
        }
      } catch (_) {}
    });
  }

  void _selectSuggestion(_NominatimResult result) {
    setState(() {
      _addressCtrl.text = result.displayName;
      _lat = result.lat;
      _lng = result.lon;
      _suggestions = [];
      _showSuggestions = false;
    });
  }

  Future<void> _submit(GoodsCampaign campaign) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm pickup location via GPS or search.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    HapticFeedback.lightImpact();

    await ref.read(goodsDonationMutationProvider.notifier).submitDonation(
          campaignId: campaign.id,
          itemName: _itemNameCtrl.text.trim(),
          category: campaign.category,
          description: _descCtrl.text.trim(),
          quantity: _qty,
          unit: campaign.unit,
          pickupAddress: _addressCtrl.text.trim(),
          contactNumber: _contactCtrl.text.trim(),
          pickupLat: _lat,
          pickupLng: _lng,
          photoUrl: _photoUrl,
        );

    final state = ref.read(goodsDonationMutationProvider);
    if (state.status == GoodsDonationMutationStatus.success) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() => _submitted = true);
    } else if (state.error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaignAsync =
        ref.watch(goodsCampaignDetailProvider(widget.campaignId));
    final mutation = ref.watch(goodsDonationMutationProvider);
    final isLoading = mutation.status == GoodsDonationMutationStatus.loading;

    if (_submitted) {
      return Scaffold(
        body: SafeArea(
          child: _SuccessView(
            onViewDonations: () => context.go('/donor/goods-donations'),
            onGoBack: () => context.go('/donor/campaigns'),
          ),
        ),
      );
    }

    return campaignAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Donate Item')),
        body: const ShimmerList(count: 4, itemHeight: 80),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Donate Item')),
        body: ErrorView(
          message: 'Could not load campaign details.',
          onRetry: () =>
              ref.invalidate(goodsCampaignDetailProvider(widget.campaignId)),
        ),
      ),
      data: (campaign) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Text(
              'Donate to ${campaign.title}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Photo Hero Section ──
                          GestureDetector(
                            onTap: _uploadingPhoto ? null : _pickPhoto,
                            child: Container(
                              width: double.infinity,
                              height: 160,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: cs.outline.withValues(alpha: 0.1)),
                                image: _photoUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_photoUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _uploadingPhoto
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : _photoUrl == null
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                                Icons
                                                    .add_photo_alternate_outlined,
                                                size: 48,
                                                color: cs.primary),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Add Item Photo',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: cs.primary,
                                              ),
                                            ),
                                            const Text(
                                              'Helps donors trust your item',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey),
                                            ),
                                          ],
                                        )
                                      : Align(
                                          alignment: Alignment.topRight,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: CircleAvatar(
                                              backgroundColor: Colors.black54,
                                              radius: 16,
                                              child: IconButton(
                                                icon: const Icon(Icons.close,
                                                    size: 16,
                                                    color: Colors.white),
                                                onPressed: () => setState(
                                                    () => _photoUrl = null),
                                                padding: EdgeInsets.zero,
                                              ),
                                            ),
                                          ),
                                        ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Item Details Card ──
                          _SectionCard(
                            title: 'Item Details',
                            icon: Icons.inventory_2_outlined,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _itemNameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'What are you donating? *',
                                    hintText: 'e.g. Winter blankets',
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Please enter the item name'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _descCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Add details *',
                                    hintText:
                                        'Condition, size, special notes…',
                                  ),
                                  maxLines: 3,
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Please describe the item'
                                      : null,
                                ),
                              ],
                            ),
                          ),

                          // ── Quantity & Category Card ──
                          _SectionCard(
                            title: 'Quantity & Category',
                            icon: Icons.numbers_outlined,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _QuantityStepper(
                                      value: _qty,
                                      unit: campaign.unit,
                                      onChanged: (v) => setState(() => _qty = v),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Category',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: cs.onSurfaceVariant),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: cs.surfaceContainerHighest
                                                  .withValues(alpha: 0.3),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              campaign.category,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // ── Pickup Location Card ──
                          _SectionCard(
                            title: 'Pickup Location',
                            icon: Icons.location_on_outlined,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed:
                                        _locatingGps ? null : _useGpsLocation,
                                    icon: _locatingGps
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.my_location),
                                    label: Text(_locatingGps
                                        ? 'Getting location…'
                                        : 'Use Current Location'),
                                  ),
                                ),
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'or enter manually',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                TextFormField(
                                  controller: _addressCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Pickup address *',
                                    hintText: 'Start typing to search…',
                                    suffixIcon: _lat != null
                                        ? const Icon(Icons.check_circle,
                                            color: Colors.green)
                                        : null,
                                  ),
                                  onChanged: _onAddressChanged,
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Please enter address'
                                      : null,
                                ),
                                if (_showSuggestions && _suggestions.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                      color: cs.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 6)
                                      ],
                                    ),
                                    child: Column(
                                      children: _suggestions
                                          .map((s) => ListTile(
                                                dense: true,
                                                leading: const Icon(
                                                    Icons.location_on_outlined,
                                                    size: 18),
                                                title: Text(s.displayName,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 13)),
                                                onTap: () =>
                                                    _selectSuggestion(s),
                                              ))
                                          .toList(),
                                    ),
                                  ),
                                if (_lat != null) ...[
                                  const SizedBox(height: 8),
                                  const Row(
                                    children: [
                                      Icon(Icons.check_circle_outline,
                                          size: 16, color: Colors.green),
                                      SizedBox(width: 4),
                                      Text(
                                        'Location confirmed',
                                        style: TextStyle(
                                            color: Colors.green, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // ── Contact Detail Card ──
                          _SectionCard(
                            title: 'Contact Information',
                            icon: Icons.phone_outlined,
                            child: TextFormField(
                              controller: _contactCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Phone number *',
                                hintText: '+92...',
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Please enter contact number'
                                  : null,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── Trust Note ──
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Pickup will be coordinated by a verified volunteer.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                _StickySubmitButton(
                  isLoading: isLoading,
                  onPressed: () => _submit(campaign),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VoidCallback onViewDonations;
  final VoidCallback onGoBack;

  const _SuccessView(
      {required this.onViewDonations, required this.onGoBack});

  @override
  Widget build(BuildContext context) {
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
                color: Colors.teal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 56, color: Colors.teal),
            ),
            const SizedBox(height: 24),
            Text(
              'Request Submitted!',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'A volunteer will be assigned to collect your item soon. '
              'Track the status in My Goods Donations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onViewDonations,
                style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                child: const Text('View My Goods Donations'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onGoBack,
                child: const Text('Back to Campaigns'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final double value;
  final String unit;
  final ValueChanged<double> onChanged;

  const _QuantityStepper({
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Text(
                  value.toStringAsFixed(value == value.toInt() ? 0 : 1),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                  unit,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.add,
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _StepButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _StickySubmitButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _StickySubmitButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(backgroundColor: Colors.teal),
          icon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.volunteer_activism),
          label: Text(
            isLoading ? 'Submitting…' : 'Submit Donation Request',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _NominatimResult {
  final String displayName;
  final double lat;
  final double lon;

  _NominatimResult({required this.displayName, required this.lat, required this.lon});
}
