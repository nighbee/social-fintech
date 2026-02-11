import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/features/profile/domain/entities/profile_entity.dart';
import 'package:app/src/features/profile/domain/requests/update_profile_request.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:app/src/features/profile/presentation/widgets/edit_profile/profile_avatar_picker.dart';
import 'package:app/src/features/profile/presentation/widgets/edit_profile/profile_text_field.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class EditProfileForm extends StatefulWidget {
  const EditProfileForm({super.key, required this.profile});

  final ProfileEntity profile;

  @override
  State<EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<EditProfileForm> {
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _cityController;
  late TextEditingController _countryController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.profile.displayName,
    );
    _bioController = TextEditingController(text: widget.profile.bio);
    _cityController = TextEditingController(text: widget.profile.city);
    _countryController = TextEditingController(text: widget.profile.country);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _onSave() {
    final bloc = getIt<ProfileBloc>();
    final request = UpdateProfileRequest(
      displayName: _displayNameController.text,
      bio: _bioController.text,
      city: _cityController.text,
      country: _countryController.text,
    );
    bloc.add(ProfileEvent.updateProfile(request));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ProfileAvatarPicker(
          imageUrl: widget.profile.avatarUrl,
          onPickImage: () {
            // TODO: Implement image picker
          },
        ),
        const Gap(24),
        ProfileTextField(
          label: 'Display Name',
          controller: _displayNameController,
        ),
        const Gap(16),
        ProfileTextField(label: 'Bio', controller: _bioController, maxLines: 3),
        const Gap(16),
        ProfileTextField(label: 'City', controller: _cityController),
        const Gap(16),
        ProfileTextField(label: 'Country', controller: _countryController),
        const Gap(32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C9EFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Save Changes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
