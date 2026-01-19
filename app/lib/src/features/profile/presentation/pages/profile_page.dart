import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: CustomAppBar(
        showLeading: false,
        actions: [Assets.icons.settingsIcon.svg(), Gap(20)],
      ),
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.profile),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
              child: Stack(
                children: [
                  // Gradient background with opacity - fills entire container
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.whiteBackground),
                          gradient: RadialGradient(
                            center: Alignment.topLeft,
                            radius: 1.5,
                            stops: const [
                              0.0, // Stop 1: 0%
                              0.24, // Stop 2: 24%
                              0.44, // Stop 3: 44%
                              0.67, // Stop 4: 67%
                              0.90, // Stop 5: 90%
                            ],
                            colors: [
                              Color(
                                0xFFd7e1ea,
                              ).withOpacity(0.20), // Stop 1: 20% opacity
                              Color(
                                0xff93cafc,
                              ).withOpacity(0.30), // Stop 2: 30% opacity
                              Color(
                                0xFF52ace1,
                              ).withOpacity(0.80), // Stop 3: 80% opacity
                              Color(
                                0xFF94bee2,
                              ).withOpacity(0.80), // Stop 4: 80% opacity
                              Color(
                                0xFFcedbe6,
                              ).withOpacity(0.60), // Stop 5: 60% opacity
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Content on top (no opacity) - determines container height
                  Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 126,
                              height: 126,
                              decoration: BoxDecoration(color: Colors.red),
                            ),
                            Gap(12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "@Ayaulym Yesmoldayeva",
                                  style: context.theme.textStyles.bodyLarge
                                      .copyWith(fontSize: 20),
                                ),
                                Gap(8),
                                Text(
                                  "Almaty | KZ",
                                  style: context.theme.textStyles.caption
                                      .copyWith(fontSize: 13),
                                ),
                                Gap(10),
                                Text(
                                  "Almaty | KZ",
                                  style: context.theme.textStyles.caption
                                      .copyWith(color: AppColors.blueText1),
                                ),
                                Gap(13),
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 5,
                                      ),
                                      height: 35,
                                      decoration: BoxDecoration(
                                        color: Color(0xFF404040),
                                        border: Border.all(
                                          color: Color(0xFF626262),
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          Assets.icons.coin.svg(width: 40),
                                          // Gap(6),
                                          Text(
                                            "27",
                                            style: context
                                                .theme
                                                .textStyles
                                                .bodyMediumBold
                                                .copyWith(
                                                  fontSize: 18,
                                                  color:
                                                      AppColors.whiteBackground,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Gap(6),
                                    Container(
                                      height: 35,

                                      padding: EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF404040),
                                        border: Border.all(
                                          color: Color(0xFF626262),
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          Assets.icons.statsIcon.svg(),
                                          Gap(6),
                                          Text(
                                            "Your Stats",
                                            style: context
                                                .theme
                                                .textStyles
                                                .bodySmall
                                                .copyWith(fontSize: 15),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),

                        Gap(16),

                        Row(
                          children: [
                            Container(
                              height: 35,

                              padding: EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: Color(0xFF404040),
                                border: Border.all(color: Color(0xFF626262)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Assets.icons.statsIcon.svg(),
                                  Gap(6),
                                  Text(
                                    "Your Stats",
                                    style: context.theme.textStyles.bodySmall
                                        .copyWith(fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
