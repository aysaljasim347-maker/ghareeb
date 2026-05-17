enum TaskStatus {
  open('OPEN'),
  pending('PENDING'),
  assigned('ASSIGNED'),
  claimed('CLAIMED'),
  inProgress('IN_PROGRESS'),
  submitted('SUBMITTED'),
  coordinatorVerified('COORDINATOR_VERIFIED'),
  paid('PAID'),
  flagged('FLAGGED'),
  cancelled('CANCELLED'),
  completed('COMPLETED'),
  failed('FAILED'),
  refunded('REFUNDED'),
  active('ACTIVE'),
  draft('DRAFT'),
  confirmed('CONFIRMED'),
  rejected('REJECTED'),
  approved('APPROVED'),
  unknown('UNKNOWN');

  final String value;
  const TaskStatus(this.value);

  static TaskStatus fromString(String? value) {
    return TaskStatus.values.firstWhere(
      (e) => e.value == value?.toUpperCase(),
      orElse: () => TaskStatus.unknown,
    );
  }
}

enum TaskUrgency {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH'),
  critical('CRITICAL'),
  unknown('UNKNOWN');

  final String value;
  const TaskUrgency(this.value);

  static TaskUrgency fromString(String? value) {
    return TaskUrgency.values.firstWhere(
      (e) => e.value == value?.toUpperCase(),
      orElse: () => TaskUrgency.unknown,
    );
  }
}

class TaskItem {
  final String item;
  final String quantity;

  const TaskItem({required this.item, required this.quantity});

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      item: json['item'] as String? ?? 'Unknown',
      quantity: json['quantity']?.toString() ?? '0',
    );
  }

  Map<String, dynamic> toJson() => {'item': item, 'quantity': quantity};
}

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
  final List<TaskItem> itemsNeeded;
  final double? latitude;
  final double? longitude;
  final String? locationText;
  final int radiusKm;
  final double budgetPkr;
  final TaskUrgency urgency;
  final TaskStatus status;
  final int upvotes;
  final int downvotes;
  final int viewCount;
  final String? createdAt;
  final String? updatedAt;
  final String? claimedAt;
  final String? createdByName;
  final String? claimedByName;
  final String? beneficiaryName;
  final String? campaignTitle;
  final String? ngoName;

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
    this.urgency = TaskUrgency.medium,
    this.status = TaskStatus.open,
    this.upvotes = 0,
    this.downvotes = 0,
    this.viewCount = 0,
    this.createdAt,
    this.updatedAt,
    this.claimedAt,
    this.createdByName,
    this.claimedByName,
    this.beneficiaryName,
    this.campaignTitle,
    this.ngoName,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as int? ?? 0,
      campaignId: json['campaign_id'] as int?,
      beneficiaryId: json['beneficiary_id'] as int?,
      createdBy: json['created_by'] as int?,
      claimedBy: json['claimed_by'] as int?,
      coordinatorId: json['coordinator_id'] as int?,
      sourceType: json['source_type'] as String? ?? 'BENEFICIARY_REQUEST',
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      category: json['category'] as String?,
      familySize: (json['family_size'] as int?) ?? 1,
      itemsNeeded: (json['items_needed'] as List<dynamic>?)
              ?.map((item) => TaskItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationText: json['location_text'] as String?,
      radiusKm: (json['radius_km'] as int?) ?? 5,
      budgetPkr: (json['budget_pkr'] as num?)?.toDouble() ?? 0,
      urgency: TaskUrgency.fromString(json['urgency'] as String?),
      status: TaskStatus.fromString(json['status'] as String?),
      upvotes: (json['upvotes'] as int?) ?? 0,
      downvotes: (json['downvotes'] as int?) ?? 0,
      viewCount: (json['view_count'] as int?) ?? 0,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      claimedAt: json['claimed_at'] as String?,
      createdByName: json['created_by_name'] as String?,
      claimedByName: json['claimed_by_name'] as String?,
      beneficiaryName: json['beneficiary_name'] as String?,
      campaignTitle: json['campaign_title'] as String?,
      ngoName: json['ngo_name'] as String?,
    );
  }

  bool get isCritical => urgency == TaskUrgency.critical;
  bool get isHigh => urgency == TaskUrgency.high;
  bool get isOpen => status == TaskStatus.open;
}
