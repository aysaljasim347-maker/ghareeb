import 'package:reliefnet_app/utils/safe_parser.dart';

class DonationModel {
  final int id;
  final int? campaignId;
  final int? donorId;
  final double amountPkr;
  final String status;
  final String paymentMethod;
  final String? referenceNumber;
  final String? receiptUrl;
  final String? campaignTitle;
  final String? donorName;
  final String? createdAt;
  final String? updatedAt;

  const DonationModel({
    required this.id,
    this.campaignId,
    this.donorId,
    required this.amountPkr,
    this.status = 'PENDING',
    this.paymentMethod = 'BANK_TRANSFER',
    this.referenceNumber,
    this.receiptUrl,
    this.campaignTitle,
    this.donorName,
    this.createdAt,
    this.updatedAt,
  });

  factory DonationModel.fromJson(Map<String, dynamic> json) {
    return DonationModel(
      id: SafeParser.paramInt(json['id']),
      campaignId: json['campaign_id'] != null ? SafeParser.paramInt(json['campaign_id']) : null,
      donorId: json['donor_id'] != null ? SafeParser.paramInt(json['donor_id']) : null,
      amountPkr: SafeParser.toDouble(json['amount_pkr']),
      status: SafeParser.toStringSafe(json['status'], defaultValue: 'PENDING'),
      paymentMethod: SafeParser.toStringSafe(json['payment_method'], defaultValue: 'BANK_TRANSFER'),
      referenceNumber: json['gateway_ref'] != null ? SafeParser.toStringSafe(json['gateway_ref']) : null,
      receiptUrl: json['receipt_url'] != null ? SafeParser.toStringSafe(json['receipt_url']) : null,
      campaignTitle: json['campaign_title'] != null ? SafeParser.toStringSafe(json['campaign_title']) : null,
      donorName: json['donor_name'] != null ? SafeParser.toStringSafe(json['donor_name']) : null,
      createdAt: json['created_at'] != null ? SafeParser.toStringSafe(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? SafeParser.toStringSafe(json['updated_at']) : null,
    );
  }

  bool get isConfirmed => status == 'CONFIRMED';
}

class DonationSummary {
  final double totalPkr;
  final int count;
  final int familiesHelped;
  final int campaignsCount;

  const DonationSummary({
    required this.totalPkr,
    required this.count,
    required this.familiesHelped,
    this.campaignsCount = 0,
  });

  factory DonationSummary.fromDonations(List<DonationModel> donations) {
    final confirmed = donations.where((d) => d.isConfirmed).toList();
    final uniqueCampaigns =
        confirmed.map((d) => d.campaignId).whereType<int>().toSet().length;
    return DonationSummary(
      totalPkr: confirmed.fold(0, (sum, d) => sum + d.amountPkr),
      count: confirmed.length,
      familiesHelped: confirmed.length,
      campaignsCount: uniqueCampaigns,
    );
  }
}
