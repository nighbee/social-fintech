import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlHelper {
  static Future<bool> tryLaunchUrl({
    required String url,
    required BuildContext context,
    required String errorText,
  }) async {
    final uri = Uri.parse(url);
    final canLaunch = await canLaunchUrl(uri);

    if (canLaunch) {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        return true;
      }
    }

    if (!context.mounted) {
      return false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorText),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }

  static Future<bool> makePhoneCall({
    required String phoneNumber,
    required BuildContext context,
    required String errorText,
  }) async {
    final trimmedPhone = phoneNumber.trim();
    if (trimmedPhone.isEmpty) {
      return false;
    }

    return tryLaunchUrl(
      url: 'tel:$trimmedPhone',
      context: context,
      errorText: errorText,
    );
  }
}
