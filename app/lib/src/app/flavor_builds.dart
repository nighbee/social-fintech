part of 'application.dart';

Widget _buildApp({required AppFlavor flavor, required String languageCode}) {
  switch (flavor) {
    case AppFlavor.development:
      return _devApp(languageCode, flavor);
    case AppFlavor.production:
      return _prodApp(languageCode, flavor);
  }
}

MaterialApp _devApp(String languageCode, AppFlavor flavor) => _buildMaterialApp(
  title: 'BrightBund Dev',
  languageCode: languageCode,
  flavor: flavor,
);

MaterialApp _prodApp(String languageCode, AppFlavor flavor) =>
    _buildMaterialApp(
      title: 'BrightBund',
      languageCode: languageCode,
      flavor: flavor,
    );

MaterialApp _buildMaterialApp({
  required String title,
  required String languageCode,
  required AppFlavor flavor,
}) {
  return MaterialApp(
    title: title,
    debugShowCheckedModeBanner: false,
    home: const HomePage(),
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1)),
        child:
            flavor == AppFlavor.development
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
      );
    },
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BrightBund')),
      body: const Center(child: Text('Welcome to BrightBund')),
    );
  }
}

enum AppFlavor {
  development('development'),
  production('production');

  final String envPath;
  const AppFlavor(this.envPath);
}
