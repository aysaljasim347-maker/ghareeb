import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:disasteraid_app/core/api/api_client.dart';
import 'package:disasteraid_app/core/api/api_constants.dart';
import 'package:disasteraid_app/models/campaign_model.dart';

class CampaignRepository {
  final ApiClient _client;

  CampaignRepository({required ApiClient client}) : _client = client;

  Future<List<CampaignModel>> getCampaigns({String? status}) async {
    try {
      final params = status != null ? {'status': status} : null;
      final response =
          await _client.get(ApiConstants.campaigns, queryParameters: params);
      final data = response.data;

      // Handle the standardized 'data' wrapper from backend
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map && data.containsKey('data')) {
        list = data['data'] as List? ?? [];
      } else if (data is Map && data.containsKey('campaigns')) {
        // Fallback for old structure
        list = data['campaigns'] as List? ?? [];
      }

      return list
          .map((c) => CampaignModel.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // INTERNAL LOGGING (Placeholder)
      print('[RESILIENCE] Failed to load campaigns: $e');
      // Return empty list instead of throwing to keep UI stable
      return [];
    }
  }

  Future<CampaignModel> getCampaignById(int id) async {
    final response = await _client.get(ApiConstants.campaignById(id));
    return CampaignModel.fromJson(response.data as Map<String, dynamic>);
  }
}

final campaignRepoProvider = Provider<CampaignRepository>((ref) {
  return CampaignRepository(client: ref.read(apiClientProvider));
});

final campaignsProvider = FutureProvider<List<CampaignModel>>((ref) async {
  final repo = ref.read(campaignRepoProvider);
  return repo.getCampaigns(status: 'ACTIVE');
});

final campaignDetailProvider =
    FutureProvider.family<CampaignModel, int>((ref, id) async {
  final repo = ref.read(campaignRepoProvider);
  return repo.getCampaignById(id);
});
