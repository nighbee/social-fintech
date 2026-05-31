part of 'router.dart';

class RoutePaths {
  static const String initial = '/';

  // Auth routes
  static const String auth = '/auth';
  static const String signup = '/signup';
  static const String signupWithEmail = '/signup/email';
  static const String login = '/login';
  static const String loginWithEmail = '/login/email';
  static const String loginCode = '/login/code';
  static const String emailEntry = '/email-entry';
  static const String emailPassword = '/email-password';
  static const String register = '/register';
  static const String code = '/code';
  static const String info = '/info';
  static const String referal = '/referal';
  static const String createPassword = '/create-password';
  static const String changePassword = '/change-password';

  // Home routes
  static const String home = '/home';
  static const String createPost = '/create-post';
  static const String notifications = '/notifications';
  static const String search = '/search';
  static const String store = '/store';

  // Map routes
  static const String map = '/map';
  static const String mapCreateRequest = '/map/create-request';
  static const String mapCreateRequestPublished =
      '/map/create-request/published';
  static const String mapRequestCanceled = '/map/request-canceled';
  static const String mapRequestClosed = '/map/request-closed';
  static const String mapRequestCompleted = '/map/request-completed';

  // Rating routes
  static const String rating = '/rating';

  // Chats routes
  static const String chats = '/chats';

  /// Полноэкранный диалог (корневой стек GoRouter, не вложен в [chats]).
  static const String chatThread = '/chat/:chatId';

  // Profile routes
  static const String profile = '/profile';

  /// Full path for nested GoRoute (`path: 'publications'` under [profile]).
  static const String profilePublications = '$profile/publications';
  static const String profileStats = '$profile/stats';
  static const String settings = '/settings';
  static const String allies = '/allies';
  static const String publicProfile = '/public-profile/:userId';
  static const String editProfile = 'edit-profile';
  static const String editProfileNickname = 'edit-profile-nickname';
  static const String editProfileBio = 'edit-profile-bio';

  // Developer features
  static const String developerFeatures = '/developer_features';
  static const String log = '/log';
  static const String widgetBook = '/widget_book';
  static const String rangs = '/rangs';
  static const String leaderboardAdmin = '/leaderboard_admin';
  static const String feedPreview = '/feed-preview';

  // Add more routes as needed
}
