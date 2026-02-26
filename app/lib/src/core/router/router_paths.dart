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

  // Map routes
  static const String map = '/map';

  // Rating routes
  static const String rating = '/rating';

  // Chats routes
  static const String chats = '/chats';

  // Profile routes
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String allies = '/allies';
  static const String publicProfile = '/public-profile/:userId';
  static const String editProfile = 'edit-profile';

  // Developer features
  static const String developerFeatures = '/developer_features';
  static const String log = '/log';
  static const String widgetBook = '/widget_book';
  static const String rangs = '/rangs';

  // Add more routes as needed
}
