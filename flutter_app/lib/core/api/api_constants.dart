/// API configuration constants.
class ApiConstants {
  ApiConstants._();

  /// Base URL for the backend API.
  /// Change this for production deployment.
  // static const String baseUrl = 'http://10.0.2.2:3000/api';

  /// Web base URL (same backend, accessed from browser).
  static const String baseUrl = 'http://localhost:3000/api';

  // ── Auth ──
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String me = '/auth/me';

  // ── Tasks ──
  static const String tasks = '/tasks';
  static const String availableTasks = '/tasks/available';
  static String taskById(int id) => '/tasks/$id';
  static String claimTask(int id) => '/tasks/$id/claim';
  static String taskEvents(int id) => '/tasks/$id/events';

  // ── Campaigns ──
  static const String campaigns = '/campaigns';
  static String campaignById(int id) => '/campaigns/$id';

  // ── Donations ──
  static const String donations = '/donations';
  static const String myDonations = '/donations/mine';
  static String confirmDonation(int id) => '/donations/$id/confirm';
  static String campaignDonations(int id) => '/donations/campaign/$id';

  // ── Deliveries ──
  static const String deliveries = '/deliveries';
  static String verifyDelivery(int id) => '/deliveries/$id/verify';
  static String taskDeliveries(int taskId) => '/deliveries/task/$taskId';

  // ── Chat ──
  static const String chatRooms = '/chat/rooms';
  static String roomMessages(int roomId) => '/chat/rooms/$roomId/messages';
  static String roomByTaskId(int taskId) => '/chat/rooms/task/$taskId';

  // ── My Tasks ──
  static const String myTasks = '/tasks/my';
  static const String coordinatorTasks = '/tasks/coordinator';

  // ── Task Actions ──
  static String unclaimTask(int id) => '/tasks/$id/unclaim';
  static String startTask(int id) => '/tasks/$id/start';

  // ── Withdrawals ──
  static const String withdrawals = '/withdrawals';
  static const String myWithdrawals = '/withdrawals/mine';

  // ── InKind Donations ──
  static const String inKind             = '/inkind';
  static const String inKindBoard        = '/inkind/board';
  static const String inKindMine         = '/inkind/mine';
  static const String inKindAdminRecords = '/inkind/admin/records';
  static String inKindById(int id)             => '/inkind/$id';
  static String inKindRequests(int id)         => '/inkind/$id/requests';
  static String inKindRequest(int id)          => '/inkind/$id/request';
  static String inKindAccept(int requestId)    => '/inkind/requests/$requestId/accept';
  static String inKindReject(int requestId)    => '/inkind/requests/$requestId/reject';
  static const String inKindMyRequests         = '/inkind/my-requests';
  static String inKindChatRoom(int requestId)  => '/chat/rooms/inkind/$requestId';

  // ── Goods Campaigns ──
  static const String goodsCampaigns         = '/goods-campaigns';
  static const String myGoodsCampaigns       = '/goods-campaigns/mine';
  static String goodsCampaignById(int id)    => '/goods-campaigns/$id';

  // ── Goods Donations ──
  static const String goodsDonations         = '/goods-donations';
  static const String myGoodsDonations       = '/goods-donations/mine';
  static const String goodsDonationsAvailable = '/goods-donations/available';
  static const String goodsDonationsForReview = '/goods-donations/for-review';
  static const String goodsDonationsNgo       = '/goods-donations/ngo';
  static String goodsDonationById(int id)    => '/goods-donations/$id';
  static String claimGoodsDonation(int id)   => '/goods-donations/$id/claim';
  static String deliverGoodsDonation(int id) => '/goods-donations/$id/deliver';
  static String approveGoodsDonation(int id) => '/goods-donations/$id/approve';
  static String rejectGoodsDonation(int id)  => '/goods-donations/$id/reject';

  // ── Media Upload ──
  static const String mediaUpload = '/media/upload';

  // ── Health ──
  static const String health = '/health';
}
