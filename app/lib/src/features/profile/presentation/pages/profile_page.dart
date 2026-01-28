import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final profileBloc = getIt<ProfileBloc>();

  @override
  void initState() {
    super.initState();
    profileBloc.add(const ProfileEvent.loadProfile());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: CustomAppBar(
        showLeading: false,
        actions: [Assets.icons.settingsIcon.svg(), Gap(20)],
      ),
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.profile),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        bloc: profileBloc,
        builder: (context, state) {
          return state.when(
            initial: () => const SizedBox.shrink(),
            loading: () => const Center(child: CircularProgressIndicator()),
            loadingError: (message) => Center(child: Text(message)),
            loaded: (user) {
              return SafeArea(
                child: Column(
                  children: [
                    Container(
                      margin: EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.1,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.whiteBackground,
                                  ),
                                  gradient: RadialGradient(
                                    center: Alignment.topLeft,
                                    radius: 1.5,
                                    stops: const [0.0, 0.24, 0.44, 0.67, 0.90],
                                    colors: [
                                      Color(0xFFd7e1ea).withOpacity(0.20),
                                      Color(0xff93cafc).withOpacity(0.30),
                                      Color(0xFF52ace1).withOpacity(0.80),
                                      Color(0xFF94bee2).withOpacity(0.80),
                                      Color(0xFFcedbe6).withOpacity(0.60),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
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
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                      ),
                                    ),
                                    Gap(12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '@${user.firstName} ${user.lastName}',
                                          style: context
                                              .theme
                                              .textStyles
                                              .bodyLarge
                                              .copyWith(fontSize: 20),
                                        ),
                                        Gap(8),
                                        Text(
                                          "Almaty | KZ",
                                          style: context
                                              .theme
                                              .textStyles
                                              .caption
                                              .copyWith(fontSize: 13),
                                        ),
                                        Gap(10),
                                        Text(
                                          "Moonstone \u2022 Clarity \u2022 A \ud83c\udf0d",
                                          style: context
                                              .theme
                                              .textStyles
                                              .caption
                                              .copyWith(
                                                color: AppColors.blueText1,
                                              ),
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
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                children: [
                                                  Assets.icons.coin.svg(
                                                    width: 40,
                                                  ),
                                                  Text(
                                                    '0',
                                                    style: context
                                                        .theme
                                                        .textStyles
                                                        .bodyMediumBold
                                                        .copyWith(
                                                          fontSize: 18,
                                                          color: AppColors
                                                              .whiteBackground,
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
                                                borderRadius:
                                                    BorderRadius.circular(4),
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
                                    Expanded(
                                      child: Container(
                                        height: 36,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Color(0xFF3C3C3C),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          "Edit profile",
                                          style: context
                                              .theme
                                              .textStyles
                                              .bodySmall
                                              .copyWith(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                    Gap(8),
                                    Expanded(
                                      child: Container(
                                        height: 36,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Color(0xFF3C3C3C),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          "Share profile",
                                          style: context
                                              .theme
                                              .textStyles
                                              .bodySmall
                                              .copyWith(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                    Gap(8),
                                    Container(
                                      height: 36,
                                      width: 44,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Color(0xFF3C3C3C),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.person_outline,
                                        size: 18,
                                        color: Colors.white70,
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
              );
            },
          );
        },
      ),
    );
  }
}
