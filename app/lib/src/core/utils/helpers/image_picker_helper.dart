import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ImagePickerHelper {
  static Future<void> showImagePicker({
    required BuildContext context,
    required Function(Uint8List bytes, String fileName) onImageSelected,
    int imageQuality = 80,
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
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        onImageSelected(bytes, image.name);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }
}
