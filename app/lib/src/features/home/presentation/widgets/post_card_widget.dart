import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/feed_ink_well.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/core/widgets/media_viewer_page.dart';
import 'package:app/src/features/home/domain/entities/media_attachment_entity.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:app/src/features/home/domain/requests/feed_request.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/home/presentation/mixins/show_publication_owner_actions_bottom_sheet.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_comments_bottom_sheet.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_silver_honor_bottom_sheet.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_report_bottom_sheet.dart';

class PostCardWidget extends StatelessWidget
    with
        ShowPostCommentsBottomSheet,
        ShowPostReportBottomSheet,
        ShowPublicationOwnerActionsBottomSheet,
        ShowPostSilverHonorBottomSheet {
  final PostResponseEntity post;
  final HomeBloc bloc;
  final VoidCallback? onReported;
  final VoidCallback? onPostDeleted;
  final VoidCallback? onMoreTap;
  final VoidCallback? onAuthorTap;

  const PostCardWidget({
    super.key,
    required this.post,
    required this.bloc,
    this.onReported,
    this.onPostDeleted,
    this.onMoreTap,
    this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    final homeBloc = bloc;
    final mediaAttachments = post.mediaAttachments;
    final hasMedia = mediaAttachments.isNotEmpty;
    final imageUrls = mediaAttachments
        .where((item) => item.type.toLowerCase() == 'image')
        .map((item) => item.url)
        .toList(growable: false);
    final rankMeta =
        _resolveRankMeta(post.author.rank, post.author.rankSubLevel);
    final avatarUrl = post.author.profilePicUrl.trim().isNotEmpty
        ? post.author.profilePicUrl
        : '';
    final legacyPost = _toLegacyPost(post, imageUrls);
    final authorHeader = Row(
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
      ],
    );

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
              Expanded(
                child: onAuthorTap == null
                    ? authorHeader
                    : Material(
                        color: Colors.transparent,
                        child: FeedInkWell(
                          onTap: onAuthorTap!,
                          child: authorHeader,
                        ),
                      ),
              ),
              GestureDetector(
                onTap: () {
                  final customMoreTap = onMoreTap;
                  if (customMoreTap != null) {
                    customMoreTap();
                    return;
                  }
                  if (post.isOwnPost) {
                    showPublicationOwnerActionsBottomSheet(
                      context,
                      bloc: homeBloc,
                      post: post,
                      onPostDeleted: onPostDeleted ??
                          () => homeBloc.add(
                                const HomeEvent.loadFeed(
                                  request: FeedRequest(),
                                ),
                              ),
                      onPostUpdated: () => homeBloc.add(
                        const HomeEvent.loadFeed(
                          request: FeedRequest(),
                        ),
                      ),
                    );
                    return;
                  }
                  showPostReportBottomSheet(
                    context,
                    bloc: homeBloc,
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
            style: TextStyles.bodyMain.copyWith(color: AppColors.textPrimary),
          ),
          if (hasMedia) ...[
            const Gap(12),
            PostImageGrid(attachments: mediaAttachments),
          ],
          const Gap(12),
          Row(
            children: [
              PostLikeButton(
                bloc: homeBloc,
                postId: post.postId,
                isLiked: post.viewerHasLiked,
                count: post.metrics.likes,
                hideLikesCount: post.hideLikesCount,
                isOwnPost: post.isOwnPost,
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
                onTap: () => _sharePost(),
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

  Future<void> _sharePost() async {
    final author = post.author.username.trim().isNotEmpty
        ? '@${post.author.username.trim()}'
        : post.author.fullName.trim();
    final text = post.contentText.trim();
    final link = 'https://brightbund.app/post/${post.postId}';
    final message = [
      if (author.isNotEmpty) author,
      if (text.isNotEmpty) text,
      link,
    ].join('\n');

    await SharePlus.instance.share(
      ShareParams(text: message),
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
    final row = Row(
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
    );
    final tap = onTap;
    if (tap == null) {
      return row;
    }
    return FeedInkWell(onTap: tap, child: row);
  }
}

class PostLikeButton extends StatelessWidget {
  const PostLikeButton({
    super.key,
    required this.bloc,
    required this.postId,
    required this.isLiked,
    required this.count,
    required this.hideLikesCount,
    required this.isOwnPost,
  });

  final HomeBloc bloc;
  final String postId;
  final bool isLiked;
  final int count;
  final bool hideLikesCount;
  final bool isOwnPost;

  @override
  Widget build(BuildContext context) {
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
            final shouldShowCount =
                !(currentPost?.hideLikesCount ?? hideLikesCount) ||
                    (currentPost?.isOwnPost ?? isOwnPost);

            return FeedInkWell(
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
                  if (shouldShowCount) ...[
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
                ],
              ),
            );
          },
          orElse: () => FeedInkWell(
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

class PostImageGrid extends StatefulWidget {
  const PostImageGrid({
    super.key,
    required this.attachments,

    /// Edge-to-edge tiles inside the outer clip (e.g. publications / Figma-style block).
    this.flushInnerMedia = false,
  });

  final List<MediaAttachmentEntity> attachments;
  final bool flushInnerMedia;

  @override
  State<PostImageGrid> createState() => _PostImageGridState();
}

class _PostImageGridState extends State<PostImageGrid> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  @override
  void didUpdateWidget(covariant PostImageGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attachments.length != oldWidget.attachments.length &&
        _pageIndex >= widget.attachments.length) {
      _pageIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isVideo(MediaAttachmentEntity item) {
    return item.type.toLowerCase() == 'video';
  }

  BorderRadius get _innerRadius =>
      widget.flushInnerMedia ? BorderRadius.zero : BorderRadius.circular(8);

  Widget _mediaTile(
    MediaAttachmentEntity item, {
    required double height,
    double? width,
    required int index,
  }) {
    final inner = _innerRadius;
    if (_isVideo(item)) {
      return _InlineVideoTile(
        videoUrl: item.url.trim(),
        thumbnailUrl: item.thumbnailUrl.trim(),
        height: height,
        width: width,
        clipRadius: inner,
        onOpen: () => _openViewer(index),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openViewer(index),
      child: CustomNetworkImage(
        imageUrl: item.url,
        height: height,
        width: width,
        borderRadius: inner,
      ),
    );
  }

  void _openViewer(int index) {
    showMediaViewer(
      context,
      items: widget.attachments
          .map(
            (item) => MediaViewerItem(
              url: item.url.trim(),
              type: item.type,
              thumbnailUrl: item.thumbnailUrl.trim().isEmpty
                  ? null
                  : item.thumbnailUrl.trim(),
            ),
          )
          .toList(),
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final attachments = widget.attachments;
    if (attachments.length == 1) {
      final tile = _mediaTile(
        attachments[0],
        height: 240,
        width: double.infinity,
        index: 0,
      );
      if (widget.flushInnerMedia) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: tile,
        );
      }
      return tile;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: 240,
            child: PageView.builder(
              controller: _pageController,
              itemCount: attachments.length,
              onPageChanged: (index) {
                if (_pageIndex != index) {
                  setState(() => _pageIndex = index);
                }
              },
              itemBuilder: (context, index) {
                return _mediaTile(
                  attachments[index],
                  height: 240,
                  width: double.infinity,
                  index: index,
                );
              },
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_pageIndex + 1}/${attachments.length}',
                style: TextStyles.bodyMain.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineVideoTile extends StatefulWidget {
  const _InlineVideoTile({
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.height,
    this.width,
    this.clipRadius = const BorderRadius.all(Radius.circular(8)),
    required this.onOpen,
  });

  final String videoUrl;
  final String thumbnailUrl;
  final double height;
  final double? width;
  final BorderRadius clipRadius;
  final VoidCallback onOpen;

  @override
  State<_InlineVideoTile> createState() => _InlineVideoTileState();
}

class _InlineVideoTileState extends State<_InlineVideoTile> {
  VideoPlayerController? _controller;
  Object? _initError;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl.isNotEmpty) {
      _init();
    }
  }

  @override
  void didUpdateWidget(covariant _InlineVideoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _initError = null;
      if (widget.videoUrl.isNotEmpty) {
        _init();
      }
    }
  }

  Future<void> _init() async {
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = e);
    } finally {
      _isInitializing = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final r = widget.clipRadius;
    final thumbWidget = widget.thumbnailUrl.isNotEmpty
        ? CustomNetworkImage(
            imageUrl: widget.thumbnailUrl,
            height: widget.height,
            width: widget.width,
            borderRadius: r,
          )
        : Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFF121418),
              borderRadius: r,
            ),
          );

    final canShowVideo = controller != null && controller.value.isInitialized;

    return ClipRRect(
      borderRadius: r,
      child: Material(
        color: Colors.transparent,
        child: FeedInkWell(
          onTap: widget.onOpen,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (canShowVideo && controller.value.isPlaying)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    ),
                  )
                else
                  thumbWidget,
                if (_initError != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Text(
                      'Видео пока недоступно',
                      style:
                          TextStyles.bodyMain.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (!canShowVideo && _isInitializing)
                  const CircularProgressIndicator(
                    color: Colors.white54,
                    strokeWidth: 2,
                  ),
                if (_initError == null &&
                    (!canShowVideo || !controller.value.isPlaying))
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
