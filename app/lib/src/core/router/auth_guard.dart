part of 'router.dart';

// ignore: non_constant_identifier_names
FutureOr<String?> AuthGuard(BuildContext context, GoRouterState state) async {
  try {
    final String? accessToken = await SecureStorageServiceImpl()
        .getAccessToken();
    Log.debug(
      'AuthGuard',
      'accessToken: ${accessToken != null ? "exists" : "null"}, path: ${state.uri}',
    );
    if (accessToken == null || accessToken.isEmpty) {
      return RoutePaths.loginWithEmail; // Redirect to login page
    }
    return null; // Allow access
  } catch (e) {
    Log.debug('AuthGuard', 'error: $e');
    return RoutePaths.loginWithEmail;
  }
}
