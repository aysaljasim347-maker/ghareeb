import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:disasteraid_app/models/campaign_model.dart';
import 'package:disasteraid_app/providers/campaign_provider.dart';
import 'package:disasteraid_app/providers/donation_provider.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/shimmer_card.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final int campaignId;

  const PaymentScreen({super.key, required this.campaignId});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  static const _presetAmounts = [500.0, 1000.0, 2000.0, 5000.0];
  double? _selectedPreset;
  final _customController = TextEditingController();
  final _referenceController = TextEditingController();
  final _receiptController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _useCustom = false;
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _customController.dispose();
    _referenceController.dispose();
    _receiptController.dispose();
    super.dispose();
  }

  double? get _amount {
    if (_useCustom) return double.tryParse(_customController.text);
    return _selectedPreset;
  }

  bool get _canSubmit =>
      _amount != null &&
      _amount! >= 100 &&
      _referenceController.text.trim().isNotEmpty &&
      !_submitting;

  Future<void> _submitDonation(CampaignModel campaign) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = _amount;
    if (amount == null) return;
    HapticFeedback.lightImpact();

    setState(() => _submitting = true);
    try {
      await ref.read(donateProvider.notifier).donate(
            campaignId: campaign.id,
            amountPkr: amount,
            referenceNumber: _referenceController.text.trim(),
            receiptUrl: _receiptController.text.trim().isEmpty
                ? null
                : _receiptController.text.trim(),
          );
      HapticFeedback.heavyImpact();
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (e) {
      setState(() => _submitting = false);
      if (!mounted) return;
      final donateState = ref.read(donateProvider);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Submission Failed'),
          content: Text(donateState.error ?? 'Something went wrong. Please try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaignAsync = ref.watch(campaignDetailProvider(widget.campaignId));

    if (_submitted) {
      return Scaffold(
        body: SafeArea(
          child: _SuccessView(
            onViewHistory: () => context.go('/donor/donations'),
            onGoHome: () => context.go('/donor/campaigns'),
          ),
        ),
      );
    }

    return campaignAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Donate')),
        body: const ShimmerList(count: 3, itemHeight: 80),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Donate')),
        body: ErrorView(
          message: 'Could not load campaign details.',
          onRetry: () => ref.invalidate(campaignDetailProvider(widget.campaignId)),
        ),
      ),
      data: (campaign) => Scaffold(
        appBar: AppBar(
          title: Text('Donate to ${campaign.title}', overflow: TextOverflow.ellipsis),
        ),
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
                      // ── Campaign Info ──
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                campaign.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (campaign.ngoName != null) ...[
                                const SizedBox(height: 4),
                                Text('By ${campaign.ngoName}',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 13)),
                              ],
                              const SizedBox(height: 12),
                              LinearProgressIndicator(value: campaign.progressFraction),
                              const SizedBox(height: 4),
                              Text(
                                '₹${campaign.raisedPkr.toStringAsFixed(0)} raised of ₹${campaign.goalPkr.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Amount Selection ──
                      Text('Select Amount',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _presetAmounts.map((amt) {
                          final selected = !_useCustom && _selectedPreset == amt;
                          return ChoiceChip(
                            label: Text('₹${amt.toInt()}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: selected ? Colors.white : null)),
                            selected: selected,
                            onSelected: (_) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _selectedPreset = amt;
                                _useCustom = false;
                              });
                            },
                            selectedColor: Theme.of(context).colorScheme.primary,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _customController,
                        decoration: const InputDecoration(
                          labelText: 'Custom Amount (PKR)',
                          prefixText: '₹ ',
                          hintText: 'Enter amount',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        onChanged: (v) => setState(() {
                          _useCustom = v.isNotEmpty;
                          if (v.isNotEmpty) _selectedPreset = null;
                        }),
                        validator: (v) {
                          if (!_useCustom) return null;
                          final parsed = double.tryParse(v ?? '');
                          if (parsed == null || parsed < 100) {
                            return 'Minimum donation is ₹100';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // ── Bank Transfer Details ──
                      Text('Bank Transfer Details',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BankRow(label: 'Bank', value: 'HBL Pakistan'),
                            _BankRow(label: 'Account Title', value: 'DisasterAid Relief Fund'),
                            _BankRow(label: 'Account No.', value: '0123456789'),
                            _BankRow(label: 'IBAN', value: 'PK36HABB0000000123456702'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _referenceController,
                        decoration: const InputDecoration(
                          labelText: 'Transaction Reference Number *',
                          hintText: 'e.g. TXN123456789',
                          helperText: 'Enter the reference/transaction ID from your bank receipt',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your transaction reference number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _receiptController,
                        decoration: const InputDecoration(
                          labelText: 'Receipt URL (optional)',
                          hintText: 'https://...',
                          helperText: 'Link to an uploaded image of your bank receipt',
                        ),
                        keyboardType: TextInputType.url,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final uri = Uri.tryParse(v.trim());
                          if (uri == null || !uri.hasAbsolutePath || !v.startsWith('http')) {
                            return 'Please enter a valid URL';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

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
                          children: [
                            const Icon(Icons.info_outline, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your donation will appear as PENDING until an admin verifies your bank transfer. You will see it confirmed in My Donations.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Submit Button ──
              Container(
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_amount != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Amount: ₹${_amount!.toStringAsFixed(0)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _canSubmit ? () => _submitDonation(campaign) : null,
                        icon: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          _submitting ? 'Submitting...' : 'Submit Donation Request',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
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
    );
  }
}

class _BankRow extends StatelessWidget {
  final String label;
  final String value;

  const _BankRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VoidCallback onViewHistory;
  final VoidCallback onGoHome;

  const _SuccessView({required this.onViewHistory, required this.onGoHome});

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
                color: const Color(0xFF38A169).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  size: 56, color: Color(0xFF38A169)),
            ),
            const SizedBox(height: 24),
            Text('Request Submitted!',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Your donation request is pending admin verification. Once your bank transfer is confirmed, it will appear as CONFIRMED in My Donations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onViewHistory,
                child: const Text('View My Donations'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onGoHome,
                child: const Text('Back to Campaigns'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
