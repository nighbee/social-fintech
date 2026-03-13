import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/features/home/domain/entities/media_attachment_entity.dart';
import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_comments_bottom_sheet.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_report_feedback_bottom_sheet.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_report_bottom_sheet.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_silver_honor_bottom_sheet.dart';
import 'package:app/src/features/home/presentation/widgets/reported_post_card_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

class PostCardWidget extends StatefulWidget {
  const PostCardWidget({super.key, required this.post});

  final PostResponseEntity post;

  @override
  State<PostCardWidget> createState() => _PostCardWidgetState();
}

class _PostCardWidgetState extends State<PostCardWidget>
    with
        ShowPostCommentsBottomSheet,
        ShowPostReportFeedbackBottomSheet,
        ShowPostReportBottomSheet,
        ShowPostSilverHonorBottomSheet {
  bool _showReportedPostCard = false;

  void _onReportSubmitted(PostReportReason _) {}

  @override
  Widget build(BuildContext context) {
    if (_showReportedPostCard) {
      return ReportedPostCardWidget(
        onClose: () {
          setState(() {
            _showReportedPostCard = false;
          });
        },
      );
    }

    final bloc = getIt<HomeBloc>();

    return BlocBuilder<HomeBloc, HomeState>(
      bloc: bloc,
      builder: (context, state) {
        final viewModel = state.maybeWhen(
          loading: (viewModel) => viewModel,
          loaded: (viewModel) => viewModel,
          orElse: HomeViewModel.new,
        );
        final currentPost = viewModel.feed.items.firstWhere(
          (item) => item.postId == widget.post.postId,
          orElse: () => widget.post,
        );

        final mediaItems = currentPost.mediaAttachments;
        final localMediaMap = <String, Uint8List>{
          for (final payload in viewModel.localMediaPayloads)
            payload.localUrl: payload.bytes,
        };
        final hasMedia = mediaItems.isNotEmpty;
        final hasContent = currentPost.contentText.trim().isNotEmpty;
        final authorName = currentPost.author.username.trim().isNotEmpty
            ? currentPost.author.username
            : currentPost.author.fullName;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.colorff2A2A2B,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.colorff3F3F40, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserAvatar(currentPost.author.profilePicUrl),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: TextStyles.titleHeadline.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.colorffE5E5E5,
                          ),
                        ),
                        Text(
                          currentPost.timeAgo.isNotEmpty
                              ? currentPost.timeAgo
                              : 'now',
                          style: TextStyles.bodySecondary.copyWith(
                            color: AppColors.colorff9CA3AF,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => showPostReportBottomSheet(
                      context,
                      onSubmitted: _onReportSubmitted,
                      reportTargetName:
                          authorName.isNotEmpty ? authorName : 'User',
                      onFeedbackDone: () {
                        if (!mounted) return;
                        setState(() {
                          _showReportedPostCard = true;
                        });
                      },
                    ),
                    child: Assets.icons.more.svg(width: 16, height: 16),
                  ),
                ],
              ),
              if (hasContent) ...[
                const Gap(12),
                Text(
                  currentPost.contentText,
                  style: TextStyles.bodyMain.copyWith(
                    color: AppColors.colorffE5E5E5,
                  ),
                ),
              ],
              if (hasMedia) ...[
                const Gap(12),
                _PostMediaGrid(
                  mediaItems: mediaItems,
                  localMap: localMediaMap,
                ),
              ],
              const Gap(12),
              Row(
                children: [
                  InkWell(
                    onTap: () => bloc.add(
                      HomeEvent.togglePostLike(postId: currentPost.postId),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.string(
                          currentPost.viewerHasLiked
                              ? _filledLikeIcon
                              : _outlineLikeIcon,
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            currentPost.viewerHasLiked
                                ? Colors.red
                                : AppColors.colorffE5E5E5,
                            BlendMode.srcIn,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          currentPost.metrics.likes.toString(),
                          style: TextStyles.bodyMain.copyWith(
                            color: currentPost.viewerHasLiked
                                ? Colors.red
                                : AppColors.colorffE5E5E5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(16),
                  PostActionButton(
                    icon: Assets.icons.message.svg(width: 20, height: 20),
                    count: currentPost.metrics.comments,
                    onTap: () => showPostCommentsBottomSheet(
                      context,
                      bloc: bloc,
                      post: currentPost,
                    ),
                  ),
                  const Gap(16),
                  PostActionButton(
                    icon: Assets.icons.share.svg(width: 20, height: 20),
                    count: currentPost.metrics.shares,
                    onTap: () {},
                  ),
                  const Spacer(),
                  PostActionButton(
                    icon: Assets.icons.silverCoin.svg(width: 25, height: 25),
                    count: currentPost.metrics.silvers,
                    onTap: () => showPostSilverHonorBottomSheet(
                      context,
                      bloc: bloc,
                      post: currentPost,
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

class PostActionButton extends StatelessWidget {
  const PostActionButton({
    super.key,
    required this.icon,
    required this.count,
    this.onTap,
  });

  final Widget icon;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const Gap(4),
          Text(
            count.toString(),
            style: TextStyles.bodyMain.copyWith(color: AppColors.colorffE5E5E5),
          ),
        ],
      ),
    );
  }
}

Widget _buildUserAvatar(String rawUrl) {
  final safeUrl = _sanitizeUrl(rawUrl.trim());
  if (safeUrl.isEmpty) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.colorff3F3F40,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, size: 20, color: Colors.white70),
    );
  }

  return CustomNetworkImage(
    imageUrl: safeUrl,
    width: 40,
    height: 40,
    borderRadius: BorderRadius.circular(20),
  );
}

Widget _buildMediaThumb(
  Map<String, Uint8List> localMap,
  String type,
  String rawUrl,
  String? rawThumbnailUrl,
  double width,
  double height,
) {
  final safeUrl = _sanitizeUrl(rawUrl);
  final safeThumb = _sanitizeUrl((rawThumbnailUrl ?? '').trim());
  final localBytes = _resolveLocalBytes(localMap, rawUrl, safeUrl);
  final isVideo = type.toLowerCase() == 'video';

  if (isVideo) {
    if (safeThumb.isNotEmpty) {
      return Stack(
        children: [
          CustomNetworkImage(
            imageUrl: safeThumb,
            width: width,
            height: height,
            borderRadius: BorderRadius.circular(8),
          ),
          Positioned.fill(
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.colorff2A2A2B,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.colorff3F3F40),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
          Gap(4),
          Text(
            'Video',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  if (localBytes != null) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        localBytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
      ),
    );
  }

  if (rawUrl.startsWith('local-media://')) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.colorff2A2A2B,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.broken_image,
        color: Colors.white54,
      ),
    );
  }

  return CustomNetworkImage(
    imageUrl: safeUrl,
    width: width,
    height: height,
    borderRadius: BorderRadius.circular(8),
  );
}

class _PostMediaGrid extends StatelessWidget {
  const _PostMediaGrid({
    required this.mediaItems,
    required this.localMap,
  });

  final List<MediaAttachmentEntity> mediaItems;
  final Map<String, Uint8List> localMap;

  @override
  Widget build(BuildContext context) {
    if (mediaItems.length == 1) {
      final item = mediaItems[0];
      return _buildMediaThumb(
        localMap,
        item.type,
        item.url,
        item.thumbnailUrl,
        double.infinity,
        200,
      );
    }
    if (mediaItems.length == 2) {
      final first = mediaItems[0];
      final second = mediaItems[1];
      return Row(
        children: [
          Expanded(
            child: _buildMediaThumb(
              localMap,
              first.type,
              first.url,
              first.thumbnailUrl,
              double.infinity,
              150,
            ),
          ),
          const Gap(8),
          Expanded(
            child: _buildMediaThumb(
              localMap,
              second.type,
              second.url,
              second.thumbnailUrl,
              double.infinity,
              150,
            ),
          ),
        ],
      );
    }

    final first = mediaItems[0];
    final second = mediaItems[1];
    final third = mediaItems[2];
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildMediaThumb(
            localMap,
            first.type,
            first.url,
            first.thumbnailUrl,
            double.infinity,
            200,
          ),
        ),
        const Gap(8),
        Expanded(
          child: Column(
            children: [
              _buildMediaThumb(
                localMap,
                second.type,
                second.url,
                second.thumbnailUrl,
                double.infinity,
                96,
              ),
              const Gap(8),
              Stack(
                children: [
                  _buildMediaThumb(
                    localMap,
                    third.type,
                    third.url,
                    third.thumbnailUrl,
                    double.infinity,
                    96,
                  ),
                  if (mediaItems.length > 3)
                    Positioned.fill(
                      child: Container(
                        alignment: Alignment.center,
                        color: Colors.black45,
                        child: Text(
                          '+${mediaItems.length - 3}',
                          style: TextStyles.titleHeadline.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _sanitizeUrl(String url) {
  if (defaultTargetPlatform == TargetPlatform.android &&
      url.contains('localhost')) {
    return url.replaceAll('localhost', '10.0.2.2');
  }
  return url;
}

Uint8List? _resolveLocalBytes(
  Map<String, Uint8List> map,
  String rawUrl,
  String sanitizedUrl,
) {
  final direct = map[rawUrl] ?? map[sanitizedUrl];
  if (direct != null) return direct;

  if (!rawUrl.startsWith('local-media://')) return null;
  final suffix = rawUrl.substring('local-media://'.length);
  final decoded = Uri.decodeComponent(suffix);
  final encoded = Uri.encodeComponent(decoded);

  final byDirect = map['local-media://$decoded'] ??
      map['local-media://$encoded'] ??
      map[decoded] ??
      map[encoded];
  if (byDirect != null) return byDirect;

  final normalizedFileName = decoded.split('/').last.toLowerCase();
  for (final entry in map.entries) {
    final key = entry.key.toLowerCase();
    if (key.contains(normalizedFileName)) {
      return entry.value;
    }
  }
  return null;
}

const String _outlineLikeIcon = '''
<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
  <path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z" />
</svg>
''';

const String _filledLikeIcon = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
  <path d="M11.645 20.91l-.007-.003-.022-.012a15.247 15.247 0 01-.383-.218 25.18 25.18 0 01-4.244-3.17C4.688 15.36 2.25 12.174 2.25 8.25 2.25 5.322 4.714 3 7.688 3A5.5 5.5 0 0112 5.052 5.5 5.5 0 0116.313 3c2.973 0 5.437 2.322 5.437 5.25 0 3.925-2.438 7.111-4.739 9.256a25.175 25.175 0 01-4.244 3.17 15.247 15.247 0 01-.383.219l-.022.012-.007.004-.003.001a.752.752 0 01-.704 0l-.003-.001z" />
</svg>
''';
