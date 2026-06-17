part of 'router.dart';

// List of routes that don't require authentication
const _authRoutes = [
  RoutePaths.login,
  RoutePaths.loginWithEmail,
  RoutePaths.loginCode,
  RoutePaths.signup,
  RoutePaths.signupWithEmail,
  RoutePaths.code,
  RoutePaths.info,
  RoutePaths.referal,
  RoutePaths.createPassword,
  RoutePaths.emailEntry,
  RoutePaths.emailPassword,
  RoutePaths.changePassword,
];

// ignore: non_constant_identifier_names
FutureOr<String?> AuthGuard(BuildContext context, GoRouterState state) async {
  try {
    final currentPath = state.matchedLocation;
    if (_authRoutes.any((route) => currentPath.startsWith(route))) {
      return null;
    }

    final String? accessToken =
        await SecureStorageServiceImpl().getAccessToken();
    Log.debug(
      'AuthGuard',
      'accessToken: ${accessToken != null ? "exists" : "null"}, path: ${state.uri}',
    );

    if (accessToken == null || accessToken.isEmpty) {
      return RoutePaths.login;
    }

    return null;
  } catch (e) {
    Log.debug('AuthGuard', 'error: $e');
    return RoutePaths.login;
  }
}
