import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/features/profile/presentation/models/profile_post_item.dart';
import 'package:flutter/material.dart';

class ProfilePostGrid extends StatelessWidget {
  const ProfilePostGrid({
    required this.posts,
    super.key,
    this.onTapPost,
  });

  final List<ProfilePostItem> posts;
  final ValueChanged<ProfilePostItem>? onTapPost;

  @override
  Widget build(BuildContext context) {
    // Show empty state if no posts
    if (posts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Assets.icons.images.svg(
                width: 120,
                height: 120,
                colorFilter: const ColorFilter.mode(
                  Color(0xFFCACACA),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No posts yet',
                style: TextStyles.titleMain.copyWith(
                  color: const Color(0xFFCACACA),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1, // Square images
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final post = posts[index];
        final imageUrl = post.imageUrls.isNotEmpty ? post.imageUrls.first : '';

        return GestureDetector(
          onTap: onTapPost == null ? null : () => onTapPost!(post),
          child: imageUrl.isEmpty
              ? Container(
                  color: AppColors.colorff2A2A2B,
                  alignment: Alignment.center,
                  child: Assets.icons.images.svg(
                    width: 28,
                    height: 28,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFFCACACA),
                      BlendMode.srcIn,
                    ),
                  ),
                )
              : CustomNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
        );
      }, childCount: posts.length),
    );
  }
}
