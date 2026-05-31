class EndPoints {
  //* Base URL
  static const String baseUrl = 'https://brightbund.app/api/v1';
  static const String baseUrlDev = 'https://brightbund.app/api/v1';

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
  static const String authFirebaseEmailLogin = '/auth/firebase-email-login';
  static const String authFirebaseEmailRegister =
      '/auth/firebase-email-register';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';
  static const String profile = '/profiles/me';

  //* Economy
  static const String economyWallet = '/economy/wallet';
  static const String economyTransfer = '/economy/transfer';
  static const String economyLedger = '/economy/ledger';
  static const String economyBalance = '/economy/balance';
  static const String economyLimits = '/economy/limits';
  static const String economyAccrualClaim = '/economy/accrual/claim';

  //* Feed
  static const String feed = '/feed';
  static const String feedMediaUpload = '/feed/media/upload';
  static const String feedState = '/feed/state';
  static const String feedStateSync = '/feed/state/sync';
  static const String posts = '/posts';
  static String postById(String postId) => '/posts/$postId';
  static String postComments(String postId) => '/posts/$postId/comments';
  static String postReport(String postId) => '/posts/$postId/report';
  static String postLikes(String postId) => '/posts/$postId/likes';
  static String postSeals(String postId) => '/posts/$postId/seals';
  static String commentLikes(String commentId) =>
      '/feed/comments/$commentId/likes';

  //* Notifications
  static const String notifications = '/notifications';
  static String notificationRead(String notificationId) =>
      '/notifications/$notificationId/read';

  //* Gamification
  static const String gamificationRank = '/gamification/rank';
  static const String gamificationRanks = '/gamification/ranks';

  //* Leaderboard
  static const String leaderboard = '/leaderboard';
  static const String adminLeaderboardScopes = '/admin/leaderboard/scopes';
  static const String adminLeaderboardAddUser = '/admin/leaderboard/add-user';
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
  static String mapTaskApplications(String taskId) =>
      '/tasks/$taskId/applications';
  static String mapWithdrawTaskApplication(
          String taskId, String applicationId) =>
      '/tasks/$taskId/applications/$applicationId';
  static String mapAcceptTaskApplication(String taskId, String applicationId) =>
      '/tasks/$taskId/applications/$applicationId/accept';
  static String mapRejectTaskApplication(String taskId, String applicationId) =>
      '/tasks/$taskId/applications/$applicationId/reject';
  static String mapConfirmTaskApplication(
          String taskId, String applicationId) =>
      '/tasks/$taskId/applications/$applicationId/confirm';
  static String mapVerifyTaskApplicationCode(
    String taskId,
    String applicationId,
  ) =>
      '/tasks/$taskId/applications/$applicationId/verify-code';
  static const String mapRegion = '/map/region';
  static const String mapChampions = '/map/champions';

  //* Payment
  static const String paymentWebhookRevenuecat = '/payment/webhook/revenuecat';

  //* Users
  static const String usersSearch = '/users/search';

  //* Chats
  static const String chatsConversations = '/chats/conversations';
  static const String chatsMediaUpload = '/chats/media/upload';
  static const String chatsWs = '/chats/ws';
  static String chatsConversationMessages(String conversationId) =>
      '/chats/conversations/$conversationId/messages';
  static String chatsConversationRead(String conversationId) =>
      '/chats/conversations/$conversationId/read';
  static const String chatsConversationsDirect = '/chats/conversations/direct';
  static String chatsConversationAccept(String conversationId) =>
      '/chats/conversations/$conversationId/accept';
  static String chatsConversationDecline(String conversationId) =>
      '/chats/conversations/$conversationId/decline';
  static String chatsConversationMute(String conversationId) =>
      '/chats/conversations/$conversationId/mute';
  static String chatsConversationPin(String conversationId) =>
      '/chats/conversations/$conversationId/pin';
  static String chatsConversationPinMessage(String conversationId) =>
      '/chats/conversations/$conversationId/pin-message';
  static String chatsConversationPinnedMessages(String conversationId) =>
      '/chats/conversations/$conversationId/pinned-messages';
  static String chatsConversationMessage(
    String conversationId,
    String messageId,
  ) =>
      '/chats/conversations/$conversationId/messages/$messageId';

  //* Profile
  static const String profiles = '/profiles';
  static const String profileMe = '/profiles/me';
  static const String profileSearch = '/profiles/search';
  static const String profileMePosts = '/profiles/me/posts';
  static const String profileMePostsList = '/profiles/me/posts/list';
  static String profilePostsById(String userId) => '/profiles/$userId/posts';
  static String profilePostsListById(String userId) =>
      '/profiles/$userId/posts/list';
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

  //* Settings — feed (see backend /settings/feed)
  static const String settingsFeed = '/settings/feed';

  //* Settings — security (see backend /settings/security/*)
  static const String settingsSecurity = '/settings/security';
  static const String settingsSecurityPassword = '/settings/security/password';
  static const String settingsSecuritySessions = '/settings/security/sessions';
  static const String settingsSecurityDeleteAccountReason =
      '/settings/security/delete-account/reason';
  static const String settingsSecurityDeleteAccountVerify =
      '/settings/security/delete-account/verify';
  static const String settingsSecurityDeleteAccount =
      '/settings/security/delete-account';

  //* Settings — interactions (see backend /settings/interactions/*)
  static const String settingsInteractions = '/settings/interactions';
  static const String settingsInteractionsMessages =
      '/settings/interactions/messages';
  static const String settingsInteractionsComments =
      '/settings/interactions/comments';
  static const String settingsInteractionsMentions =
      '/settings/interactions/mentions';
  static const String settingsInteractionsBlocked =
      '/settings/interactions/blocked';
  static String settingsInteractionsBlockedUser(String userId) =>
      '/settings/interactions/blocked/$userId';
  static String settingsInteractionsMessageKeyword(String id) =>
      '/settings/interactions/messages/keywords/$id';
  static const String settingsInteractionsMessageKeywords =
      '/settings/interactions/messages/keywords';

  //* Support — bug reports (see backend POST /settings/support/bugs)
  static const String settingsSupportBugs = '/settings/support/bugs';
}
