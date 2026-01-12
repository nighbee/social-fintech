import 'package:flutter/material.dart';

part 'flavor_builds.dart';

class MainApp extends StatefulWidget {
  const MainApp({required this.flavor, super.key});

  final AppFlavor flavor;

  void run() => runApp(this);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  Widget build(BuildContext context) {
    return _buildApp(flavor: widget.flavor, languageCode: 'en');
  }
}
