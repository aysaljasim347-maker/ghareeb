import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
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
  bool _useCustom = false;
  bool _processingPayment = false;
  bool _paymentSuccess = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  double? get _amount {
    if (_useCustom) {
      return double.tryParse(_customController.text);
    }
    return _selectedPreset;
  }

  bool get _canPay => _amount != null && _amount! >= 100;

  Future<void> _startPayment(CampaignModel campaign) async {
    final amount = _amount;
    if (amount == null) return;
    HapticFeedback.lightImpact();

    setState(() => _processingPayment = true);
    try {
      const stripeKey = String.fromEnvironment('STRIPE_PK', defaultValue: '');

      String? paymentIntentClientSecret;

      if (stripeKey.isNotEmpty) {
        // Full Stripe flow: initialize and present payment sheet
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: paymentIntentClientSecret ?? '',
            merchantDisplayName: 'DisasterAid',
            style: Theme.of(context).brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
          ),
        );
        await Stripe.instance.presentPaymentSheet();
      }

      // Record donation on backend (with optional gateway_ref)
      await ref.read(donateProvider.notifier).donate(
            campaignId: campaign.id,
            amountPkr: amount,
            gatewayRef: paymentIntentClientSecret,
          );

      HapticFeedback.heavyImpact();
      setState(() {
        _processingPayment = false;
        _paymentSuccess = true;
      });
    } on StripeException catch (e) {
      setState(() => _processingPayment = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Payment Failed'),
            content: Text(e.error.localizedMessage ?? 'Payment was cancelled or failed. Please try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startPayment(campaign);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _processingPayment = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Payment Failed'),
            content: const Text(
                'Something went wrong. Please check your connection and try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startPayment(campaign);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaignAsync = ref.watch(campaignDetailProvider(widget.campaignId));

    if (_paymentSuccess) {
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
          title: Text('Donate to ${campaign.title}',
              overflow: TextOverflow.ellipsis),
        ),
        body: Column(
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
                            LinearProgressIndicator(
                                value: campaign.progressFraction),
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
                          selectedColor:
                              Theme.of(context).colorScheme.primary,
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
                    ),
                    const SizedBox(height: 24),

                    // ── Breakdown ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_outlined,
                              color: Color(0xFF38A169)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '100% of your donation goes directly to beneficiaries. We charge no platform fees.',
                              style:
                                  TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Pay Button ──
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
                        'Total: ₹${_amount!.toStringAsFixed(0)}',
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
                      onPressed:
                          _canPay && !_processingPayment
                              ? () => _startPayment(campaign)
                              : null,
                      icon: _processingPayment
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.lock_outline),
                      label: Text(
                        _processingPayment
                            ? 'Processing payment...'
                            : 'Pay Securely',
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
            Text('Thank you!',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Your donation has been processed. You\'re making a real difference.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onViewHistory,
                child: const Text('View Receipt'),
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
