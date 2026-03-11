import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ImagePickerHelper {
  static Future<void> showImagePicker({
    required BuildContext context,
    required Function(Uint8List bytes, String fileName) onImageSelected,
    int imageQuality = 80,
    double? maxWidth,
    double? maxHeight,
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

  static Future<void> showMediaPicker({
    required BuildContext context,
    required Function(Uint8List bytes, String fileName) onMediaSelected,
    int imageQuality = 80,
    double? maxWidth,
    double? maxHeight,
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
    double? maxWidth,
    double? maxHeight,
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
  ) async {
    try {
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        final bytes = await video.readAsBytes();
        onMediaSelected(bytes, video.name);
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
    }
  }
}
