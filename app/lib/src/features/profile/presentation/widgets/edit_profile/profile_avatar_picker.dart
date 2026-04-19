import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/helpers/image_picker_helper.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:flutter/material.dart';

class ProfileAvatarPicker extends StatelessWidget {
  const ProfileAvatarPicker({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl.trim();

    return Center(
      child: Stack(
        children: [
          normalizedUrl.isNotEmpty
              ? CustomNetworkImage(
                  imageUrl: normalizedUrl,
                  width: 100,
                  height: 100,
                  borderRadius: BorderRadius.circular(50),
                )
              : Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: AppColors.colorff2A2A2B,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 36,
                    color: AppColors.colorff9CA3AF,
                  ),
                ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () {
                ImagePickerHelper.showImagePicker(
                  context: context,
                  onImageSelected: (bytes, fileName) {
                    getIt<ProfileBloc>().add(
                      ProfileEvent.updateProfilePhoto(bytes, fileName),
                    );
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF6C9EFF), // Brand color
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
