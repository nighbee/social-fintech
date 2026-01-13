part of 'router.dart';

List<RouteBase> _routes({required AppFlavor flavor}) => <RouteBase>[
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
        path: RoutePaths.log,
        name: RouteNames.log,
        builder: (context, state) => const LogPage(),
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
        routes: [
          // Auth routes
          GoRoute(
            path: RoutePaths.auth,
            name: RouteNames.auth,
            builder: (context, state) => const LoginPage(),
            routes: [
              GoRoute(
                path: RoutePaths.login,
                name: RouteNames.login,
                builder: (context, state) => const LoginPage(),
              ),
            ],
          ),

          // Home route
          GoRoute(
            path: RoutePaths.home,
            name: RouteNames.home,
            pageBuilder: (context, state) {
              return const NoTransitionPage(child: HomePage());
            },
          ),

          // Profile route (protected by auth guard)
          GoRoute(
            path: RoutePaths.profile,
            name: RouteNames.profile,
            redirect: AuthGuard,
            builder: (context, state) {
              return Scaffold(
                appBar: AppBar(title: const Text('Profile')),
                body: const Center(child: Text('Profile Page')),
              );
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
