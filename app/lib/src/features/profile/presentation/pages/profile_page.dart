import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/base/base_bloc/bloc/base_bloc_widget.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: CustomAppBar(
        showLeading: false,
        actions: [Assets.icons.settingsIcon.svg(), Gap(16)],
      ),
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.profile),
      body: SafeArea(
        child: BaseBlocWidget<ProfileBloc, ProfileEvent, ProfileState>(
          bloc: getIt<ProfileBloc>(),
          starterEvent: const ProfileEvent.loadProfile(),
          builder: (context, state, bloc) {
            return state.when(
              initial: () => const Center(child: CircularProgressIndicator()),
              loading: (_) => const Center(child: CircularProgressIndicator()),
              loadingError: (message) => Center(child: Text(message)),
              loaded: (ProfileViewModel viewmodel) {
                final profile = viewmodel.profile;

                return CustomScrollView(
                  slivers: [
                    // Profile Header Card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ProfileHeaderCard(profile: profile),
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
}
