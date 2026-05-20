import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/core/api/api_client.dart';
import 'package:reliefnet_app/features/tasks/presentation/tasks_provider.dart';
import 'package:reliefnet_app/providers/beneficiary_task_provider.dart';
import 'package:reliefnet_app/screens/coordinator/coordinator_tasks_screen.dart';

enum ReviewStatus { idle, loading, success, error }

class ReviewState {
  final ReviewStatus status;
  final String? error;
  const ReviewState({this.status = ReviewStatus.idle, this.error});
}

class DeliveryReviewNotifier extends StateNotifier<ReviewState> {
  final ApiClient _client;
  final Ref _ref;

  DeliveryReviewNotifier({required ApiClient client, required Ref ref})
      : _client = client,
        _ref = ref,
        super(const ReviewState());

  Future<void> reviewDelivery({
    required int deliveryId,
    required int taskId,
    required String outcome,
    required String notes,
  }) async {
    state = const ReviewState(status: ReviewStatus.loading);
    try {
      await _client.post(
        '/deliveries/$deliveryId/verify',
        data: {
          'verified': outcome == 'VERIFY',
          'outcome': outcome,
          'notes': notes,
        },
      );
      state = const ReviewState(status: ReviewStatus.success);
      
      // Invalidate relevant providers
      _ref.invalidate(coordinatorTasksProvider);
      _ref.invalidate(taskDetailProvider(taskId));
      _ref.invalidate(taskDeliveryDetailsProvider(taskId));
    } catch (e) {
      String message = 'Failed to submit review.';
      if (e is DioException && e.response?.data is Map) {
        message = e.response?.data['error'] ?? message;
      }
      state = ReviewState(status: ReviewStatus.error, error: message);
    }
  }
}

final deliveryReviewProvider =
    StateNotifierProvider<DeliveryReviewNotifier, ReviewState>((ref) {
  final client = ref.read(apiClientProvider);
  return DeliveryReviewNotifier(client: client, ref: ref);
});
