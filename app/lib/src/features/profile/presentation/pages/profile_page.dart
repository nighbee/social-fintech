import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/widgets/list_item/custom_list_item.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:app/src/features/profile/presentation/utils/mock_data.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_header_card.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_post_grid.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ProfilePageContent();
  }
}

class _ProfilePageContent extends StatefulWidget {
  const _ProfilePageContent();

  @override
  State<_ProfilePageContent> createState() => _ProfilePageContentState();
}

class _ProfilePageContentState extends State<_ProfilePageContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = getIt<ProfileBloc>();
      final shouldLoad = bloc.state.maybeWhen(
        initial: () => true,
        loadingError: (_) => true,
        orElse: () => false,
      );
      if (shouldLoad) {
        bloc.add(const ProfileEvent.loadProfile());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Layer 1: Fixed particle background (behind everything)
        Positioned.fill(
          child: Container(
            color: AppColors.colorff19191A,
            child: const IgnorePointer(
              child: ParticleAnimation(
                particleCount: 20,
                particleColors: [Color(0xFFFFFFFF)],
                minSize: 4.0,
                maxSize: 8.0,
                minDistanceBetweenParticles: 70.0,
              ),
            ),
          ),
        ),
        // Layer 2: Scaffold with transparent background (above particles)
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: CustomAppBar(
            backgroundColor: Colors.transparent,
            showLeading: false,
            actions: [
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (context) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 20),
                          CustomListItem(
                            title: 'Log out',
                            iconRight: true,
                            color: Colors.red,
                            onTap: () {
                              context.pop(); // Close bottom sheet
                              getIt<AuthBloc>().add(const AuthEvent.logout());
                              context.go(RoutePaths.loginWithEmail);
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  );
                },
                child: Assets.icons.settingsIcon.svg(),
              ),
              const Gap(16),
            ],
          ),
          bottomNavigationBar: const CustomNavBar(
            currentTab: RoutePaths.profile,
          ),
          body: SafeArea(
            child: BlocBuilder<ProfileBloc, ProfileState>(
              bloc: getIt<ProfileBloc>(),
              builder: (context, state) {
                return state.when(
                  initial: () =>
                      const Center(child: CircularProgressIndicator()),
                  loading: (_) =>
                      const Center(child: CircularProgressIndicator()),
                  loadingError: (message) => Center(child: Text(message)),
                  loaded: (ProfileViewModel viewmodel) {
                    final profile = viewmodel.profile;

                    return CustomScrollView(
                      slivers: [
                        // Profile Header Card
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ProfileHeaderCard(
                              displayName: profile.displayName,
                              userId: profile.userId,
                              avatarUrl: profile.avatarUrl,
                              city: profile.city,
                              country: profile.country,
                              region: profile.region,
                              rankTier: profile.rankTier,
                              reputationScore: profile.reputationScore,
                            ),
                          ),
                        ),
                        // Posts Grid
                        ProfilePostGrid(posts: mockPosts),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
