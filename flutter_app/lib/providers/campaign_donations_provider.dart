import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/models/donation_model.dart';
import 'package:reliefnet_app/providers/donation_provider.dart';

final campaignDonationsProvider =
    FutureProvider.family<List<DonationModel>, int>((ref, campaignId) async {
  final repo = ref.read(donationRepoProvider);
  return repo.getCampaignDonations(campaignId);
});
