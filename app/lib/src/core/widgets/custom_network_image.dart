import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CustomNetworkImage extends StatelessWidget {
  const CustomNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.cacheWidth,
    this.cacheHeight,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.network(
        _sanitizeUrl(imageUrl),
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: FilterQuality.low,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: AppColors.colorff2A2A2B,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: AppColors.colorff9CA3AF,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: AppColors.colorff2A2A2B,
            child: Icon(
              Icons.broken_image,
              color: AppColors.colorff9CA3AF,
              size: 32,
            ),
          );
        },
      ),
    );
  }

  String _sanitizeUrl(String url) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (url.contains('localhost')) {
        return url.replaceAll('localhost', '10.0.2.2');
      }
    }
    return url;
  }
}
