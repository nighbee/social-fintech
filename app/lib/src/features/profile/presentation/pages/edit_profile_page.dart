import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:app/src/features/profile/presentation/widgets/edit_profile/edit_profile_form.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

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
          'Edit Profile',
          style: TextStyles.titleMain.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        bloc: getIt<ProfileBloc>(),
        builder: (context, state) {
          return state.maybeWhen(
            loaded: (viewModel) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: EditProfileForm(profile: viewModel.profile),
                ),
              );
            },
            loading: (_) => const Center(child: CircularProgressIndicator()),
            loadingError: (message) => Center(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
            orElse: () => const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
