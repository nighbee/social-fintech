import 'package:app/src/core/base/base_bloc/bloc/base_bloc_widget.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:app/src/features/profile/presentation/mixins/show_profile_actions_bottom_sheet.dart';
import 'package:app/src/features/profile/presentation/utils/mock_data.dart';
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
  Widget build(BuildContext context) {
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
            onPressed: () => _showActions(context),
          ),
        ],
      ),
      body: SafeArea(
        child: BaseBlocWidget<ProfileBloc, ProfileEvent, ProfileState>(
          bloc: getIt<ProfileBloc>(),
          starterEvent: ProfileEvent.loadPublicProfile(widget.userId),
          builder: (context, state, bloc) {
            return state.when(
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
                final profile = viewModel.profile;
                return CustomScrollView(
                  slivers: [
                    // Profile Header Card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ProfileHeaderCard(
                          profile: profile,
                          isPublicProfile: true,
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
    );
  }

  void _showActions(BuildContext context) {
    showProfileActionsBottomSheet(
      context,
      userName: 'Пользователь',
      onBlock: () {},
      onReport: () {},
      onRestrict: () {},
      onCopyUrl: () {},
      onAbout: () {},
      onShare: () {},
    );
  }
}
