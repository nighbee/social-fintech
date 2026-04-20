import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/helpers/image_picker_helper.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/features/profile/domain/entities/profile_entity.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:app/src/features/profile/presentation/widgets/edit_profile/edit_profile_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  ProfileEntity _cachedProfile = const ProfileEntity.empty();

  @override
  void initState() {
    super.initState();
    _cacheProfile(getIt<ProfileBloc>().state);

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

  void _cacheProfile(ProfileState state) {
    final profile = state.maybeWhen(
      loading: (viewModel) => viewModel.profile,
      loaded: (viewModel) => viewModel.profile,
      orElse: () => null,
    );

    if (profile == null) {
      return;
    }

    if (profile.userId.isEmpty &&
        profile.displayName.isEmpty &&
        profile.bio.isEmpty &&
        profile.avatarUrl.isEmpty) {
      return;
    }

    _cachedProfile = profile;
  }

  ProfileEntity _resolveProfile(ProfileState state) {
    return state.maybeWhen(
      loading: (viewModel) => viewModel.profile,
      loaded: (viewModel) => viewModel.profile,
      orElse: () => _cachedProfile,
    );
  }

  bool _isProfileEmpty(ProfileEntity profile) {
    return profile.userId.isEmpty &&
        profile.displayName.isEmpty &&
        profile.bio.isEmpty &&
        profile.avatarUrl.isEmpty;
  }

  Future<void> _openNicknamePage(ProfileEntity profile) async {
    await context.pushNamed(
      RouteNames.editProfileNickname,
      extra: <String, dynamic>{
        'displayName': profile.displayName,
        'userId': profile.userId,
      },
    );
  }

  Future<void> _openBioPage(ProfileEntity profile) async {
    await context.pushNamed(
      RouteNames.editProfileBio,
      extra: <String, dynamic>{
        'bio': profile.bio,
      },
    );
  }

  Future<void> _openAvatarPicker() async {
    await ImagePickerHelper.showProfileImagePicker(
      context: context,
      onImageSelected: (bytes, fileName) {
        getIt<ProfileBloc>().add(
          ProfileEvent.updateProfilePhoto(bytes, fileName),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileBloc, ProfileState>(
      bloc: getIt<ProfileBloc>(),
      listener: (context, state) {
        _cacheProfile(state);
        state.whenOrNull(
          loadingError: (message) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          },
        );
      },
      builder: (context, state) {
        final profile = _resolveProfile(state);
        final isLoading = state.maybeWhen(
          loading: (_) => true,
          orElse: () => false,
        );

        if (_isProfileEmpty(profile) && isLoading) {
          return const Scaffold(
            backgroundColor: AppColors.colorff19191A,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_isProfileEmpty(profile)) {
          return const Scaffold(
            backgroundColor: AppColors.colorff19191A,
            appBar: EditProfileFlowAppBar(title: 'Edit Profile'),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.colorff19191A,
          appBar: const EditProfileFlowAppBar(
            title: 'Edit Profile',
            trailing: Icon(
              Icons.more_vert_rounded,
              size: 24,
              color: AppColors.textBrand,
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: _EditProfileBody(
                profile: profile,
                onChangePhotoTap: _openAvatarPicker,
                onNicknameTap: () => _openNicknamePage(profile),
                onBioTap: () => _openBioPage(profile),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EditProfileBody extends StatelessWidget {
  const _EditProfileBody({
    required this.profile,
    required this.onChangePhotoTap,
    required this.onNicknameTap,
    required this.onBioTap,
  });

  final ProfileEntity profile;
  final VoidCallback onChangePhotoTap;
  final VoidCallback onNicknameTap;
  final VoidCallback onBioTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: _EditProfilePhotoButton(
            avatarUrl: profile.avatarUrl,
            onTap: onChangePhotoTap,
          ),
        ),
        const Gap(28),
        const EditProfileSectionLabel(title: 'Nickname'),
        const Gap(12),
        EditProfileValueCardRow(
          value: profile.displayName,
          prefixAtSign: true,
          placeholder: '@Add nickname',
          onTap: onNicknameTap,
        ),
        const Gap(24),
        const EditProfileSectionLabel(title: 'Bio'),
        const Gap(12),
        EditProfileValueCardRow(
          value: profile.bio,
          placeholder: 'Add bio',
          onTap: onBioTap,
        ),
      ],
    );
  }
}

class _EditProfilePhotoButton extends StatelessWidget {
  const _EditProfilePhotoButton({
    required this.avatarUrl,
    required this.onTap,
  });

  final String avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final normalizedAvatarUrl = avatarUrl.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            children: [
              normalizedAvatarUrl.isNotEmpty
                  ? CustomNetworkImage(
                      imageUrl: normalizedAvatarUrl,
                      width: 146,
                      height: 146,
                      borderRadius: BorderRadius.circular(8),
                      errorIcon: Icons.person_outline,
                      errorIconSize: 36,
                    )
                  : Container(
                      width: 146,
                      height: 146,
                      decoration: BoxDecoration(
                        color: AppColors.colorff2A2A2B,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        size: 36,
                        color: AppColors.colorff9CA3AF,
                      ),
                    ),
              const Gap(12),
              Text(
                'Change photo',
                style: TextStyles.bodyLarge.copyWith(
                  color: AppColors.textBrand,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
