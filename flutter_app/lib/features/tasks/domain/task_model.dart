/// Task model matching the backend schema.
class TaskModel {
  final int id;
  final int? campaignId;
  final int? beneficiaryId;
  final int? createdBy;
  final int? claimedBy;
  final int? coordinatorId;
  final String sourceType;
  final String title;
  final String? description;
  final String? category;
  final int familySize;
  final List<dynamic> itemsNeeded;
  final double? latitude;
  final double? longitude;
  final String? locationText;
  final int radiusKm;
  final double budgetPkr;
  final String urgency;
  final String status;
  final int upvotes;
  final int downvotes;
  final int viewCount;
  final String? createdAt;
  final String? updatedAt;
  final String? claimedAt;
  final String? createdByName;
  final String? claimedByName;

  const TaskModel({
    required this.id,
    this.campaignId,
    this.beneficiaryId,
    this.createdBy,
    this.claimedBy,
    this.coordinatorId,
    required this.sourceType,
    required this.title,
    this.description,
    this.category,
    this.familySize = 1,
    this.itemsNeeded = const [],
    this.latitude,
    this.longitude,
    this.locationText,
    this.radiusKm = 5,
    this.budgetPkr = 0,
    this.urgency = 'MEDIUM',
    this.status = 'OPEN',
    this.upvotes = 0,
    this.downvotes = 0,
    this.viewCount = 0,
    this.createdAt,
    this.updatedAt,
    this.claimedAt,
    this.createdByName,
    this.claimedByName,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as int,
      campaignId: json['campaign_id'] as int?,
      beneficiaryId: json['beneficiary_id'] as int?,
      createdBy: json['created_by'] as int?,
      claimedBy: json['claimed_by'] as int?,
      coordinatorId: json['coordinator_id'] as int?,
      sourceType: json['source_type'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      familySize: (json['family_size'] as int?) ?? 1,
      itemsNeeded: (json['items_needed'] as List<dynamic>?) ?? [],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationText: json['location_text'] as String?,
      radiusKm: (json['radius_km'] as int?) ?? 5,
      budgetPkr: (json['budget_pkr'] as num?)?.toDouble() ?? 0,
      urgency: (json['urgency'] as String?) ?? 'MEDIUM',
      status: (json['status'] as String?) ?? 'OPEN',
      upvotes: (json['upvotes'] as int?) ?? 0,
      downvotes: (json['downvotes'] as int?) ?? 0,
      viewCount: (json['view_count'] as int?) ?? 0,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      claimedAt: json['claimed_at'] as String?,
      createdByName: json['created_by_name'] as String?,
      claimedByName: json['claimed_by_name'] as String?,
    );
  }

  bool get isCritical => urgency == 'CRITICAL';
  bool get isHigh => urgency == 'HIGH';
  bool get isOpen => status == 'OPEN';
}
