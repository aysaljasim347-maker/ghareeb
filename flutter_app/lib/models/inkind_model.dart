import 'package:disasteraid_app/utils/safe_parser.dart';

class InKindDonation {
  final int id;
  final int donorId;
  final String donorName;
  final String title;
  final String? description;
  final String? photoUrl;
  final String addressText;
  final double latitude;
  final double longitude;
  final String status;
  final int? requestCount;
  final int? pendingCount;
  final String createdAt;

  const InKindDonation({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.title,
    this.description,
    this.photoUrl,
    required this.addressText,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.requestCount,
    this.pendingCount,
    required this.createdAt,
  });

  bool get isAvailable => status == 'AVAILABLE';
  bool get isAccepted => status == 'ACCEPTED';

  factory InKindDonation.fromJson(Map<String, dynamic> j) => InKindDonation(
        id: SafeParser.paramInt(j['id']),
        donorId: SafeParser.paramInt(j['donor_id']),
        donorName: SafeParser.toStringSafe(j['donor_name']),
        title: SafeParser.toStringSafe(j['title']),
        description: j['description'] != null ? SafeParser.toStringSafe(j['description']) : null,
        photoUrl: j['photo_url'] != null ? SafeParser.toStringSafe(j['photo_url']) : null,
        addressText: SafeParser.toStringSafe(j['address_text']),
        latitude: SafeParser.toDouble(j['latitude']),
        longitude: SafeParser.toDouble(j['longitude']),
        status: SafeParser.toStringSafe(j['status']),
        requestCount: j['request_count'] != null
            ? SafeParser.paramInt(j['request_count'])
            : null,
        pendingCount: j['pending_count'] != null
            ? SafeParser.paramInt(j['pending_count'])
            : null,
        createdAt: SafeParser.toStringSafe(j['created_at']),
      );
}

class InKindRequest {
  final int id;
  final int donationId;
  final int beneficiaryId;
  final String beneficiaryName;
  final String? message;
  final String phone;
  final String? email;
  final String status;
  final String? donorSharedPhone;
  final String? acceptedAt;
  final String createdAt;

  const InKindRequest({
    required this.id,
    required this.donationId,
    required this.beneficiaryId,
    required this.beneficiaryName,
    this.message,
    required this.phone,
    this.email,
    required this.status,
    this.donorSharedPhone,
    this.acceptedAt,
    required this.createdAt,
  });

  bool get isPending  => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';
  bool get isRejected => status == 'REJECTED';

  factory InKindRequest.fromJson(Map<String, dynamic> j) => InKindRequest(
        id: SafeParser.paramInt(j['id']),
        donationId: SafeParser.paramInt(j['donation_id']),
        beneficiaryId: SafeParser.paramInt(j['beneficiary_id']),
        beneficiaryName: SafeParser.toStringSafe(j['beneficiary_name']),
        message: j['message'] != null ? SafeParser.toStringSafe(j['message']) : null,
        phone: SafeParser.toStringSafe(j['phone']),
        email: j['email'] != null ? SafeParser.toStringSafe(j['email']) : null,
        status: SafeParser.toStringSafe(j['status']),
        donorSharedPhone: j['donor_shared_phone'] != null ? SafeParser.toStringSafe(j['donor_shared_phone']) : null,
        acceptedAt: j['accepted_at'] != null ? SafeParser.toStringSafe(j['accepted_at']) : null,
        createdAt: SafeParser.toStringSafe(j['created_at']),
      );
}

class InKindRecord {
  final int donationId;
  final String title;
  final String? photoUrl;
  final String addressText;
  final String acceptedAt;
  final String donorName;
  final String? donorSharedPhone;
  final String beneficiaryName;
  final String beneficiaryPhone;
  final String? beneficiaryEmail;

  const InKindRecord({
    required this.donationId,
    required this.title,
    this.photoUrl,
    required this.addressText,
    required this.acceptedAt,
    required this.donorName,
    this.donorSharedPhone,
    required this.beneficiaryName,
    required this.beneficiaryPhone,
    this.beneficiaryEmail,
  });

  factory InKindRecord.fromJson(Map<String, dynamic> j) => InKindRecord(
        donationId: SafeParser.paramInt(j['donation_id']),
        title: SafeParser.toStringSafe(j['title']),
        photoUrl: j['photo_url'] != null ? SafeParser.toStringSafe(j['photo_url']) : null,
        addressText: SafeParser.toStringSafe(j['address_text']),
        acceptedAt: SafeParser.toStringSafe(j['accepted_at']),
        donorName: SafeParser.toStringSafe(j['donor_name']),
        donorSharedPhone: j['donor_shared_phone'] != null ? SafeParser.toStringSafe(j['donor_shared_phone']) : null,
        beneficiaryName: SafeParser.toStringSafe(j['beneficiary_name']),
        beneficiaryPhone: SafeParser.toStringSafe(j['beneficiary_phone']),
        beneficiaryEmail: j['beneficiary_email'] != null ? SafeParser.toStringSafe(j['beneficiary_email']) : null,
      );
}
