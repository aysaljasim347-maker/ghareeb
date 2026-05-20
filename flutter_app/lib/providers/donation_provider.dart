import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/core/api/api_client.dart';
import 'package:reliefnet_app/core/api/api_constants.dart';
import 'package:reliefnet_app/models/donation_model.dart';

class DonationRepository {
  final ApiClient _client;

  DonationRepository({required ApiClient client}) : _client = client;

  Future<List<DonationModel>> getMyDonations() async {
    final response = await _client.get(ApiConstants.myDonations);
    final data = response.data;
    if (data is List) {
      return data
          .map((d) => DonationModel.fromJson(d as Map<String, dynamic>))
          .toList();
    }
    final list = (data as Map<String, dynamic>)['data'] as List? ?? [];
    return list
        .map((d) => DonationModel.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  Future<List<DonationModel>> getCampaignDonations(int campaignId) async {
    final response =
        await _client.get(ApiConstants.campaignDonations(campaignId));
    final data = response.data;
    List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map) {
      list = (data['data'] ?? data['donations'] ?? []) as List<dynamic>;
    } else {
      list = [];
    }
    return list
        .map((d) => DonationModel.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  Future<DonationModel> createDonation({
    required int campaignId,
    required double amountPkr,
    required String referenceNumber,
    String? receiptUrl,
  }) async {
    final response = await _client.post(
      ApiConstants.donations,
      data: {
        'campaign_id': campaignId,
        'amount_pkr': amountPkr,
        'reference_number': referenceNumber,
        if (receiptUrl != null && receiptUrl.isNotEmpty) 'receipt_url': receiptUrl,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return DonationModel.fromJson(
        data['donation'] as Map<String, dynamic>? ?? data);
  }
}

final donationRepoProvider = Provider<DonationRepository>((ref) {
  return DonationRepository(client: ref.read(apiClientProvider));
});

final myDonationsProvider = FutureProvider<List<DonationModel>>((ref) async {
  final repo = ref.read(donationRepoProvider);
  return repo.getMyDonations();
});

// ── Donate Notifier ──

enum DonateStatus { idle, loading, success, error }

class DonateState {
  final DonateStatus status;
  final String? error;
  final DonationModel? result;

  const DonateState({
    this.status = DonateStatus.idle,
    this.error,
    this.result,
  });

  DonateState copyWith({DonateStatus? status, String? error, DonationModel? result}) {
    return DonateState(
      status: status ?? this.status,
      error: error,
      result: result ?? this.result,
    );
  }
}

class DonateNotifier extends StateNotifier<DonateState> {
  final DonationRepository _repo;
  final Ref _ref;

  DonateNotifier({required DonationRepository repo, required Ref ref})
      : _repo = repo,
        _ref = ref,
        super(const DonateState());

  Future<void> donate({
    required int campaignId,
    required double amountPkr,
    required String referenceNumber,
    String? receiptUrl,
  }) async {
    state = state.copyWith(status: DonateStatus.loading, error: null);
    try {
      final donation = await _repo.createDonation(
        campaignId: campaignId,
        amountPkr: amountPkr,
        referenceNumber: referenceNumber,
        receiptUrl: receiptUrl,
      );
      _ref.invalidate(myDonationsProvider);
      state = DonateState(status: DonateStatus.success, result: donation);
    } catch (e) {
      state = DonateState(
        status: DonateStatus.error,
        error: _extractError(e),
      );
      rethrow;
    }
  }

  void reset() => state = const DonateState();

  String _extractError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('Reference number already used')) {
      return 'This reference number is already linked to another donation.';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'No internet connection. Please try again.';
    }
    return 'Donation could not be submitted. Please try again.';
  }
}

final donateProvider = StateNotifierProvider<DonateNotifier, DonateState>((ref) {
  final repo = ref.read(donationRepoProvider);
  return DonateNotifier(repo: repo, ref: ref);
});
