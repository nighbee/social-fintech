part of 'router.dart';

// ignore: non_constant_identifier_names
FutureOr<String?> AuthGuard(BuildContext context, GoRouterState state) async {
  // TODO: Implement proper authentication check
  // For now, this allows all access. Update when SecureStorageServiceImpl is available
  try {
    // Example: Check if user is authenticated
    // final String? accessToken = await SecureStorageServiceImpl().getAccessToken();
    // if (accessToken == null || accessToken.isEmpty) {
    //   return RoutePaths.auth;
    // }
    debugPrint('AuthGuard: Allowing access to ${state.uri}');
    return null; // Allow access
  } catch (e) {
    debugPrint('AuthGuard error: $e');
    return RoutePaths.auth;
  }
}
