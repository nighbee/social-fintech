import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: CustomAppBar(showLeading: false),
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.home),
      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          children: [
            Gap(12),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Welcome to BrightBund',
                      style: context.theme.textStyles.titleLarge,
                    ),
                    Gap(20),
                    Text(
                      'Home page content will be added here',
                      style: context.theme.textStyles.codePageSubtitle,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
