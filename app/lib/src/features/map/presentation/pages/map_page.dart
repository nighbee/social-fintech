import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:flutter/material.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: const CustomAppBar(showLeading: false),
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.map),
      body: const SafeArea(child: Center(child: Text('Map Page'))),
    );
  }
}
