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

  // ── Health ──
  static const String health = '/health';
}
