import 'package:reliefnet_app/utils/safe_parser.dart';

// Status flow: PENDING → ASSIGNED → DELIVERED → APPROVED | REJECTED
class GoodsDonation {
  final int id;
  final int campaignId;
  final String campaignTitle;
  final int? donorId;
  final String donorName;
  final String itemName;
  final String category;
  final String description;
  final String? photoUrl;
  final double quantity;
  final String unit;
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String contactNumber;
  final String status;
  final int? volunteerId;
  final String? volunteerName;
  final String? proofPhotoUrl;
  final String? deliveredAt;
  final String? approvedAt;
  final String? rejectedAt;
  final String? rejectionReason;
  final String submittedAt;

  const GoodsDonation({
    required this.id,
    required this.campaignId,
    required this.campaignTitle,
    this.donorId,
    required this.donorName,
    required this.itemName,
    required this.category,
    required this.description,
    this.photoUrl,
    required this.quantity,
    required this.unit,
    required this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    required this.contactNumber,
    this.status = 'PENDING',
    this.volunteerId,
    this.volunteerName,
    this.proofPhotoUrl,
    this.deliveredAt,
    this.approvedAt,
    this.rejectedAt,
    this.rejectionReason,
    required this.submittedAt,
  });

  bool get isPending   => status == 'PENDING';
  bool get isAssigned  => status == 'ASSIGNED';
  bool get isDelivered => status == 'DELIVERED';
  bool get isApproved  => status == 'APPROVED';
  bool get isRejected  => status == 'REJECTED';

  // Donor-facing label for "DELIVERED" is "Picked Up"
  String get displayStatus {
    if (status == 'DELIVERED') return 'Picked Up';
    return status[0] + status.substring(1).toLowerCase();
  }

  factory GoodsDonation.fromJson(Map<String, dynamic> j) => GoodsDonation(
        id: SafeParser.paramInt(j['id']),
        campaignId: SafeParser.paramInt(j['campaign_id']),
        campaignTitle: SafeParser.toStringSafe(j['campaign_title']),
        donorId: j['donor_id'] != null ? SafeParser.paramInt(j['donor_id']) : null,
        donorName: SafeParser.toStringSafe(j['donor_name']),
        itemName: SafeParser.toStringSafe(j['item_name']),
        category: SafeParser.toStringSafe(j['category']),
        description: SafeParser.toStringSafe(j['description']),
        photoUrl: j['photo_url'] != null ? SafeParser.toStringSafe(j['photo_url']) : null,
        quantity: SafeParser.toDouble(j['quantity']),
        unit: SafeParser.toStringSafe(j['unit']),
        pickupAddress: SafeParser.toStringSafe(j['pickup_address']),
        pickupLat: j['pickup_lat'] != null ? SafeParser.toDouble(j['pickup_lat']) : null,
        pickupLng: j['pickup_lng'] != null ? SafeParser.toDouble(j['pickup_lng']) : null,
        contactNumber: SafeParser.toStringSafe(j['contact_number']),
        status: SafeParser.toStringSafe(j['status'], defaultValue: 'PENDING'),
        volunteerId: j['volunteer_id'] != null ? SafeParser.paramInt(j['volunteer_id']) : null,
        volunteerName: j['volunteer_name'] != null ? SafeParser.toStringSafe(j['volunteer_name']) : null,
        proofPhotoUrl: j['proof_photo_url'] != null ? SafeParser.toStringSafe(j['proof_photo_url']) : null,
        deliveredAt: j['delivered_at'] != null ? SafeParser.toStringSafe(j['delivered_at']) : null,
        approvedAt: j['approved_at'] != null ? SafeParser.toStringSafe(j['approved_at']) : null,
        rejectedAt: j['rejected_at'] != null ? SafeParser.toStringSafe(j['rejected_at']) : null,
        rejectionReason: j['rejection_reason'] != null ? SafeParser.toStringSafe(j['rejection_reason']) : null,
        submittedAt: SafeParser.toStringSafe(j['submitted_at']),
      );
}
