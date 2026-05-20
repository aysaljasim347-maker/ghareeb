import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/core/api/api_client.dart';
import 'package:reliefnet_app/providers/beneficiary_task_provider.dart';

class FeedbackRepository {
  final ApiClient _client;
  FeedbackRepository({required ApiClient client}) : _client = client;

  Future<void> submitFeedback({
    required int deliveryId,
    required String status,
    int? rating,
    String? comment,
  }) async {
    await _client.post(
      '/deliveries/$deliveryId/beneficiary-confirm',
      data: {
        'confirmation_status': status,
        if (rating != null) 'rating': rating,
        if (comment != null) 'comment': comment,
      },
    );
  }
}

final feedbackRepoProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepository(client: ref.read(apiClientProvider));
});

class BeneficiaryFeedbackNotifier extends StateNotifier<AsyncValue<void>> {
  final FeedbackRepository _repo;
  final Ref _ref;

  BeneficiaryFeedbackNotifier(
      {required FeedbackRepository repo, required Ref ref})
      : _repo = repo,
        _ref = ref,
        super(const AsyncValue.data(null));

  Future<void> submit({
    required int deliveryId,
    required int taskId,
    required String status,
    int? rating,
    String? comment,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.submitFeedback(
        deliveryId: deliveryId,
        status: status,
        rating: rating,
        comment: comment,
      );
      // Refresh task details to show feedback
      _ref.invalidate(beneficiaryTaskDetailProvider(taskId));
      _ref.invalidate(taskDeliveryDetailsProvider(taskId));
    });
  }
}

final beneficiaryFeedbackProvider =
    StateNotifierProvider<BeneficiaryFeedbackNotifier, AsyncValue<void>>((ref) {
  final repo = ref.read(feedbackRepoProvider);
  return BeneficiaryFeedbackNotifier(repo: repo, ref: ref);
});
