class CampaignModel {
  final int id;
  final int? ngoId;
  final int? createdBy;
  final String title;
  final String? description;
  final double goalPkr;
  final double raisedPkr;
  final String status;
  final double? latitude;
  final double? longitude;
  final String? ngoName;
  final String? createdByName;
  final String? imageUrl;
  final String? createdAt;
  final String? updatedAt;

  const CampaignModel({
    required this.id,
    this.ngoId,
    this.createdBy,
    required this.title,
    this.description,
    required this.goalPkr,
    this.raisedPkr = 0,
    this.status = 'ACTIVE',
    this.latitude,
    this.longitude,
    this.ngoName,
    this.createdByName,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    return CampaignModel(
      id: json['id'] as int,
      ngoId: json['ngo_id'] as int?,
      createdBy: json['created_by'] as int?,
      title: json['title'] as String,
      description: json['description'] as String?,
      goalPkr: (json['goal_pkr'] as num?)?.toDouble() ?? 0,
      raisedPkr: (json['raised_pkr'] as num?)?.toDouble() ?? 0,
      status: (json['status'] as String?) ?? 'ACTIVE',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      ngoName: json['ngo_name'] as String?,
      createdByName: json['created_by_name'] as String?,
      imageUrl: json['image_url'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  double get progressFraction =>
      goalPkr > 0 ? (raisedPkr / goalPkr).clamp(0.0, 1.0) : 0;

  bool get isActive => status == 'ACTIVE';
}
