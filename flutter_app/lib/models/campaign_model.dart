import 'package:disasteraid_app/utils/safe_parser.dart';

class CampaignModel {
  final int id;
  final int? ngoId;
  final int? createdBy;
  final String title;
  final String? description;
  final double goalPkr;
  final double raisedPkr;
  final double spentPkr;
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
    this.spentPkr = 0,
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
      id: SafeParser.paramInt(json['id']),
      ngoId: json['ngo_id'] != null ? SafeParser.paramInt(json['ngo_id']) : null,
      createdBy: json['created_by'] != null ? SafeParser.paramInt(json['created_by']) : null,
      title: SafeParser.toStringSafe(json['title'], defaultValue: 'Untitled Campaign'),
      description: json['description'] != null ? SafeParser.toStringSafe(json['description']) : null,
      goalPkr: SafeParser.toDouble(json['goal_pkr']),
      raisedPkr: SafeParser.toDouble(json['raised_pkr']),
      spentPkr: SafeParser.toDouble(json['spent_pkr']),
      status: SafeParser.toStringSafe(json['status'], defaultValue: 'ACTIVE'),
      latitude: json['latitude'] != null ? SafeParser.toDouble(json['latitude']) : null,
      longitude: json['longitude'] != null ? SafeParser.toDouble(json['longitude']) : null,
      ngoName: json['ngo_name'] != null ? SafeParser.toStringSafe(json['ngo_name']) : null,
      createdByName: json['created_by_name'] != null ? SafeParser.toStringSafe(json['created_by_name']) : null,
      imageUrl: json['image_url'] != null ? SafeParser.toStringSafe(json['image_url']) : null,
      createdAt: json['created_at'] != null ? SafeParser.toStringSafe(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? SafeParser.toStringSafe(json['updated_at']) : null,
    );
  }

  double get progressFraction =>
      goalPkr > 0 ? (raisedPkr / goalPkr).clamp(0.0, 1.0) : 0;

  bool get isActive => status == 'ACTIVE';

  // Campaigns with ≥70 % of goal reached are surfaced as urgent
  bool get isUrgent => isActive && progressFraction >= 0.7;

  double get utilizationFraction =>
      raisedPkr > 0 ? (spentPkr / raisedPkr).clamp(0.0, 1.0) : 0;
}
