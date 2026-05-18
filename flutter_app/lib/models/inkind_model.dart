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
        id: j['id'] as int,
        donorId: j['donor_id'] as int,
        donorName: j['donor_name'] as String? ?? '',
        title: j['title'] as String,
        description: j['description'] as String?,
        photoUrl: j['photo_url'] as String?,
        addressText: j['address_text'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        status: j['status'] as String,
        requestCount: j['request_count'] != null
            ? int.tryParse(j['request_count'].toString())
            : null,
        pendingCount: j['pending_count'] != null
            ? int.tryParse(j['pending_count'].toString())
            : null,
        createdAt: j['created_at'] as String,
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
        id: j['id'] as int,
        donationId: j['donation_id'] as int,
        beneficiaryId: j['beneficiary_id'] as int,
        beneficiaryName: j['beneficiary_name'] as String? ?? '',
        message: j['message'] as String?,
        phone: j['phone'] as String,
        email: j['email'] as String?,
        status: j['status'] as String,
        donorSharedPhone: j['donor_shared_phone'] as String?,
        acceptedAt: j['accepted_at'] as String?,
        createdAt: j['created_at'] as String,
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
        donationId: j['donation_id'] as int,
        title: j['title'] as String,
        photoUrl: j['photo_url'] as String?,
        addressText: j['address_text'] as String,
        acceptedAt: j['accepted_at'] as String,
        donorName: j['donor_name'] as String,
        donorSharedPhone: j['donor_shared_phone'] as String?,
        beneficiaryName: j['beneficiary_name'] as String,
        beneficiaryPhone: j['beneficiary_phone'] as String,
        beneficiaryEmail: j['beneficiary_email'] as String?,
      );
}
