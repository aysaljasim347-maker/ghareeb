class DonationModel {
  final int id;
  final int? campaignId;
  final int? donorId;
  final double amountPkr;
  final String status;
  final String? gatewayRef;
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
    this.gatewayRef,
    this.campaignTitle,
    this.donorName,
    this.createdAt,
    this.updatedAt,
  });

  factory DonationModel.fromJson(Map<String, dynamic> json) {
    return DonationModel(
      id: json['id'] as int,
      campaignId: json['campaign_id'] as int?,
      donorId: json['donor_id'] as int?,
      amountPkr: (json['amount_pkr'] as num?)?.toDouble() ?? 0,
      status: (json['status'] as String?) ?? 'PENDING',
      gatewayRef: json['gateway_ref'] as String?,
      campaignTitle: json['campaign_title'] as String?,
      donorName: json['donor_name'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  bool get isCompleted => status == 'COMPLETED';
}

class DonationSummary {
  final double totalPkr;
  final int count;
  final int familiesHelped;

  const DonationSummary({
    required this.totalPkr,
    required this.count,
    required this.familiesHelped,
  });

  factory DonationSummary.fromDonations(List<DonationModel> donations) {
    final completed = donations.where((d) => d.isCompleted).toList();
    return DonationSummary(
      totalPkr: completed.fold(0, (sum, d) => sum + d.amountPkr),
      count: completed.length,
      familiesHelped: completed.length,
    );
  }
}
