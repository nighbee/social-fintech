import 'package:app/src/core/base/base_bloc/bloc/base_bloc_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/features/auth/domain/entities/login_entity.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';

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
    // return const Center(child: Text("Profile Page"));
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: const CustomAppBar(showLeading: false),
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.profile),
      body: SafeArea(
        child: BaseBlocWidget<ProfileBloc, ProfileEvent, ProfileState>(
          bloc: getIt<ProfileBloc>(),
          starterEvent: ProfileEvent.loadProfile(),
          builder: (context, state, bloc) {
            return state.when(
              initial: () => const Center(child: CircularProgressIndicator()),
              loading: (_) => const Center(child: CircularProgressIndicator()),
              loaded: (ProfileViewModel viewmodel) {
                final user = viewmodel.user;

                return Center(
                  child: Column(children: [Gap(16), Text(user.id)]),
                );
              },
              loadingError: (message) => Center(child: Text(message)),
            );
          },
        ),
      ),
    );
  }
}
