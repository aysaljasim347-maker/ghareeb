import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:disasteraid_app/core/api/api_client.dart';
import 'package:disasteraid_app/core/api/api_constants.dart';
import 'package:disasteraid_app/models/campaign_model.dart';

class CampaignRepository {
  final ApiClient _client;

  CampaignRepository({required ApiClient client}) : _client = client;

  Future<List<CampaignModel>> getCampaigns({String? status}) async {
    final params = status != null ? {'status': status} : null;
    final response =
        await _client.get(ApiConstants.campaigns, queryParameters: params);
    final data = response.data;
    if (data is List) {
      return data
          .map((c) => CampaignModel.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    final list = (data as Map<String, dynamic>)['campaigns'] as List? ?? [];
    return list
        .map((c) => CampaignModel.fromJson(c as Map<String, dynamic>))
        .toList();
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
