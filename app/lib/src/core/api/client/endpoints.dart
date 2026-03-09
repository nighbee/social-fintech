class EndPoints {
  //* Base URL
  static const String baseUrl = 'http://localhost:8081/api/v1';
  static const String baseUrlDev = 'http://10.0.2.2:8081/api/v1';

  //* Auth
  static const String authLogin = '/auth/login';
  static const String authCheckEmail = '/auth/check-email';
  static const String authLoginEmail = '/auth/login-email';
  static const String authRegisterEmail = '/auth/register-email';
  static const String authRegisterPhone = '/auth/register-phone';
  static const String authPhoneRequest = '/auth/phone/request';
  static const String authPhoneVerify = '/auth/phone/verify';
  static const String authFirebasePhoneLogin = '/auth/firebase-phone-login';
  static const String authFirebasePhoneRegister =
      '/auth/firebase-phone-register';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';
  static const String profile = '/profiles/me';

  //* Economy
  static const String economyWallet = '/economy/wallet';
  static const String economyTransfer = '/economy/transfer';
  static const String economyLedger = '/economy/ledger';

  //* Feed
  static const String feed = '/feed';
  static const String feedState = '/feed/state';
  static const String feedStateSync = '/feed/state/sync';
  static const String posts = '/posts';
  static String postComments(String postId) => '/posts/$postId/comments';
  static String postLikes(String postId) => '/posts/$postId/likes';

  //* Gamification
  static const String gamificationRank = '/gamification/rank';
  static const String gamificationRanks = '/gamification/ranks';

  //* Leaderboard
  static const String leaderboardGlobal = '/leaderboards/global';
  static String leaderboardLocal(String regionId) =>
      '/leaderboards/local/$regionId';
  static const String leaderboardMe = '/leaderboards/me';

  //* Map
  static const String mapTasks = '/tasks';
  static const String mapTasksNearby = '/tasks/nearby';
  static const String mapTasksApplied = '/tasks/applied';
  static const String mapTasksMy = '/tasks/my';
  static String mapTaskById(String taskId) => '/tasks/$taskId';
  static String mapApplyToTask(String taskId) => '/tasks/$taskId/apply';
  static String mapTaskApplications(String taskId) => '/tasks/$taskId/applications';
  static String mapWithdrawTaskApplication(String taskId, String applicationId) =>
      '/tasks/$taskId/applications/$applicationId';
  static String mapAcceptTaskApplication(String taskId, String applicationId) =>
      '/tasks/$taskId/applications/$applicationId/accept';
  static String mapRejectTaskApplication(String taskId, String applicationId) =>
      '/tasks/$taskId/applications/$applicationId/reject';
  static String mapConfirmTaskApplication(String taskId, String applicationId) =>
      '/tasks/$taskId/applications/$applicationId/confirm';
  static String mapVerifyTaskApplicationCode(
    String taskId,
    String applicationId,
  ) => '/tasks/$taskId/applications/$applicationId/verify-code';
  static const String mapRegion = '/map/region';
  static const String mapChampions = '/map/champions';

  //* Payment
  static const String paymentWebhookRevenuecat = '/payment/webhook/revenuecat';

  //* Users
  static const String usersSearch = '/users/search';

  //* Profile
  static const String profiles = '/profiles';
  static const String profileMe = '/profiles/me';
  static const String profileUpdate = '/profiles/me';
  static String profileById(String userId) => '/profiles/$userId';
  static const String profileMeStats = '/profiles/me/stats';
  static String profileStatsById(String userId) => '/profiles/$userId/stats';
  static const String profileMeAvatar = '/profiles/me/avatar';
  static String profileAddAlly(String userId) => '/profiles/$userId/allies';
  static String profileRemoveAlly(String userId) => '/profiles/$userId/allies';
  static String profileGetAllies(String userId) => '/profiles/$userId/allies';
  static String profileBlock(String userId) => '/profiles/$userId/block';
  static String profileUnblock(String userId) => '/profiles/$userId/block';
  static String profileRestrict(String userId) => '/profiles/$userId/restrict';
  static String profileUnrestrict(String userId) =>
      '/profiles/$userId/restrict';
  static String profileReport(String userId) => '/profiles/$userId/report';
  static String profileRelationship(String userId) =>
      '/profiles/$userId/relationship';
}
