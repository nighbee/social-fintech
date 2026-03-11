part of 'router.dart';

List<RouteBase> _routes({required Talker talker, required AppFlavor flavor}) =>
    <RouteBase>[
      // Initial route - redirects to home
      GoRoute(
        path: RoutePaths.initial,
        name: RouteNames.initial,
        redirect: (context, state) {
          return RoutePaths.home;
        },
      ),

      // Developer features route (outside shell for easy access)
      GoRoute(
        path: RoutePaths.developerFeatures,
        name: RouteNames.developerFeatures,
        builder: (context, state) => const DeveloperFeaturesPage(),
        routes: [
          GoRoute(
            path: 'log',
            name: RouteNames.log,
            builder: (context, state) => TalkerScreen(
              talker: talker,
              theme: TalkerScreenTheme.fromTheme(Theme.of(context), {
                TalkerLogType.blocEvent.key: Colors.green,
                TalkerLogType.blocTransition.key: Colors.green,
                TalkerLogType.httpResponse.key: Colors.green,
              }),
            ),
          ),
          GoRoute(
            path: 'widget_book',
            name: RouteNames.widgetBook,
            builder: (context, state) => const WidgetBookPage(),
          ),
          GoRoute(
            path: 'rangs',
            name: RouteNames.rangs,
            builder: (context, state) => const RangsPage(),
          ),
          // Public Profile route (protected by auth guard)
          GoRoute(
            path: RoutePaths.publicProfile,
            name: RouteNames.publicProfile,
            redirect: AuthGuard,
            builder: (context, state) {
              final userId = state.pathParameters['userId'] ?? '';
              return PublicProfilePage(userId: userId);
            },
          ),
        ],
      ),

      // Main app routes wrapped in StatefulShellRoute for LogPushButton
      StatefulShellRoute.indexedStack(
        builder: (context, state, child) {
          return Stack(
            children: [
              child,
              // Show LogPushButton only in development flavor
              if (flavor == AppFlavor.development) const LogPushButton(),
            ],
          );
        },
        branches: [
          StatefulShellBranch(
            observers: [TalkerRouteObserver(talker)],
            routes: [
              // Auth routes - Signup
              GoRoute(
                path: RoutePaths.signup,
                name: RouteNames.signup,
                builder: (context, state) => const SignupWithNumberPage(),
              ),
              GoRoute(
                path: RoutePaths.signupWithEmail,
                name: RouteNames.signupWithEmail,
                builder: (context, state) => const SignupWithEmailPage(),
              ),
              GoRoute(
                path: RoutePaths.code,
                name: RouteNames.code,
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return CodePage(
                    verificationId: extra?['verificationId'] ?? '',
                    phoneNumber: extra?['phoneNumber'] ?? '',
                    isLogin: extra?['isLogin'] ?? true,
                  );
                },
              ),
              GoRoute(
                path: RoutePaths.info,
                name: RouteNames.info,
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return InfoPage(
                    email: extra?['email'] as String?,
                    password: extra?['password'] as String?,
                    phoneNumber: extra?['phoneNumber'] as String?,
                    firebaseIdToken: extra?['firebaseIdToken'] as String?,
                  );
                },
              ),
              GoRoute(
                path: RoutePaths.referal,
                name: RouteNames.referal,
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return ReferalPage(
                    email: extra?['email'] as String?,
                    password: extra?['password'] as String?,
                    phoneNumber: extra?['phoneNumber'] as String?,
                    firebaseIdToken: extra?['firebaseIdToken'] as String?,
                    firstName: extra?['firstName'] as String?,
                    lastName: extra?['lastName'] as String?,
                    dateOfBirth: extra?['dateOfBirth'] as String?,
                  );
                },
              ),
              GoRoute(
                path: RoutePaths.createPassword,
                name: RouteNames.createPassword,
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  final email = extra?['email'] as String? ?? '';
                  return CreatePasswordPage(email: email);
                },
              ),
              // Auth routes - Login
              GoRoute(
                path: RoutePaths.login,
                name: RouteNames.login,
                builder: (context, state) => const LoginWithNumberPage(),
              ),
              GoRoute(
                path: RoutePaths.loginWithEmail,
                name: RouteNames.loginWithEmail,
                builder: (context, state) => const LoginWithEmailPage(),
              ),
              GoRoute(
                path: RoutePaths.emailEntry,
                name: RouteNames.emailEntry,
                builder: (context, state) => const EmailEntryPage(),
              ),
              GoRoute(
                path: RoutePaths.emailPassword,
                name: RouteNames.emailPassword,
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return EmailPasswordPage(
                    email: extra?['email'] ?? '',
                    isNewUser: extra?['isNewUser'] ?? false,
                  );
                },
              ),
              GoRoute(
                path: RoutePaths.loginCode,
                name: RouteNames.loginCode,
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return LoginCodePage(
                    verificationId: extra?['verificationId'] ?? '',
                    phoneNumber: extra?['phoneNumber'] ?? '',
                    isLogin: extra?['isLogin'] ?? true,
                  );
                },
              ),
              GoRoute(
                path: RoutePaths.changePassword,
                name: RouteNames.changePassword,
                builder: (context, state) => const ChangePasswordPage(),
              ),

              // Home route (protected by auth guard)
              GoRoute(
                path: RoutePaths.home,
                name: RouteNames.home,
                redirect: AuthGuard,
                pageBuilder: (context, state) {
                  return const NoTransitionPage(child: HomePage());
                },
              ),
              GoRoute(
                path: RoutePaths.createPost,
                name: RouteNames.createPost,
                redirect: AuthGuard,
                builder: (context, state) => const CreatePostPage(),
              ),

              // Map route (protected by auth guard)
              GoRoute(
                path: RoutePaths.map,
                name: RouteNames.map,
                redirect: AuthGuard,
                pageBuilder: (context, state) {
                  return const NoTransitionPage(child: MapPage());
                },
              ),
              GoRoute(
                path: RoutePaths.mapCreateRequest,
                name: RouteNames.mapCreateRequest,
                redirect: AuthGuard,
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  final latitude = (extra?['latitude'] as num?)?.toDouble() ?? 50.4501;
                  final longitude =
                      (extra?['longitude'] as num?)?.toDouble() ?? 30.5234;
                  return CreateRequestPage(
                    latitude: latitude,
                    longitude: longitude,
                  );
                },
              ),
              GoRoute(
                path: RoutePaths.mapCreateRequestPublished,
                name: RouteNames.mapCreateRequestPublished,
                redirect: AuthGuard,
                builder: (context, state) => const CreateRequestPublishedPage(),
              ),
              GoRoute(
                path: RoutePaths.mapRequestCanceled,
                name: RouteNames.mapRequestCanceled,
                redirect: AuthGuard,
                builder: (context, state) => const MapRequestCanceledPage(),
              ),
              GoRoute(
                path: RoutePaths.mapRequestCompleted,
                name: RouteNames.mapRequestCompleted,
                redirect: AuthGuard,
                builder: (context, state) => const MapRequestCompletedPage(),
              ),

              // Rating route (protected by auth guard)
              GoRoute(
                path: RoutePaths.rating,
                name: RouteNames.rating,
                redirect: AuthGuard,
                pageBuilder: (context, state) {
                  return const NoTransitionPage(child: RatingPage());
                },
              ),

              // Chats route (protected by auth guard)
              GoRoute(
                path: RoutePaths.chats,
                name: RouteNames.chats,
                redirect: AuthGuard,
                pageBuilder: (context, state) {
                  return const NoTransitionPage(child: ChatsPage());
                },
              ),

              // Notifications route (protected by auth guard)
              GoRoute(
                path: RoutePaths.notifications,
                name: RouteNames.notifications,
                redirect: AuthGuard,
                pageBuilder: (context, state) {
                  return const NoTransitionPage(child: NotificationsPage());
                },
              ),

              // Profile route (protected by auth guard)
              GoRoute(
                path: RoutePaths.profile,
                name: RouteNames.profile,
                redirect: AuthGuard,
                pageBuilder: (context, state) {
                  return NoTransitionPage(child: ProfilePage());
                },
                routes: [
                  GoRoute(
                    path: 'settings',
                    name: RouteNames.settings,
                    redirect: AuthGuard,
                    builder: (context, state) {
                      return Scaffold(
                        appBar: AppBar(title: const Text('Settings')),
                        body: const Center(child: Text('Settings Page')),
                      );
                    },
                  ),
                  GoRoute(
                    path: RoutePaths.editProfile,
                    name: RouteNames.editProfile,
                    builder: (context, state) => const EditProfilePage(),
                  ),
                  GoRoute(
                    path: 'allies',
                    name: RouteNames.allies,
                    redirect: AuthGuard,
                    builder: (context, state) => const AlliesPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ];

class LogPushButton extends StatelessWidget {
  const LogPushButton({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Positioned(
      right: 0,
      top: (height - (height / 4)),
      child: GestureDetector(
        onTap: () => context.push(RoutePaths.developerFeatures),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
          child: const Icon(Icons.logo_dev_rounded),
        ),
      ),
    );
  }
}

