import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/core/api/api_client.dart';
import 'package:reliefnet_app/core/api/api_constants.dart';
import 'package:reliefnet_app/models/goods_donation_model.dart';

// ── Read providers ─────────────────────────────────────────────────────────────

/// Donor's own goods donations.
final myGoodsDonationsProvider =
    FutureProvider.autoDispose<List<GoodsDonation>>((ref) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get(ApiConstants.myGoodsDonations);
  final list = (res.data as Map<String, dynamic>)['data'] as List;
  return list.map((e) => GoodsDonation.fromJson(e as Map<String, dynamic>)).toList();
});

/// PENDING goods donations available for volunteers to pick up.
final goodsPickupTasksProvider =
    FutureProvider.autoDispose<List<GoodsDonation>>((ref) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get(ApiConstants.goodsDonationsAvailable);
  final list = (res.data as Map<String, dynamic>)['data'] as List;
  return list.map((e) => GoodsDonation.fromJson(e as Map<String, dynamic>)).toList();
});

/// Single goods donation by id (donor / volunteer / coordinator / NGO / admin).
final goodsDonationDetailProvider =
    FutureProvider.autoDispose.family<GoodsDonation, int>((ref, id) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get(ApiConstants.goodsDonationById(id));
  return GoodsDonation.fromJson(res.data as Map<String, dynamic>);
});

/// DELIVERED donations awaiting coordinator review.
final goodsDeliveredReviewProvider =
    FutureProvider.autoDispose<List<GoodsDonation>>((ref) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get(ApiConstants.goodsDonationsForReview);
  final list = (res.data as Map<String, dynamic>)['data'] as List;
  return list.map((e) => GoodsDonation.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Mutation notifier ──────────────────────────────────────────────────────────

enum GoodsDonationMutationStatus { idle, loading, success, error }

class GoodsDonationMutationState {
  final GoodsDonationMutationStatus status;
  final String? error;
  const GoodsDonationMutationState({
    this.status = GoodsDonationMutationStatus.idle,
    this.error,
  });
}

class GoodsDonationNotifier
    extends StateNotifier<GoodsDonationMutationState> {
  GoodsDonationNotifier(this._client)
      : super(const GoodsDonationMutationState());

  final ApiClient _client;

  Future<void> submitDonation({
    required int campaignId,
    required String itemName,
    required String category,
    required String description,
    required double quantity,
    required String unit,
    required String pickupAddress,
    required String contactNumber,
    double? pickupLat,
    double? pickupLng,
    String? photoUrl,
  }) async {
    state = const GoodsDonationMutationState(
        status: GoodsDonationMutationStatus.loading);
    try {
      await _client.post(
        ApiConstants.goodsDonations,
        data: {
          'campaign_id':     campaignId,
          'item_name':       itemName,
          'category':        category,
          'description':     description,
          'quantity':        quantity,
          'unit':            unit,
          'pickup_address':  pickupAddress,
          'contact_number':  contactNumber,
          if (pickupLat != null) 'pickup_lat': pickupLat,
          if (pickupLng != null) 'pickup_lng': pickupLng,
          if (photoUrl != null)  'photo_url':  photoUrl,
        },
      );
      state = const GoodsDonationMutationState(
          status: GoodsDonationMutationStatus.success);
    } catch (e) {
      state = GoodsDonationMutationState(
        status: GoodsDonationMutationStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> claimPickupTask(int donationId) async {
    state = const GoodsDonationMutationState(
        status: GoodsDonationMutationStatus.loading);
    try {
      await _client.patch(ApiConstants.claimGoodsDonation(donationId));
      state = const GoodsDonationMutationState(
          status: GoodsDonationMutationStatus.success);
    } catch (e) {
      state = GoodsDonationMutationState(
        status: GoodsDonationMutationStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> markDelivered({
    required int donationId,
    required double confirmedQty,
    required String note,
    String? proofPhotoUrl,
  }) async {
    state = const GoodsDonationMutationState(
        status: GoodsDonationMutationStatus.loading);
    try {
      await _client.patch(
        ApiConstants.deliverGoodsDonation(donationId),
        data: {
          'proof_photo_url': proofPhotoUrl ?? '',
          'qty_confirmed':   confirmedQty,
          if (note.isNotEmpty) 'volunteer_note': note,
        },
      );
      state = const GoodsDonationMutationState(
          status: GoodsDonationMutationStatus.success);
    } catch (e) {
      state = GoodsDonationMutationState(
        status: GoodsDonationMutationStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> approveDelivery(int donationId) async {
    state = const GoodsDonationMutationState(
        status: GoodsDonationMutationStatus.loading);
    try {
      await _client.patch(ApiConstants.approveGoodsDonation(donationId));
      state = const GoodsDonationMutationState(
          status: GoodsDonationMutationStatus.success);
    } catch (e) {
      state = GoodsDonationMutationState(
        status: GoodsDonationMutationStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> rejectDelivery(int donationId, {required String reason}) async {
    state = const GoodsDonationMutationState(
        status: GoodsDonationMutationStatus.loading);
    try {
      await _client.patch(
        ApiConstants.rejectGoodsDonation(donationId),
        data: {'rejection_reason': reason},
      );
      state = const GoodsDonationMutationState(
          status: GoodsDonationMutationStatus.success);
    } catch (e) {
      state = GoodsDonationMutationState(
        status: GoodsDonationMutationStatus.error,
        error: e.toString(),
      );
    }
  }

  void reset() => state = const GoodsDonationMutationState();
}

final goodsDonationMutationProvider =
    StateNotifierProvider<GoodsDonationNotifier, GoodsDonationMutationState>(
  (ref) => GoodsDonationNotifier(ref.read(apiClientProvider)),
);
