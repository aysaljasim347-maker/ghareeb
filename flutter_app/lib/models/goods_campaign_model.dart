import 'package:reliefnet_app/utils/safe_parser.dart';

class GoodsCampaign {
  final int id;
  final int? ngoId;
  final String? ngoName;
  final String title;
  final String itemNeeded;
  final String category;
  final int targetQty;
  final String unit;
  final String description;
  final String locationText;
  final double? latitude;
  final double? longitude;
  final String deadline;
  final String? coverImageUrl;
  final String status;
  final int qtyReceived;
  final String createdAt;

  const GoodsCampaign({
    required this.id,
    this.ngoId,
    this.ngoName,
    required this.title,
    required this.itemNeeded,
    required this.category,
    required this.targetQty,
    required this.unit,
    required this.description,
    required this.locationText,
    this.latitude,
    this.longitude,
    required this.deadline,
    this.coverImageUrl,
    this.status = 'ACTIVE',
    this.qtyReceived = 0,
    required this.createdAt,
  });

  double get progressFraction =>
      targetQty > 0 ? (qtyReceived / targetQty).clamp(0.0, 1.0) : 0.0;

  bool get isActive => status == 'ACTIVE';

  bool get isExpired {
    final dl = DateTime.tryParse(deadline);
    return dl != null && dl.isBefore(DateTime.now());
  }

  String get progressLabel => '$qtyReceived / $targetQty $unit';

  factory GoodsCampaign.fromJson(Map<String, dynamic> j) => GoodsCampaign(
        id: SafeParser.paramInt(j['id']),
        ngoId: j['ngo_id'] != null ? SafeParser.paramInt(j['ngo_id']) : null,
        ngoName: j['ngo_name'] != null ? SafeParser.toStringSafe(j['ngo_name']) : null,
        title: SafeParser.toStringSafe(j['title']),
        itemNeeded: SafeParser.toStringSafe(j['item_needed']),
        category: SafeParser.toStringSafe(j['category']),
        targetQty: SafeParser.paramInt(j['target_qty']),
        unit: SafeParser.toStringSafe(j['unit']),
        description: SafeParser.toStringSafe(j['description']),
        locationText: SafeParser.toStringSafe(j['location_text']),
        latitude: j['latitude'] != null ? SafeParser.toDouble(j['latitude']) : null,
        longitude: j['longitude'] != null ? SafeParser.toDouble(j['longitude']) : null,
        deadline: SafeParser.toStringSafe(j['deadline']),
        coverImageUrl: j['cover_image_url'] != null
            ? SafeParser.toStringSafe(j['cover_image_url'])
            : null,
        status: SafeParser.toStringSafe(j['status'], defaultValue: 'ACTIVE'),
        qtyReceived: SafeParser.paramInt(j['qty_received']),
        createdAt: SafeParser.toStringSafe(j['created_at']),
      );
}
