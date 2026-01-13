import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:app/src/core/router/router.dart';

part 'flavor_builds.dart';

class MainApp extends StatefulWidget {
  const MainApp({required this.flavor, super.key});

  final AppFlavor flavor;

  void run() => runApp(this);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final GoRouter router;

  @override
  void initState() {
    super.initState();
    router = routerProvider(widget.flavor);
  }

  @override
  Widget build(BuildContext context) {
    return _buildApp(flavor: widget.flavor, router: router, languageCode: 'en');
  }
}
