import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ProfilePostGrid extends StatelessWidget {
  const ProfilePostGrid({required this.posts, super.key});

  final List<PostEntity> posts;

  @override
  Widget build(BuildContext context) {
    final mediaPosts = posts
        .where((post) => post.imageUrls.isNotEmpty)
        .toList(growable: false);
    final textPosts = posts
        .where(
          (post) => post.imageUrls.isEmpty && post.content.trim().isNotEmpty,
        )
        .toList(growable: false);

    if (mediaPosts.isEmpty && textPosts.isEmpty) {
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

    return SliverMainAxisGroup(
      slivers: [
        if (mediaPosts.isNotEmpty)
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final post = mediaPosts[index];
              return CustomNetworkImage(
                imageUrl: post.imageUrls.first,
                fit: BoxFit.cover,
              );
            }, childCount: mediaPosts.length),
          ),
        if (textPosts.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                mediaPosts.isNotEmpty ? 18 : 8,
                16,
                0,
              ),
              child: Text(
                'Text Posts',
                style: TextStyles.titleHeadline.copyWith(color: Colors.white),
              ),
            ),
          ),
        if (textPosts.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final post = textPosts[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == textPosts.length - 1 ? 0 : 12,
                  ),
                  child: _ProfileTextPostCard(post: post),
                );
              }, childCount: textPosts.length),
            ),
          ),
      ],
    );
  }
}

class _ProfileTextPostCard extends StatelessWidget {
  const _ProfileTextPostCard({required this.post});

  final PostEntity post;

  @override
  Widget build(BuildContext context) {
    final createdAt = post.createdAt.toLocal();
    final dateLabel =
        '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.username,
                  style: TextStyles.titleTag.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                dateLabel,
                style: TextStyles.bodySecondary.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Gap(10),
          Text(
            post.content.trim(),
            style: TextStyles.bodyMain.copyWith(
              color: Colors.white,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
