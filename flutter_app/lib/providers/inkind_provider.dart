import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reliefnet_app/core/api/api_client.dart';
import 'package:reliefnet_app/core/api/api_constants.dart';
import 'package:reliefnet_app/models/inkind_model.dart';
import 'package:reliefnet_app/providers/chat_provider.dart';

// ── Board (beneficiary) ──────────────────────────────────────────────────────

final inKindBoardProvider = FutureProvider.autoDispose<List<InKindDonation>>((ref) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get(ApiConstants.inKindBoard);
  return (res.data as List).map((e) => InKindDonation.fromJson(e)).toList();
});

// ── My Donations (donor) ─────────────────────────────────────────────────────

final myInKindDonationsProvider =
    FutureProvider.autoDispose<List<InKindDonation>>((ref) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get(ApiConstants.inKindMine);
  return (res.data as List).map((e) => InKindDonation.fromJson(e)).toList();
});

// ── Single donation ──────────────────────────────────────────────────────────

final inKindDonationProvider =
    FutureProvider.autoDispose.family<InKindDonation, int>((ref, id) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get(ApiConstants.inKindById(id));
  return InKindDonation.fromJson(res.data as Map<String, dynamic>);
});

// ── Requests on a donation (donor) ───────────────────────────────────────────

final inKindRequestsProvider =
    FutureProvider.autoDispose.family<List<InKindRequest>, int>((ref, donationId) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get(ApiConstants.inKindRequests(donationId));
  return (res.data as List).map((e) => InKindRequest.fromJson(e)).toList();
});

// ── My Requests (beneficiary) ────────────────────────────────────────────────

final myInKindRequestsProvider =
    FutureProvider.autoDispose<List<MyInKindRequest>>((ref) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get(ApiConstants.inKindMyRequests);
  return (res.data as List).map((e) => MyInKindRequest.fromJson(e)).toList();
});

// ── Admin records ────────────────────────────────────────────────────────────

final inKindAdminRecordsProvider =
    FutureProvider.autoDispose<List<InKindRecord>>((ref) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get(ApiConstants.inKindAdminRecords);
  return (res.data as List).map((e) => InKindRecord.fromJson(e)).toList();
});

// ── Mutations ────────────────────────────────────────────────────────────────

class InKindNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  ApiClient get _client => ref.read(apiClientProvider);

  Future<String> uploadPhoto(List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _client.dio.post('/media/upload', data: formData);
    return res.data['url'] as String;
  }

  Future<void> createDonation({
    required String title,
    String? description,
    String? photoUrl,
    required String addressText,
    required double latitude,
    required double longitude,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _client.post(ApiConstants.inKind, data: {
        'title': title,
        if (description != null) 'description': description,
        if (photoUrl != null) 'photo_url': photoUrl,
        'address_text': addressText,
        'latitude': latitude,
        'longitude': longitude,
      });
      state = const AsyncValue.data(null);
      ref.invalidate(myInKindDonationsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> submitRequest(
    int donationId, {
    String? message,
    required String phone,
    String? email,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _client.post(ApiConstants.inKindRequest(donationId), data: {
        if (message != null && message.isNotEmpty) 'message': message,
        'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      state = const AsyncValue.data(null);
      ref.invalidate(inKindBoardProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> acceptRequest(int requestId, {String? donorSharedPhone}) async {
    state = const AsyncValue.loading();
    try {
      await _client.post(ApiConstants.inKindAccept(requestId), data: {
        if (donorSharedPhone != null && donorSharedPhone.isNotEmpty)
          'donor_shared_phone': donorSharedPhone,
      });
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> rejectRequest(int requestId) async {
    state = const AsyncValue.loading();
    try {
      await _client.post(ApiConstants.inKindReject(requestId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Opens or creates a chat room for an inkind request.
  Future<ChatRoom> openInKindChat(int requestId) async {
    final res = await _client.get(ApiConstants.inKindChatRoom(requestId));
    final data = res.data as Map<String, dynamic>;
    return ChatRoom.fromJson(data['room'] as Map<String, dynamic>? ?? data);
  }
}

final inKindNotifierProvider =
    NotifierProvider<InKindNotifier, AsyncValue<void>>(InKindNotifier.new);
