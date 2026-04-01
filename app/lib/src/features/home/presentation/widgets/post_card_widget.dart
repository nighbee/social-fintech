import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_comments_bottom_sheet.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_silver_honor_bottom_sheet.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_report_bottom_sheet.dart';

class PostCardWidget extends StatelessWidget
    with
        ShowPostCommentsBottomSheet,
        ShowPostReportBottomSheet,
        ShowPostSilverHonorBottomSheet {
  final PostResponseEntity post;
  final VoidCallback? onReported;

  const PostCardWidget({super.key, required this.post, this.onReported});

  @override
  Widget build(BuildContext context) {
    final homeBloc = getIt<HomeBloc>();
    final imageUrls = post.mediaAttachments.map((item) => item.url).toList();
    final hasImages = imageUrls.isNotEmpty;
    final rankMeta = _resolveRankMeta(post.author.rank, post.author.rankSubLevel);
    final avatarUrl = post.author.profilePicUrl.trim().isNotEmpty
        ? post.author.profilePicUrl
        : '';
    final legacyPost = _toLegacyPost(post, imageUrls);

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PostAvatar(imageUrl: avatarUrl),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.author.username,
                            style: TextStyles.titleHeadline.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          post.timeAgo,
                          style: TextStyles.bodyMain.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const Gap(2),
                    Row(
                      children: [
                        Text(
                          rankMeta.label,
                          style: TextStyles.bodyMain.copyWith(
                            color: const Color(0xFF4E92CE),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Gap(4),
                        rankMeta.badge.image(width: 16, height: 16),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => showPostReportBottomSheet(
                  context,
                  bloc: homeBloc,
                  postId: post.postId,
                  authorId: post.author.id,
                  username: post.author.username,
                  onReported: onReported,
                ),
                child: Assets.icons.more.svg(width: 16, height: 16),
              ),
            ],
          ),
          const Gap(12),
          Text(
            post.contentText,
            style: TextStyles.bodyMain.copyWith(color: AppColors.textPrimary),
          ),
          if (hasImages) ...[
            const Gap(12),
            PostImageGrid(imageUrls: imageUrls),
          ],
          const Gap(12),
          Row(
            children: [
              PostLikeButton(
                postId: post.postId,
                isLiked: post.viewerHasLiked,
                count: post.metrics.likes,
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
                count: post.metrics.comments,
                onTap: () => showPostCommentsBottomSheet(
                  context,
                  post: legacyPost,
                ),
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
              PostSilverButton(
                bloc: homeBloc,
                postId: post.postId,
                initialCount: post.metrics.silvers,
                onTap: () => showPostSilverHonorBottomSheet(
                  context,
                  bloc: homeBloc,
                  post: post,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankMeta {
  const _RankMeta({required this.label, required this.badge});

  final String label;
  final AssetGenImage badge;
}

_RankMeta _resolveRankMeta(String rank, String rankSubLevel) {
  final normalizedRank = rank.trim();
  final normalizedSubLevel = rankSubLevel.trim();

  if (normalizedRank.isEmpty) {
    return _RankMeta(
      label: 'Moonstone • Intention • A',
      badge: Assets.images.moonstone,
    );
  }

  final rankKey = normalizedRank.toLowerCase();
  final badge = switch (rankKey) {
    'moonstone' => Assets.images.moonstone,
    'onyx' => Assets.images.onyx,
    'pearl' => Assets.images.pearl,
    'jade' => Assets.images.jade,
    'lapislazuli' => Assets.images.lapislazuli,
    'ammolite' => Assets.images.ammolite,
    'supernova' => Assets.images.supernova,
    _ => Assets.images.moonstone,
  };

  final labelParts = <String>[
    normalizedRank,
    if (normalizedSubLevel.isNotEmpty) normalizedSubLevel,
  ];
  if (labelParts.length == 1) {
    labelParts.add('A');
  }

  return _RankMeta(
    label: labelParts.join(' • '),
    badge: badge,
  );
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
            PostResponseEntity? currentPost;
            for (final item in viewModel.feed.items) {
              if (item.postId == postId) {
                currentPost = item;
                break;
              }
            }

            final currentlyLiked = currentPost?.viewerHasLiked ?? isLiked;
            final currentCount = currentPost?.metrics.likes ?? count;

            return InkWell(
              onTap: () {
                bloc.add(HomeEvent.togglePostLike(postId: postId));
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
              bloc.add(HomeEvent.togglePostLike(postId: postId));
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

class PostSilverButton extends StatelessWidget {
  const PostSilverButton({
    super.key,
    required this.bloc,
    required this.postId,
    required this.initialCount,
    required this.onTap,
  });

  final HomeBloc bloc;
  final String postId;
  final int initialCount;
  final VoidCallback onTap;

  int _resolveCurrentSilverCount(HomeViewModel viewModel) {
    for (final item in viewModel.feed.items.reversed) {
      if (item.postId == postId) {
        return item.metrics.silvers;
      }
    }
    return initialCount;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      bloc: bloc,
      builder: (context, state) {
        return state.maybeWhen(
          loading: (viewModel) {
            final currentCount = _resolveCurrentSilverCount(viewModel);
            return PostActionButton(
              icon: Assets.icons.silverCoin.svg(width: 24, height: 24),
              count: currentCount,
              onTap: onTap,
            );
          },
          loaded: (viewModel) {
            final currentCount = _resolveCurrentSilverCount(viewModel);
            return PostActionButton(
              icon: Assets.icons.silverCoin.svg(width: 24, height: 24),
              count: currentCount,
              onTap: onTap,
            );
          },
          orElse: () => PostActionButton(
            icon: Assets.icons.silverCoin.svg(width: 24, height: 24),
            count: initialCount,
            onTap: onTap,
          ),
        );
      },
    );
  }
}

PostEntity _toLegacyPost(PostResponseEntity post, List<String> imageUrls) {
  return PostEntity(
    id: post.postId,
    userId: post.author.id,
    username: post.author.username,
    userAvatar: post.author.profilePicUrl.trim().isNotEmpty
        ? post.author.profilePicUrl
        : null,
    content: post.contentText,
    imageUrls: imageUrls,
    likesCount: post.metrics.likes,
    commentsCount: post.metrics.comments,
    isLiked: post.viewerHasLiked,
    createdAt: DateTime.now(),
  );
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
