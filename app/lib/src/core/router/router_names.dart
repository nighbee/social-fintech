part of 'router.dart';

class RouteNames {
  static const String initial = 'initial';

  // Auth routes
  static const String auth = 'auth';
  static const String signup = 'signup';
  static const String signupWithEmail = 'signupWithEmail';
  static const String login = 'login';
  static const String loginWithEmail = 'loginWithEmail';
  static const String loginCode = 'loginCode';
  static const String emailEntry = 'emailEntry';
  static const String emailPassword = 'emailPassword';
  static const String register = 'register';
  static const String code = 'code';
  static const String info = 'info';
  static const String referal = 'referal';
  static const String createPassword = 'createPassword';
  static const String changePassword = 'changePassword';

  // Home routes
  static const String home = 'home';
  static const String createPost = 'createPost';

  // Map routes
  static const String map = 'map';
  static const String mapCreateRequest = 'mapCreateRequest';
  static const String mapCreateRequestPublished = 'mapCreateRequestPublished';
  static const String mapRequestCanceled = 'mapRequestCanceled';
  static const String mapRequestCompleted = 'mapRequestCompleted';

  // Rating routes
  static const String rating = 'rating';

  // Chats routes
  static const String chats = 'chats';

  // Profile routes
  static const String profile = 'profile';
  static const String settings = 'settings';
  static const String allies = 'allies';
  static const String publicProfile = 'publicProfile';
  static const String editProfile = 'editProfile';

  // Notifications routes
  static const String notifications = 'notifications';

  // Developer features
  static const String developerFeatures = 'developer_features';
  static const String log = 'log';
  static const String widgetBook = 'widget_book';
  static const String rangs = 'rangs';

  // Add more route names as needed
}
