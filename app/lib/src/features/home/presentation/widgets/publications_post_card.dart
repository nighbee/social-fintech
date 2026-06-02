import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/feed_ink_well.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_comments_bottom_sheet.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_report_bottom_sheet.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_silver_honor_bottom_sheet.dart';
import 'package:app/src/features/home/presentation/mixins/show_publication_owner_actions_bottom_sheet.dart';
import 'package:app/src/features/home/presentation/widgets/post_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

PostResponseEntity _mergeFromMyPublicationsCache(
  HomeBloc bloc,
  PostResponseEntity anchor,
) {
  for (final p in bloc.myProfilePostsListCache.items) {
    if (p.postId == anchor.postId) {
      return p;
    }
  }
  return anchor;
}

List<String> _legacyImageUrls(PostResponseEntity post) {
  final urls = <String>[];
  for (final media in post.mediaAttachments) {
    final type = media.type.toLowerCase();
    if (type == 'video') {
      final thumb = media.thumbnailUrl.trim();
      final url = media.url.trim();
      if (thumb.isNotEmpty) {
        urls.add(thumb);
      } else if (url.isNotEmpty) {
        urls.add(url);
      }
    } else {
      final url = media.url.trim();
      if (url.isNotEmpty) {
        urls.add(url);
      }
    }
  }
  return urls;
}

PostEntity _toLegacyPost(PostResponseEntity post) {
  return PostEntity(
    id: post.postId,
    userId: post.author.id,
    username: post.author.username,
    userAvatar: post.author.profilePicUrl.trim().isNotEmpty
        ? post.author.profilePicUrl
        : null,
    content: post.contentText,
    imageUrls: _legacyImageUrls(post),
    likesCount: post.metrics.likes,
    commentsCount: post.metrics.comments,
    isLiked: post.viewerHasLiked,
    createdAt: DateTime.now(),
  );
}

class _PubRankMeta {
  const _PubRankMeta({required this.label, required this.badge});

  final String label;
  final AssetGenImage badge;
}

_PubRankMeta _pubResolveRankMeta(String rank, String rankSubLevel) {
  final normalizedRank = rank.trim();
  final normalizedSubLevel = rankSubLevel.trim();

  if (normalizedRank.isEmpty) {
    return _PubRankMeta(
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

  return _PubRankMeta(
    label: labelParts.join(' • '),
    badge: badge,
  );
}

/// Feed-style card for "My publications": Figma media layout + owner actions (delete / hide likes / comments).
class PublicationsPostCard extends StatelessWidget
    with
        ShowPostCommentsBottomSheet,
        ShowPostReportBottomSheet,
        ShowPostSilverHonorBottomSheet,
        ShowPublicationOwnerActionsBottomSheet {
  const PublicationsPostCard({
    super.key,
    required this.anchorPost,
    required this.bloc,
    required this.onPostDeleted,
    this.isOwnerMode = true,
    this.onReported,
  });

  final PostResponseEntity anchorPost;
  final HomeBloc bloc;
  final VoidCallback onPostDeleted;
  final bool isOwnerMode;
  final VoidCallback? onReported;

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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      bloc: bloc,
      builder: (context, state) {
        final post = isOwnerMode
            ? _mergeFromMyPublicationsCache(bloc, anchorPost)
            : anchorPost;
        final rankMeta =
            _pubResolveRankMeta(post.author.rank, post.author.rankSubLevel);
        final avatarUrl = post.author.profilePicUrl.trim().isNotEmpty
            ? post.author.profilePicUrl
            : '';
        final hasMedia = post.mediaAttachments.isNotEmpty;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PubAvatar(imageUrl: avatarUrl),
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
                    onTap: () {
                      if (isOwnerMode) {
                        showPublicationOwnerActionsBottomSheet(
                          context,
                          bloc: bloc,
                          post: post,
                          onPostDeleted: onPostDeleted,
                        );
                        return;
                      }
                      showPostReportBottomSheet(
                        context,
                        bloc: bloc,
                        postId: post.postId,
                        authorId: post.author.id,
                        username: post.author.username,
                        onReported: onReported,
                      );
                    },
                    child: Assets.icons.more.svg(width: 16, height: 16),
                  ),
                ],
              ),
              const Gap(12),
              Text(
                post.contentText,
                style:
                    TextStyles.bodyMain.copyWith(color: AppColors.textPrimary),
              ),
              if (hasMedia) ...[
                const Gap(12),
                PostImageGrid(
                  attachments: post.mediaAttachments,
                  flushInnerMedia: true,
                ),
              ],
              const Gap(12),
              Row(
                children: [
                  FeedInkWell(
                    onTap: () {
                      bloc.add(HomeEvent.togglePostLike(postId: post.postId));
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.string(
                          post.viewerHasLiked
                              ? _filledLikeIcon
                              : _outlineLikeIcon,
                          width: 18,
                          height: 18,
                          colorFilter: ColorFilter.mode(
                            post.viewerHasLiked
                                ? const Color(0xFFF38AA1)
                                : AppColors.textPrimary,
                            BlendMode.srcIn,
                          ),
                        ),
                        if (!post.hideLikesCount) ...[
                          const Gap(4),
                          Text(
                            post.metrics.likes.toString(),
                            style: TextStyles.bodyMain.copyWith(
                              color: post.viewerHasLiked
                                  ? const Color(0xFFF38AA1)
                                  : AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Gap(16),
                  PostActionButton(
                    icon: Assets.icons.message.svg(
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(
                        post.permissions.canComment
                            ? AppColors.textPrimary
                            : AppColors.textSecondary.withValues(alpha: 0.45),
                        BlendMode.srcIn,
                      ),
                    ),
                    count: post.metrics.comments,
                    onTap: post.permissions.canComment
                        ? () => showPostCommentsBottomSheet(
                              context,
                              post: _toLegacyPost(post),
                            )
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Comments are turned off for this post.'),
                              ),
                            );
                          },
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
                    count: post.metrics.silvers,
                    onTap: () => showPostSilverHonorBottomSheet(
                      context,
                      bloc: bloc,
                      post: post,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PubAvatar extends StatelessWidget {
  const _PubAvatar({required this.imageUrl});

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
