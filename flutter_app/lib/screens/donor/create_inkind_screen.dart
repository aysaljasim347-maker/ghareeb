import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:reliefnet_app/providers/inkind_provider.dart';

class CreateInKindScreen extends ConsumerStatefulWidget {
  const CreateInKindScreen({super.key});

  @override
  ConsumerState<CreateInKindScreen> createState() => _CreateInKindScreenState();
}

class _CreateInKindScreenState extends ConsumerState<CreateInKindScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _titleCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();

  double? _lat;
  double? _lng;
  String? _photoUrl;
  bool _uploadingPhoto = false;
  bool _locatingGps    = false;

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
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (file == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await file.readAsBytes();
      final notifier = ref.read(inKindNotifierProvider.notifier);
      final url = await notifier.uploadPhoto(bytes, file.name);
      setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo upload failed: $e'), backgroundColor: Colors.red),
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
        throw Exception('Location services are disabled. Please enable GPS.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Enable them in settings.');
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // Reverse-geocode with Nominatim
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
          'addressdetails': 1,
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
            // Clear lat/lng until user picks a suggestion
            _lat = null;
            _lng = null;
          });
        }
      } catch (_) {
        // Silently ignore autocomplete errors
      }
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a pickup location — use GPS or pick from suggestions.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final notifier = ref.read(inKindNotifierProvider.notifier);
    try {
      await notifier.createDonation(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        photoUrl: _photoUrl,
        addressText: _addressCtrl.text.trim(),
        latitude: _lat!,
        longitude: _lng!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Donation posted!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(inKindNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Donate an Item')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Section 1: Item Details ──
                    _SectionCard(
                      title: 'Item Details',
                      icon: Icons.inventory_2_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Photo picker
                          GestureDetector(
                            onTap: _uploadingPhoto ? null : _pickPhoto,
                            child: Container(
                              width: double.infinity,
                              height: 160,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: theme.colorScheme.outline
                                        .withValues(alpha: 0.31)),
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
                                                size: 40,
                                                color:
                                                    theme.colorScheme.primary),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Add Photo (Optional)',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    theme.colorScheme.primary,
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

                          TextFormField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'What are you donating? *',
                              hintText: 'e.g. Winter blankets (3 pieces)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().length < 3)
                                ? 'Title must be at least 3 characters'
                                : null,
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _descCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Description (optional)',
                              hintText: 'Add details (condition, quantity…)',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),

                    // ── Section 2: Pickup Location ──
                    _SectionCard(
                      title: 'Pickup Location',
                      icon: Icons.location_on_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _locatingGps ? null : _useGpsLocation,
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
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          ),
                          TextFormField(
                            controller: _addressCtrl,
                            decoration: InputDecoration(
                              labelText: 'Pickup address',
                              hintText: 'Start typing to search…',
                              border: const OutlineInputBorder(),
                              suffixIcon: _lat != null
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : null,
                            ),
                            onChanged: _onAddressChanged,
                          ),
                          if (_showSuggestions && _suggestions.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black12, blurRadius: 6)
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
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                          onTap: () => _selectSuggestion(s),
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

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          _StickySubmitButton(
            isLoading: isLoading,
            onPressed: _submit,
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          child: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Post Donation', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
