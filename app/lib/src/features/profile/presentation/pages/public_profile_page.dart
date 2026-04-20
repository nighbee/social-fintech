import 'package:app/gen/assets.gen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:app/src/features/profile/presentation/mixins/show_profile_actions_bottom_sheet.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_header_card.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_post_grid.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PublicProfilePage extends StatefulWidget {
  final String userId;

  const PublicProfilePage({super.key, required this.userId});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage>
    with ShowProfileActionsBottomSheet {
  @override
  void initState() {
    super.initState();
    getIt<ProfileBloc>().add(ProfileEvent.loadPublicProfile(widget.userId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      bloc: getIt<ProfileBloc>(),
      builder: (context, state) {
        final bloc = getIt<ProfileBloc>();
        return Scaffold(
          backgroundColor: AppColors.mainBackground,
          appBar: AppBar(
            backgroundColor: AppColors.mainBackground,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Profile',
              style: TextStyles.titleMain.copyWith(color: Colors.white),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {
                  showProfileActionsBottomSheet(
                    context,
                    userName: state.maybeMap(
                      loaded: (state) =>
                          state.viewModel.publicProfile.displayName,
                      orElse: () => 'Пользователь',
                    ),
                    onBlock: () {
                      bloc.add(ProfileEvent.blockUser(widget.userId));
                    },
                    onReport: () {
                      bloc.add(ProfileEvent.reportUser(widget.userId));
                    },
                    onRestrict: () {
                      bloc.add(ProfileEvent.restrictUser(widget.userId));
                    },
                    onCopyUrl: () {},
                    onAbout: () {},
                    onShare: () {},
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: state.when(
              initial: () => const Center(child: CircularProgressIndicator()),
              loading: (_) => const Center(child: CircularProgressIndicator()),
              loadingError: (message) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: TextStyles.bodyMain.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              loaded: (viewModel) {
                final profile = viewModel.publicProfile;

                return CustomScrollView(
                  slivers: [
                    // Profile Header Card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ProfileHeaderCard(
                          displayName: profile.displayName,
                          userId: profile.userId,
                          firstName: profile.firstName,
                          lastName: profile.lastName,
                          avatarUrl: profile.avatarUrl,
                          bio: profile.bio,
                          city: profile.city,
                          country: profile.country,
                          region: profile.region,
                          rankTier: profile.rankTier,
                          reputationScore: profile.reputationScore,
                          isPublicProfile: true,
                          relationshipStatus: viewModel.relationshipStatus,
                          onFollow: () =>
                              bloc.add(ProfileEvent.becomeAlly(widget.userId)),
                          onUnfollow: () =>
                              bloc.add(ProfileEvent.removeAlly(widget.userId)),
                          onUnblock: () =>
                              bloc.add(ProfileEvent.unblockUser(widget.userId)),
                        ),
                      ),
                    ),
                    if (viewModel.relationshipStatus.iBlockedThem)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Assets.icons.blocked.svg(
                              width: 64,
                              height: 64,
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'You\'ve blocked this account',
                              style: TextStyles.titleMain.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                              ),
                              child: Text(
                                'Unblock this account to see their photos and videos. When you unblock them, they\'ll also be able to find your profile, see your content and message you again.',
                                style: TextStyles.bodyMain.copyWith(
                                  color: const Color(0xFF6D6D6D),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      // Posts Grid
                      ProfilePostGrid(posts: []),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
