import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostCardWidget extends StatelessWidget {
  final PostEntity post;

  const PostCardWidget({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: User info and menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomNetworkImage(
                imageUrl: post.imageUrls.first,
                width: 40,
                height: 40,
                borderRadius: BorderRadius.circular(4),
              ),

              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.username,
                      style: context.theme.textStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      timeago.format(post.createdAt),
                      style: context.theme.textStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Assets.icons.more.svg(width: 16, height: 16),
              ),
            ],
          ),
          const Gap(12),
          // Content
          Text(
            post.content,
            style: context.theme.textStyles.caption.copyWith(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          if (post.imageUrls.isNotEmpty) ...[
            const Gap(12),
            PostImageGrid(imageUrls: post.imageUrls),
          ],
          const Gap(12),
          // Actions: Like, Comment, Share
          Row(
            children: [
              PostActionButton(
                icon: Assets.icons.like.svg(width: 20, height: 20),
                count: post.likesCount,
              ),
              const Gap(16),
              PostActionButton(
                icon: Assets.icons.message.svg(width: 20, height: 20),
                count: post.commentsCount,
              ),
              const Gap(16),
              GestureDetector(
                onTap: () {},
                child: Assets.icons.share.svg(width: 20, height: 20),
              ),
              const Spacer(),
              PostActionButton(
                icon: Assets.icons.silverCoin.svg(width: 25, height: 25),
                count: 45,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PostActionButton extends StatelessWidget {
  final Widget icon;
  final int count;

  const PostActionButton({super.key, required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const Gap(4),
          Text(
            count.toString(),
            style: context.theme.textStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class PostImageGrid extends StatelessWidget {
  final List<String> imageUrls;

  const PostImageGrid({super.key, required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    if (imageUrls.length == 1) {
      return CustomNetworkImage(
        imageUrl: imageUrls[0],
        height: 200,
        width: double.infinity,
        borderRadius: BorderRadius.circular(8),
      );
    } else if (imageUrls.length == 2) {
      return Row(
        children: [
          Expanded(
            child: CustomNetworkImage(
              imageUrl: imageUrls[0],
              height: 150,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const Gap(8),
          Expanded(
            child: CustomNetworkImage(
              imageUrl: imageUrls[1],
              height: 150,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      );
    } else {
      // 3 or more images
      return Column(
        children: [
          CustomNetworkImage(
            imageUrl: imageUrls[0],
            height: 200,
            width: double.infinity,
            borderRadius: BorderRadius.circular(8),
          ),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: CustomNetworkImage(
                  imageUrl: imageUrls[1],
                  height: 100,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const Gap(8),
              Expanded(
                child: CustomNetworkImage(
                  imageUrl: imageUrls[2],
                  height: 100,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }
}
