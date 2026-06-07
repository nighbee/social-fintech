part of 'application.dart';

Widget _buildApp({
  required AppFlavor flavor,
  required GoRouter router,
  required String languageCode,
}) {
  switch (flavor) {
    case AppFlavor.development:
      return _devApp(router, languageCode, flavor);
    case AppFlavor.production:
      return _prodApp(router, languageCode, flavor);
  }
}

MaterialApp _devApp(GoRouter router, String languageCode, AppFlavor flavor) =>
    _buildMaterialApp(
      router: router,
      title: 'BrightBund Dev',
      languageCode: languageCode,
      flavor: flavor,
    );

MaterialApp _prodApp(GoRouter router, String languageCode, AppFlavor flavor) =>
    _buildMaterialApp(
      router: router,
      title: 'BrightBund',
      languageCode: languageCode,
      flavor: flavor,
    );

MaterialApp _buildMaterialApp({
  required GoRouter router,
  required String title,
  required String languageCode,
  required AppFlavor flavor,
}) {
  return MaterialApp.router(
    title: title,
    theme: MaterialAppTheme.light,
    routerDelegate: router.routerDelegate,
    routeInformationParser: router.routeInformationParser,
    routeInformationProvider: router.routeInformationProvider,
    debugShowCheckedModeBanner: false,
    builder: (context, child) {
      return ColoredBox(
        color: AppColors.mainBackground,
        child: MediaQuery(
          data:
              MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1)),
          child: flavor == AppFlavor.development
              ? Align(
                  alignment: Alignment.topRight,
                  child: Banner(
                    message: flavor.envPath,
                    location: BannerLocation.topEnd,
                    color: Colors.red,
                    child: child!,
                  ),
                )
              : child!,
        ),
      );
    },
  );
}

enum AppFlavor {
  development('development'),
  production('production');

  final String envPath;
  const AppFlavor(this.envPath);
}
