import 'dart:io';

import 'package:app/src/features/profile/domain/entities/profile.dart';
import 'package:app/src/features/profile/domain/entities/update_profile_params.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.profile});

  final Profile profile;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  File? _selectedImage;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.profile.effectiveDisplayName,
    );
    _bioController = TextEditingController(text: widget.profile.bio);
    _locationController = TextEditingController(text: widget.profile.location);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      if (_selectedImage != null) {
        context.read<ProfileBloc>().add(
          ProfileEvent.uploadAvatar(_selectedImage!),
        );
      }

      final params = UpdateProfileParams(
        displayName: _displayNameController.text,
        bio: _bioController.text,
        // location string needs to be parsed or just updated as city?
        // backend expects locationCity and locationCountry separate.
        // For now, let's assume simple string update is not fully supported by backend logic
        // or we need to split it?
        // The Request object has locationCity and locationCountry.
        // The UI shows "Location".
        // I will map input to locationCity for now for simplicity, or omit if complex.
        // Let's assume input is "City"
        locationCity: _locationController.text,
      );

      context.read<ProfileBloc>().add(ProfileEvent.updateProfile(params));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, state) {
        state.maybeWhen(
          loading: () => setState(() => _isLoading = true),
          loaded: (user) {
            setState(() => _isLoading = false);
            context.pop(); // Go back to profile on success
          },
          loadingError: (message) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $message')));
          },
          orElse: () {},
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: const Text('Save'),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: _selectedImage != null
                                  ? FileImage(_selectedImage!)
                                  : (widget.profile.avatarUrl != null &&
                                        widget.profile.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(widget.profile.avatarUrl!)
                                        as ImageProvider
                                  : null,
                              child:
                                  (_selectedImage == null &&
                                      (widget.profile.avatarUrl == null ||
                                          widget.profile.avatarUrl!.isEmpty))
                                  ? const Icon(Icons.person, size: 50)
                                  : null,
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(24),
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'Display Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const Gap(16),
                      TextFormField(
                        controller: _bioController,
                        decoration: const InputDecoration(
                          labelText: 'Bio',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const Gap(16),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
