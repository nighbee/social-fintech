import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_comments_bottom_sheet.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_report_bottom_sheet.dart';
import 'package:app/src/features/home/presentation/mixins/show_silver_honor_flow_bottom_sheet.dart';

class PostCardWidget extends StatelessWidget
    with
        ShowPostCommentsBottomSheet,
        ShowPostReportBottomSheet,
        ShowSilverHonorBottomSheet {
  final PostEntity post;

  const PostCardWidget({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final hasImages = post.imageUrls.isNotEmpty;
    final avatarUrl =
        post.userAvatar ?? (hasImages ? post.imageUrls.first : '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.feedMoonstoneBase,
        gradient: const RadialGradient(
          center: Alignment(-1.84, -1.0),
          radius: 2.6,
          stops: <double>[0.0, 0.2404, 0.4423, 0.6683, 0.899],
          colors: AppColors.feedMoonstoneGradient,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.feedMoonstoneBorder,
          width: 1,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: User info and menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PostAvatar(imageUrl: avatarUrl),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.username,
                      style: TextStyles.titleHeadline.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      timeago.format(post.createdAt),
                      style: TextStyles.bodySecondary.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => showPostReportBottomSheet(
                  context,
                  username: post.username,
                ),
                child: Assets.icons.more.svg(width: 16, height: 16),
              ),
            ],
          ),
          const Gap(12),
          // Content
          Text(
            post.content,
            style: TextStyles.bodyMain.copyWith(color: AppColors.textPrimary),
          ),
          if (hasImages) ...[
            const Gap(12),
            PostImageGrid(imageUrls: post.imageUrls),
          ],
          const Gap(12),
          // Actions: Like, Comment, Share
          Row(
            children: [
              PostLikeButton(
                postId: post.id,
                isLiked: post.isLiked,
                count: post.likesCount,
              ),
              const Gap(16),
              PostActionButton(
                icon: Assets.icons.message.svg(
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textPrimary,
                    BlendMode.srcIn,
                  ),
                ),
                count: post.commentsCount,
                onTap: () => showPostCommentsBottomSheet(context, post: post),
              ),
              const Gap(16),
              PostActionButton(
                icon: Assets.icons.share.svg(
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textPrimary,
                    BlendMode.srcIn,
                  ),
                ),
                onTap: () {},
              ),
              const Spacer(),
              PostActionButton(
                icon: Assets.icons.silverCoin.svg(width: 24, height: 24),
                count: 45,
                onTap: () => showSilverHonorBottomSheet(context, post: post),
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
  final int? count;
  final VoidCallback? onTap;

  const PostActionButton({
    super.key,
    required this.icon,
    this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          if (count != null) ...[
            const Gap(4),
            Text(
              count.toString(),
              style: TextStyles.bodyMain.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PostLikeButton extends StatelessWidget {
  const PostLikeButton({
    super.key,
    required this.postId,
    required this.isLiked,
    required this.count,
  });

  final String postId;
  final bool isLiked;
  final int count;

  @override
  Widget build(BuildContext context) {
    final bloc = getIt<HomeBloc>();

    return BlocBuilder<HomeBloc, HomeState>(
      bloc: bloc,
      builder: (context, state) {
        return state.maybeWhen(
          loaded: (viewModel) {
            // Get the most up-to-date post from state
            final currentPost = viewModel.posts.firstWhere(
              (p) => p.id == postId,
              orElse: () => PostEntity(
                id: postId,
                userId: '',
                username: '',
                content: '',
                createdAt: DateTime.now(),
                isLiked: isLiked,
                likesCount: count,
                commentsCount: 0,
              ),
            );

            final currentlyLiked = currentPost.isLiked;
            final currentCount = currentPost.likesCount;

            return InkWell(
              onTap: () {
                if (currentlyLiked) {
                  bloc.add(HomeEvent.unlikePost(postId));
                } else {
                  bloc.add(HomeEvent.likePost(postId));
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.string(
                    currentlyLiked ? _filledLikeIcon : _outlineLikeIcon,
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(
                      currentlyLiked
                          ? const Color(0xFFF38AA1)
                          : AppColors.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    currentCount.toString(),
                    style: TextStyles.bodyMain.copyWith(
                      color: currentlyLiked
                          ? const Color(0xFFF38AA1)
                          : AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
          orElse: () => InkWell(
            onTap: () {
              bloc.add(HomeEvent.likePost(postId));
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.string(
                  _outlineLikeIcon,
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textPrimary,
                    BlendMode.srcIn,
                  ),
                ),
                const Gap(4),
                Text(
                  count.toString(),
                  style: TextStyles.bodyMain.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static const String _outlineLikeIcon = '''
<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
  <path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z" />
</svg>
''';

  static const String _filledLikeIcon = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
  <path d="M11.645 20.91l-.007-.003-.022-.012a15.247 15.247 0 01-.383-.218 25.18 25.18 0 01-4.244-3.17C4.688 15.36 2.25 12.174 2.25 8.25 2.25 5.322 4.714 3 7.688 3A5.5 5.5 0 0112 5.052 5.5 5.5 0 0116.313 3c2.973 0 5.437 2.322 5.437 5.25 0 3.925-2.438 7.111-4.739 9.256a25.175 25.175 0 01-4.244 3.17 15.247 15.247 0 01-.383.219l-.022.012-.007.004-.003.001a.752.752 0 01-.704 0l-.003-.001z" />
</svg>
''';
}

class _PostAvatar extends StatelessWidget {
  const _PostAvatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = imageUrl.trim().isNotEmpty;
    if (hasAvatar) {
      return CustomNetworkImage(
        imageUrl: imageUrl,
        width: 36,
        height: 36,
        borderRadius: BorderRadius.circular(6),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF363639),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.person_outline,
        size: 20,
        color: AppColors.textSecondary,
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
