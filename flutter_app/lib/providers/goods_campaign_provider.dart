import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/core/api/api_client.dart';
import 'package:reliefnet_app/core/api/api_constants.dart';
import 'package:reliefnet_app/models/goods_campaign_model.dart';

/// All active goods campaigns (public — no auth required).
final goodsCampaignsProvider =
    FutureProvider.autoDispose<List<GoodsCampaign>>((ref) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get(ApiConstants.goodsCampaigns);
  final list = (res.data as Map<String, dynamic>)['data'] as List;
  return list.map((e) => GoodsCampaign.fromJson(e as Map<String, dynamic>)).toList();
});

/// Single goods campaign by id (public — no auth required).
final goodsCampaignDetailProvider =
    FutureProvider.autoDispose.family<GoodsCampaign, int>((ref, id) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get(ApiConstants.goodsCampaignById(id));
  return GoodsCampaign.fromJson(res.data as Map<String, dynamic>);
});
