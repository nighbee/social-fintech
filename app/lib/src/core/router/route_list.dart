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
                builder: (context, state) => const CodePage(),
              ),
              GoRoute(
                path: RoutePaths.info,
                name: RouteNames.info,
                builder: (context, state) => const InfoPage(),
              ),
              GoRoute(
                path: RoutePaths.referal,
                name: RouteNames.referal,
                builder: (context, state) => const ReferalPage(),
              ),
              GoRoute(
                path: RoutePaths.createPassword,
                name: RouteNames.createPassword,
                builder: (context, state) => const CreatePasswordPage(),
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
                path: RoutePaths.loginCode,
                name: RouteNames.loginCode,
                builder: (context, state) => const LoginCodePage(),
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

              // Map route (protected by auth guard)
              GoRoute(
                path: RoutePaths.map,
                name: RouteNames.map,
                redirect: AuthGuard,
                pageBuilder: (context, state) {
                  return const NoTransitionPage(child: MapPage());
                },
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
                    path: RoutePaths.settings,
                    name: RouteNames.settings,
                    redirect: AuthGuard,
                    builder: (context, state) {
                      return Scaffold(
                        appBar: AppBar(title: const Text('Settings')),
                        body: const Center(child: Text('Settings Page')),
                      );
                    },
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
