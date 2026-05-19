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
  int _step = 0; // 0 = amount, 1 = payment details
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
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _CampaignHeader(campaign: campaign),
                    const SizedBox(height: 24),
                    _StepIndicator(step: _step),
                    const SizedBox(height: 24),
                    if (_step == 0)
                      _AmountSelector(
                        selectedPreset: _selectedPreset,
                        useCustom: _useCustom,
                        customController: _customController,
                        onPreset: (amt) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedPreset = amt;
                            _useCustom = false;
                          });
                        },
                        onCustomChanged: (v) {
                          setState(() {
                            _useCustom = v.isNotEmpty;
                            _selectedPreset = null;
                          });
                        },
                      ),
                    if (_step == 1)
                      _PaymentDetails(
                        referenceController: _referenceController,
                        receiptController: _receiptController,
                      ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
              _BottomCTA(
                step: _step,
                amount: _amount,
                submitting: _submitting,
                canContinue: _amount != null && _amount! >= 100,
                canSubmit: _canSubmit,
                onNext: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _step = 1);
                },
                onBack: () {
                  setState(() => _step = 0);
                },
                onSubmit: () => _submitDonation(campaign),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignHeader extends StatelessWidget {
  final CampaignModel campaign;

  const _CampaignHeader({required this.campaign});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              campaign.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              campaign.ngoName ?? '',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: campaign.progressFraction,
                minHeight: 6,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Rs ${campaign.raisedPkr.toStringAsFixed(0)} raised of Rs ${campaign.goalPkr.toStringAsFixed(0)}",
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;

  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _dot(0, step, "Amount"),
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: step >= 1 ? Colors.green : Colors.grey.shade300,
            ),
          ),
          _dot(1, step, "Details"),
        ],
      ),
    );
  }

  Widget _dot(int index, int currentStep, String label) {
    final active = currentStep >= index;
    final isDone = currentStep > index;

    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: active ? Colors.green : Colors.grey.shade300,
          child: isDone
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  "${index + 1}",
                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            color: active ? Colors.black87 : Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _AmountSelector extends StatelessWidget {
  final double? selectedPreset;
  final bool useCustom;
  final TextEditingController customController;
  final Function(double) onPreset;
  final Function(String) onCustomChanged;

  const _AmountSelector({
    required this.selectedPreset,
    required this.useCustom,
    required this.customController,
    required this.onPreset,
    required this.onCustomChanged,
  });

  @override
  Widget build(BuildContext context) {
    final presets = [500.0, 1000.0, 2000.0, 5000.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Choose amount",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: presets.map((amt) {
            final selected = !useCustom && selectedPreset == amt;
            return ChoiceChip(
              label: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text("Rs ${amt.toInt()}"),
              ),
              selected: selected,
              onSelected: (_) => onPreset(amt),
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Text(
          "Or enter custom amount",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: customController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onCustomChanged,
          decoration: InputDecoration(
            labelText: "Custom amount",
            prefixText: "Rs ",
            prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey),
            SizedBox(width: 6),
            Text("Minimum donation is Rs 100", style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

class _PaymentDetails extends StatelessWidget {
  final TextEditingController referenceController;
  final TextEditingController receiptController;

  const _PaymentDetails({
    required this.referenceController,
    required this.receiptController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Payment details",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: const ExpansionTile(
            title: Text("View Bank Details", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            leading: Icon(Icons.account_balance, color: Colors.green),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    _BankInfoRow(label: "Bank", value: "HBL Pakistan"),
                    _BankInfoRow(label: "Account", value: "DisasterAid Relief"),
                    _BankInfoRow(label: "Account #", value: "0123456789"),
                    _BankInfoRow(label: "IBAN", value: "PK36HABB0000000123456702"),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: referenceController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: "Transaction reference *",
            hintText: "e.g. TXN123456789",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            helperText: "Enter the reference ID from your bank receipt",
          ),
          validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: receiptController,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: "Receipt URL (optional)",
            hintText: "https://...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            helperText: "Link to your payment proof image",
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Your donation will be verified by our team within 24 hours.",
                  style: TextStyle(fontSize: 11, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BankInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _BankInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _BottomCTA extends StatelessWidget {
  final int step;
  final double? amount;
  final bool submitting;
  final bool canContinue;
  final bool canSubmit;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const _BottomCTA({
    required this.step,
    required this.amount,
    required this.submitting,
    required this.canContinue,
    required this.canSubmit,
    required this.onNext,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          if (step == 1) ...[
            OutlinedButton(
              onPressed: submitting ? null : onBack,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(80, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Back"),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton(
              onPressed: step == 0
                  ? (canContinue ? onNext : null)
                  : (canSubmit ? onSubmit : null),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(step == 0 ? "Continue" : "Submit Donation"),
            ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            Text(
              "Thank You!",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            const Text(
              "Your donation request has been submitted and is pending verification.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onViewHistory,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: const Text("View My Donations"),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onGoHome,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: const Text("Back to Home"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
