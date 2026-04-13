import 'dart:typed_data';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/glass_container.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ImagePickerHelper {
  static Future<void> showImagePicker({
    required BuildContext context,
    required Function(Uint8List bytes, String fileName) onImageSelected,
    int imageQuality = 80,
    double? maxWidth = 1280,
    double? maxHeight = 1280,
  }) async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take a photo'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImage(
                      picker,
                      ImageSource.camera,
                      onImageSelected,
                      imageQuality,
                      maxWidth,
                      maxHeight,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImage(
                      picker,
                      ImageSource.gallery,
                      onImageSelected,
                      imageQuality,
                      maxWidth,
                      maxHeight,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> showProfileImagePicker({
    required BuildContext context,
    required Function(Uint8List bytes, String fileName) onImageSelected,
    int imageQuality = 80,
    double? maxWidth = 1280,
    double? maxHeight = 1280,
  }) async {
    final ImagePicker picker = ImagePicker();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: _ProfileImagePickerSheet(
            onCameraTap: () async {
              Navigator.of(sheetContext).pop();
              await _pickImage(
                picker,
                ImageSource.camera,
                onImageSelected,
                imageQuality,
                maxWidth,
                maxHeight,
              );
            },
            onGalleryTap: () async {
              Navigator.of(sheetContext).pop();
              await _pickImage(
                picker,
                ImageSource.gallery,
                onImageSelected,
                imageQuality,
                maxWidth,
                maxHeight,
              );
            },
          ),
        );
      },
    );
  }

  static Future<void> showMediaPicker({
    required BuildContext context,
    required Function(Uint8List bytes, String fileName) onMediaSelected,
    Function(String message)? onError,
    int imageQuality = 80,
    double? maxWidth = 1280,
    double? maxHeight = 1280,
  }) async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take a photo'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImage(
                      picker,
                      ImageSource.camera,
                      onMediaSelected,
                      imageQuality,
                      maxWidth,
                      maxHeight,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose photo from gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImage(
                      picker,
                      ImageSource.gallery,
                      onMediaSelected,
                      imageQuality,
                      maxWidth,
                      maxHeight,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.video_library),
                  title: const Text('Choose video from gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickVideo(
                      picker,
                      onMediaSelected,
                      onError: onError,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> showImagePickerFile({
    required BuildContext context,
    required Function(XFile file) onImageSelected,
    int imageQuality = 80,
    double? maxWidth = 1280,
    double? maxHeight = 1280,
  }) async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take a photo'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImageFile(
                      picker,
                      ImageSource.camera,
                      onImageSelected,
                      imageQuality,
                      maxWidth,
                      maxHeight,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImageFile(
                      picker,
                      ImageSource.gallery,
                      onImageSelected,
                      imageQuality,
                      maxWidth,
                      maxHeight,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _pickImage(
    ImagePicker picker,
    ImageSource source,
    Function(Uint8List bytes, String fileName) onImageSelected,
    int imageQuality,
    double? maxWidth,
    double? maxHeight,
  ) async {
    try {
      final PermissionStatus status;
      if (source == ImageSource.camera) {
        status = await Permission.camera.request();
      } else {
        // For gallery, permission handling might vary by Android version
        // simplistic approach for now
        status = PermissionStatus.granted;
      }

      if (source == ImageSource.camera && !status.isGranted) {
        return;
      }

      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        onImageSelected(bytes, image.name);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  static Future<void> _pickImageFile(
    ImagePicker picker,
    ImageSource source,
    Function(XFile file) onImageSelected,
    int imageQuality,
    double? maxWidth,
    double? maxHeight,
  ) async {
    try {
      final PermissionStatus status;
      if (source == ImageSource.camera) {
        status = await Permission.camera.request();
      } else {
        status = PermissionStatus.granted;
      }

      if (source == ImageSource.camera && !status.isGranted) {
        return;
      }

      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      if (image != null) {
        onImageSelected(image);
      }
    } catch (e) {
      debugPrint('Error picking image file: $e');
    }
  }

  static Future<void> _pickVideo(
    ImagePicker picker,
    Function(Uint8List bytes, String fileName) onMediaSelected,
    {
    Function(String message)? onError,
  }
  ) async {
    try {
      final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );
      if (video != null) {
        final bytes = await video.readAsBytes();
        onMediaSelected(bytes, video.name);
      } else {
        onError?.call('Video was not selected. Max duration is 2 minutes.');
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
      onError?.call('Failed to pick video. Please try again.');
    }
  }
}

class _ProfileImagePickerSheet extends StatelessWidget {
  const _ProfileImagePickerSheet({
    required this.onCameraTap,
    required this.onGalleryTap,
  });

  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GlassContainer(
        borderRadius: 12,
        blurSigma: 28,
        backgroundColor: AppColors.colorff202020.withValues(alpha: 0.72),
        borderColor: Colors.white.withValues(alpha: 0.08),
        borderWidth: 1,
        enableWhiteGlow: false,
        dropShadowColor: Colors.black.withValues(alpha: 0.48),
        dropShadowBlurRadius: 32,
        dropShadowOffset: const Offset(0, 4),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFA3ADB6),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              const SizedBox(height: 18),
              _ProfileImagePickerActionRow(
                icon: Icons.camera_alt_outlined,
                label: 'Take a photo',
                onTap: onCameraTap,
              ),
              const SizedBox(height: 12),
              _ProfileImagePickerActionRow(
                icon: Icons.photo_library_outlined,
                label: 'Upload photo',
                onTap: onGalleryTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileImagePickerActionRow extends StatelessWidget {
  const _ProfileImagePickerActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: AppColors.textBrand,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyles.bodyLarge.copyWith(
                    fontSize: 18,
                    height: 1,
                    color: AppColors.textBrand,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
