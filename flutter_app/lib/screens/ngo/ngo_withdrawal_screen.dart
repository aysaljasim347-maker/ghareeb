import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:disasteraid_app/core/api/api_client.dart';
import 'package:disasteraid_app/core/api/api_constants.dart';

// ── Withdrawal model ──

class WithdrawalModel {
  final int id;
  final double amount;
  final String bankAccount;
  final String status;
  final String? createdAt;

  const WithdrawalModel({
    required this.id,
    required this.amount,
    required this.bankAccount,
    required this.status,
    this.createdAt,
  });

  factory WithdrawalModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalModel(
      id: json['id'] as int,
      amount: (json['amount'] as num).toDouble(),
      bankAccount: json['bank_account'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] as String?,
    );
  }
}

// ── Providers ──

final myWithdrawalsProvider = FutureProvider<List<WithdrawalModel>>((ref) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get(ApiConstants.myWithdrawals);
  final data = response.data as Map<String, dynamic>;
  final list = (data['data'] as List<dynamic>?) ?? [];
  return list
      .map((w) => WithdrawalModel.fromJson(w as Map<String, dynamic>))
      .toList();
});

// ── Screen ──

class NgoWithdrawalScreen extends ConsumerStatefulWidget {
  const NgoWithdrawalScreen({super.key});

  @override
  ConsumerState<NgoWithdrawalScreen> createState() => _NgoWithdrawalScreenState();
}

class _NgoWithdrawalScreenState extends ConsumerState<NgoWithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _bankController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _bankController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.lightImpact();
    setState(() => _submitting = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.post(
        ApiConstants.withdrawals,
        data: {
          'amount': double.parse(_amountController.text.trim()),
          'bank_account': _bankController.text.trim(),
        },
      );
      HapticFeedback.heavyImpact();
      ref.invalidate(myWithdrawalsProvider);
      _amountController.clear();
      _bankController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Withdrawal request submitted. Awaiting admin approval.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('Insufficient')
            ? 'Insufficient wallet balance for this withdrawal.'
            : 'Could not submit withdrawal request. Please try again.';
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Request Failed'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final withdrawalsAsync = ref.watch(myWithdrawalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdrawal Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myWithdrawalsProvider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Request Form ──
            Text('New Withdrawal Request',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (PKR) *',
                      prefixText: '₹ ',
                      hintText: 'e.g. 5000',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    validator: (v) {
                      final parsed = double.tryParse(v?.trim() ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bankController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Account Details *',
                      hintText: 'Account title, number, bank name',
                    ),
                    maxLines: 2,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter your bank account details';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_outlined),
                      label: Text(_submitting ? 'Submitting...' : 'Request Withdrawal'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── History ──
            Text('My Requests',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            withdrawalsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) => const Text('Could not load withdrawal history.'),
              data: (items) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No withdrawal requests yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final w = items[index];
                    return _WithdrawalTile(withdrawal: w);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WithdrawalTile extends StatelessWidget {
  final WithdrawalModel withdrawal;

  const _WithdrawalTile({required this.withdrawal});

  Color _statusColor() {
    switch (withdrawal.status) {
      case 'APPROVED':
        return const Color(0xFF38A169);
      case 'REJECTED':
        return const Color(0xFFE53E3E);
      default:
        return const Color(0xFFED8936);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${withdrawal.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    withdrawal.bankAccount,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Text(
                withdrawal.status,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
