import 'dart:io';

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/helpers/image_picker_helper.dart';
import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:app/src/features/home/domain/entities/comment_response_entity.dart';
import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:app/src/features/home/domain/requests/create_comment_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_comments_request.dart';
import 'package:app/src/features/home/domain/requests/media_attachment_request.dart';
import 'package:app/src/features/home/domain/requests/upload_feed_media_request.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

mixin ShowPostCommentsBottomSheet {
  void showPostCommentsBottomSheet(
    BuildContext context, {
    required HomeBloc bloc,
    required PostResponseEntity post,
  }) {
    context.showRoundedModalBottomSheet(
      backgroundColor: Colors.transparent,
      maxHeightFactor: 0.92,
      child: ActionBottomSheet(
        backgroundColor: const Color(0xFF202020).withValues(alpha: 0.20),
        child: PostCommentsBottomSheet(
          bloc: bloc,
          post: post,
        ),
      ),
    );
  }
}

class PostCommentsBottomSheet extends StatefulWidget {
  const PostCommentsBottomSheet({
    required this.bloc,
    required this.post,
    super.key,
  });

  final HomeBloc bloc;
  final PostResponseEntity post;

  @override
  State<PostCommentsBottomSheet> createState() =>
      _PostCommentsBottomSheetState();
}

class _PostCommentsBottomSheetState extends State<PostCommentsBottomSheet> {
  late final TextEditingController _commentController;
  late final FocusNode _focusNode;

  final Set<String> _expandedReplyCommentIds = <String>{};
  final Set<String> _loadingReplyCommentIds = <String>{};
  final Map<String, List<CommentResponseEntity>> _repliesByParent = {};
  List<CommentResponseEntity> _topLevelComments = const [];

  String? _pendingReplyParentId;
  bool _pendingTopLevelRequest = false;
  String? _replyToCommentId;
  String? _replyToUsername;
  String? _commentError;
  final List<_DraftCommentPhoto> _pendingPhotos = <_DraftCommentPhoto>[];

  void _openPublicProfile(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;

    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.pushNamed(
      RouteNames.publicProfile,
      pathParameters: {'userId': normalizedUserId},
    );
  }

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _focusNode = FocusNode();
    final existing = widget.bloc.state.maybeWhen(
      loaded: (viewModel) => viewModel.comments.comments,
      orElse: () => const <CommentResponseEntity>[],
    );
    if (existing.isNotEmpty) {
      _topLevelComments = _dedupeById(
        existing.where((item) => item.parentCommentId.trim().isEmpty).toList(),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchTopLevelComments());
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _fetchTopLevelComments() {
    _pendingTopLevelRequest = true;
    widget.bloc.add(
      HomeEvent.getPostComments(
        request: GetPostCommentsRequest(postId: widget.post.postId),
      ),
    );
  }

  void _fetchReplies(String parentId) {
    _pendingReplyParentId = parentId;
    _loadingReplyCommentIds.add(parentId);
    widget.bloc.add(
      HomeEvent.getPostComments(
        request: GetPostCommentsRequest(
          postId: widget.post.postId,
          parentId: parentId,
        ),
      ),
    );
  }

  void _toggleReplies(String commentId) {
    setState(() {
      if (_expandedReplyCommentIds.contains(commentId)) {
        _expandedReplyCommentIds.remove(commentId);
      } else {
        _expandedReplyCommentIds.add(commentId);
        if (!_repliesByParent.containsKey(commentId)) {
          _fetchReplies(commentId);
        }
      }
    });
  }

  Future<void> _onSendComment() async {
    final text = _commentController.text.trim();
    final hasPhoto = _pendingPhotos.isNotEmpty;
    if (text.isEmpty && !hasPhoto) return;

    List<MediaAttachmentRequest> mediaAttachments = const [];
    if (hasPhoto) {
      final uploaded = <MediaAttachmentRequest>[];
      for (final item in _pendingPhotos) {
        final bytes = await File(item.filePath).readAsBytes();
        final uploadResult = await widget.bloc.uploadCommentMediaDirect(
          UploadFeedMediaRequest(
            bytes: bytes,
            fileName: item.fileName,
            fallbackType: 'image',
          ),
        );
        if (!mounted) return;

        if (uploadResult.isLeft()) {
          uploadResult.fold(
            (error) => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error.message)),
            ),
            (_) {},
          );
          return;
        }
        uploadResult.fold((_) {}, (attachment) => uploaded.add(attachment));
      }
      mediaAttachments = uploaded;
    }

    final parentId = _replyToCommentId;
    final createResult = await widget.bloc.createPostCommentDirect(
      widget.post.postId,
      CreateCommentRequest(
        parentId: parentId,
        contentText: text,
        mediaAttachments: mediaAttachments,
      ),
    );
    if (!mounted) return;

    if (createResult.isLeft()) {
      createResult.fold(
        (error) {
          final normalized = error.message.toLowerCase();
          final blocked = normalized.contains('comment_not_allowed') ||
              normalized.contains('not allowed') ||
              normalized.contains('forbidden') ||
              normalized.contains('403');
          setState(() {
            _commentError = blocked
                ? "You can\u2019t comment on this post"
                : error.message;
          });
        },
        (_) {},
      );
      return;
    }

    _commentController.clear();
    createResult.fold((_) {}, (createdComment) {
      _applyIncomingCommentUpdates([createdComment]);
    });
    setState(() {
      _replyToCommentId = null;
      _replyToUsername = null;
      _commentError = null;
      _pendingPhotos.clear();
      if (parentId != null && parentId.isNotEmpty) {
        _expandedReplyCommentIds.add(parentId);
      }
    });

    // Reconcile after create to keep reply counts and ordering in sync with backend.
    if (parentId != null && parentId.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _fetchReplies(parentId);
        }
      });
    }
  }

  Future<void> _onPickPhoto() async {
    await ImagePickerHelper.showImagePickerFile(
      context: context,
      imageQuality: 60,
      maxWidth: 1280,
      maxHeight: 1280,
      onImageSelected: (file) {
        setState(() {
          _pendingPhotos.add(
            _DraftCommentPhoto(filePath: file.path, fileName: file.name),
          );
        });
      },
    );
  }

  Future<void> _onToggleCommentLike(CommentResponseEntity comment) async {
    final before = _findCommentById(comment.commentId);
    _applyLocalLikeToggle(comment.commentId);

    final result = await widget.bloc.toggleCommentLikeDirect(
      comment.commentId,
    );
    result.fold(
      (error) {
        if (!mounted) return;
        if (before != null) {
          setState(() {
            _applyIncomingCommentUpdates([before]);
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      },
      (updatedComment) {
        if (!mounted) return;
        setState(() {
          _applyIncomingCommentUpdates([updatedComment]);
        });
        _fetchTopLevelComments();
      },
    );
  }

  CommentResponseEntity? _findCommentById(String commentId) {
    for (final comment in _topLevelComments) {
      if (comment.commentId == commentId) return comment;
    }
    for (final replies in _repliesByParent.values) {
      for (final comment in replies) {
        if (comment.commentId == commentId) return comment;
      }
    }
    return null;
  }

  void _applyLocalLikeToggle(String commentId) {
    setState(() {
      _topLevelComments = _topLevelComments
          .map((comment) => _toggleIfTarget(comment, commentId))
          .toList();

      _repliesByParent.updateAll(
        (_, replies) => replies
            .map((comment) => _toggleIfTarget(comment, commentId))
            .toList(),
      );
    });
  }

  CommentResponseEntity _toggleIfTarget(
    CommentResponseEntity comment,
    String commentId,
  ) {
    if (comment.commentId != commentId) return comment;
    final nextLiked = !comment.viewerHasLiked;
    final nextCount = nextLiked
        ? comment.likesCount + 1
        : (comment.likesCount > 0 ? comment.likesCount - 1 : 0);
    return comment.copyWith(
      viewerHasLiked: nextLiked,
      likesCount: nextCount,
    );
  }

  void _applyIncomingComments(HomeViewModel viewModel) {
    final incoming = _dedupeById(viewModel.comments.comments);
    final pendingParentId = _pendingReplyParentId;
    if (pendingParentId != null) {
      _pendingReplyParentId = null;
      _loadingReplyCommentIds.remove(pendingParentId);
      _repliesByParent[pendingParentId] = incoming;
      _pendingTopLevelRequest = false;
      return;
    }

    if (_pendingTopLevelRequest) {
      _pendingTopLevelRequest = false;
      _topLevelComments = _dedupeById(incoming);
      return;
    }

    _applyIncomingCommentUpdates(incoming);
  }

  void _applyIncomingCommentUpdates(List<CommentResponseEntity> incoming) {
    if (incoming.isEmpty) return;

    final byId = <String, CommentResponseEntity>{
      for (final comment in incoming) comment.commentId: comment,
    };

    _topLevelComments = _topLevelComments
        .map((comment) => byId[comment.commentId] ?? comment)
        .toList();

    _repliesByParent.updateAll(
      (_, replies) =>
          replies.map((comment) => byId[comment.commentId] ?? comment).toList(),
    );

    for (final comment in incoming) {
      final parentId = comment.parentCommentId.trim();
      if (parentId.isEmpty) {
        _topLevelComments = _prependUniqueById(comment, _topLevelComments);
        continue;
      }

      final existing = _repliesByParent[parentId] ?? const <CommentResponseEntity>[];
      _repliesByParent[parentId] = _appendUniqueById(comment, existing);
    }
  }

  List<CommentResponseEntity> _prependUniqueById(
    CommentResponseEntity comment,
    List<CommentResponseEntity> source,
  ) {
    final filtered = source
        .where((item) => item.commentId != comment.commentId)
        .toList();
    return [comment, ...filtered];
  }

  List<CommentResponseEntity> _appendUniqueById(
    CommentResponseEntity comment,
    List<CommentResponseEntity> source,
  ) {
    final exists = source.any((item) => item.commentId == comment.commentId);
    if (exists) {
      return source
          .map((item) => item.commentId == comment.commentId ? comment : item)
          .toList();
    }
    return [...source, comment];
  }

  List<CommentResponseEntity> _dedupeById(List<CommentResponseEntity> comments) {
    final map = <String, CommentResponseEntity>{};
    for (final item in comments) {
      map[item.commentId] = item;
    }
    return map.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return BlocListener<HomeBloc, HomeState>(
      bloc: widget.bloc,
      listener: (context, state) {
        state.maybeWhen(
          loaded: (viewModel) {
            setState(() {
              _applyIncomingComments(viewModel);
            });
          },
          orElse: () {},
        );
      },
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Comments',
                    style: TextStyles.titleHeadline.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Gap(16),
              Flexible(
                child: _topLevelComments.isEmpty
                    ? Center(
                        child: Text(
                          'No comments yet',
                          style: TextStyles.bodyMain.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _topLevelComments.length,
                        separatorBuilder: (_, __) => const Gap(12),
                        itemBuilder: (context, index) {
                          final comment = _topLevelComments[index];
                          return _CommentItem(
                            comment: comment,
                            depth: 0,
                            isExpanded: _expandedReplyCommentIds
                                .contains(comment.commentId),
                            isLoadingReplies: _loadingReplyCommentIds
                                .contains(comment.commentId),
                            replies: _repliesByParent[comment.commentId] ??
                                const <CommentResponseEntity>[],
                            onReply: () {
                              setState(() {
                                _replyToCommentId = comment.commentId;
                                _replyToUsername = comment.author.username;
                                _commentError = null;
                              });
                              _focusNode.requestFocus();
                            },
                            onToggleLike: () => _onToggleCommentLike(comment),
                            onToggleReplies: () =>
                                _toggleReplies(comment.commentId),
                            onReplyToChild: (child) {
                              setState(() {
                                _replyToCommentId = child.commentId;
                                _replyToUsername = child.author.username;
                                _commentError = null;
                              });
                              _focusNode.requestFocus();
                            },
                            childRepliesFor: (id) =>
                                _repliesByParent[id] ??
                                const <CommentResponseEntity>[],
                            onOpenProfile: _openPublicProfile,
                            isChildExpanded: (id) =>
                                _expandedReplyCommentIds.contains(id),
                            isChildLoading: (id) =>
                                _loadingReplyCommentIds.contains(id),
                            onToggleChildReplies: _toggleReplies,
                            onToggleChildLike: _onToggleCommentLike,
                          );
                        },
                      ),
              ),
              _CommentInputBar(
                controller: _commentController,
                focusNode: _focusNode,
                onSend: _onSendComment,
                onPickPhoto: _onPickPhoto,
                photos: _pendingPhotos,
                onRemovePhoto: (index) {
                  setState(() {
                    _pendingPhotos.removeAt(index);
                  });
                },
                errorText: _commentError,
                onChanged: (_) {
                  if (_commentError == null) return;
                  setState(() {
                    _commentError = null;
                  });
                },
                replyToUsername: _replyToUsername,
                onCancelReply: () {
                  setState(() {
                    _replyToCommentId = null;
                    _replyToUsername = null;
                    _commentError = null;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({
    required this.comment,
    required this.depth,
    required this.isExpanded,
    required this.isLoadingReplies,
    required this.replies,
    required this.onReply,
    required this.onToggleLike,
    required this.onToggleReplies,
    required this.onReplyToChild,
    required this.childRepliesFor,
    required this.onOpenProfile,
    required this.isChildExpanded,
    required this.isChildLoading,
    required this.onToggleChildReplies,
    required this.onToggleChildLike,
  });

  final CommentResponseEntity comment;
  final int depth;
  final bool isExpanded;
  final bool isLoadingReplies;
  final List<CommentResponseEntity> replies;
  final VoidCallback onReply;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleReplies;
  final ValueChanged<CommentResponseEntity> onReplyToChild;
  final List<CommentResponseEntity> Function(String id) childRepliesFor;
  final ValueChanged<String> onOpenProfile;
  final bool Function(String id) isChildExpanded;
  final bool Function(String id) isChildLoading;
  final ValueChanged<String> onToggleChildReplies;
  final ValueChanged<CommentResponseEntity> onToggleChildLike;

  @override
  Widget build(BuildContext context) {
    final hasReplies = comment.replyCount > 0 || replies.isNotEmpty;
    final mediaUrls = comment.mediaAttachments
        .map((item) => item.url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
    final hasMedia = mediaUrls.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: depth * 14),
            GestureDetector(
              onTap: () => onOpenProfile(comment.author.id),
              child: _CommentAvatar(url: comment.author.profilePicUrl),
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: () => onOpenProfile(comment.author.id),
                          child: Text(
                            comment.author.username,
                            style: TextStyles.bodyMain.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const Gap(6),
                      Text(
                        _commentDisplayTime(comment),
                        style: TextStyles.bodyMain.copyWith(
                          color: const Color(0xFF838383),
                        ),
                      ),
                    ],
                  ),
                  const Gap(6),
                  Text(
                    comment.contentText,
                    style: TextStyles.bodyMain.copyWith(color: Colors.white),
                  ),
                  if (hasMedia) const Gap(8),
                  if (hasMedia)
                    _CommentImageGrid(imageUrls: mediaUrls),
                  const Gap(8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onReply,
                        child: Text(
                          'Reply',
                          style: TextStyles.bodyMain.copyWith(
                            color: const Color(0xFF838383),
                          ),
                        ),
                      ),
                      if (hasReplies) ...[
                        const Gap(18),
                        GestureDetector(
                          onTap: onToggleReplies,
                          child: Text(
                            isExpanded
                                ? 'Hide replies'
                                : (isLoadingReplies
                                    ? 'Loading replies...'
                                    : 'View ${comment.replyCount} replies'),
                            style: TextStyles.bodyMain.copyWith(
                              color: const Color(0xFF838383),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _CommentLikeButton(
              isLiked: comment.viewerHasLiked,
              count: comment.likesCount,
              onTap: onToggleLike,
            ),
          ],
        ),
        if (isExpanded && replies.isNotEmpty) ...[
          const Gap(10),
          ...replies.map(
            (reply) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CommentItem(
                comment: reply,
                depth: depth + 1,
                isExpanded: isChildExpanded(reply.commentId),
                isLoadingReplies: isChildLoading(reply.commentId),
                replies: childRepliesFor(reply.commentId),
                onReply: () => onReplyToChild(reply),
                onToggleLike: () => onToggleChildLike(reply),
                onToggleReplies: () => onToggleChildReplies(reply.commentId),
                onReplyToChild: onReplyToChild,
                childRepliesFor: childRepliesFor,
                onOpenProfile: onOpenProfile,
                isChildExpanded: isChildExpanded,
                isChildLoading: isChildLoading,
                onToggleChildReplies: onToggleChildReplies,
                onToggleChildLike: onToggleChildLike,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _commentDisplayTime(CommentResponseEntity comment) {
  final createdAt = comment.createdAt.trim();
  if (createdAt.isNotEmpty) {
    final parsed = DateTime.tryParse(createdAt);
    if (parsed != null) {
      return timeago.format(parsed);
    }
  }
  return comment.timeAgo;
}

class _CommentLikeButton extends StatelessWidget {
  const _CommentLikeButton({
    required this.isLiked,
    required this.count,
    required this.onTap,
  });

  final bool isLiked;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            size: 16,
            color: isLiked ? Colors.red : const Color(0xFF838383),
          ),
          const Gap(4),
          Text(
            count.toString(),
            style: TextStyles.bodyMain.copyWith(
              color: isLiked ? Colors.red : const Color(0xFF838383),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.colorff2A2A2B,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.person, color: Colors.white70, size: 18),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        url,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        cacheWidth: 108,
        cacheHeight: 108,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.colorff2A2A2B,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.person, color: Colors.white70, size: 18),
        ),
      ),
    );
  }
}

class _CommentInputBar extends StatelessWidget {
  const _CommentInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onPickPhoto,
    required this.onRemovePhoto,
    required this.onChanged,
    required this.photos,
    this.errorText,
    this.replyToUsername,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function() onSend;
  final VoidCallback onPickPhoto;
  final ValueChanged<int> onRemovePhoto;
  final ValueChanged<String> onChanged;
  final List<_DraftCommentPhoto> photos;
  final String? errorText;
  final String? replyToUsername;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 168, 168, 168).withValues(
          alpha: 0.08,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (errorText != null && errorText!.trim().isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  errorText!,
                  style: TextStyles.bodyMain.copyWith(
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
            ),
          if (replyToUsername != null && replyToUsername!.isNotEmpty)
            Row(
              children: [
                Text(
                  'Replying to @$replyToUsername',
                  style: TextStyles.bodyMain.copyWith(
                    color: const Color(0xFFB8B8B8),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onCancelReply,
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFFB8B8B8),
                    size: 16,
                  ),
                ),
              ],
            ),
          if (replyToUsername != null && replyToUsername!.isNotEmpty)
            const Gap(8),
          if (photos.isNotEmpty)
            SizedBox(
              height: 68,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const Gap(8),
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  final cacheSize =
                      (68 * MediaQuery.of(context).devicePixelRatio).round();
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(photo.filePath),
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                          cacheWidth: cacheSize,
                          cacheHeight: cacheSize,
                          filterQuality: FilterQuality.low,
                          gaplessPlayback: true,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => onRemovePhoto(index),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          if (photos.isNotEmpty) const Gap(8),
          Row(
            children: [
              GestureDetector(
                onTap: onPickPhoto,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white),
                  ),
                  child: Assets.icons.plusIcon.svg(),
                ),
              ),
              const Gap(13),
              Expanded(
                child: CustomTextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  labelText: 'Add a comment...',
                  showLabel: false,
                  height: 40,
                ),
              ),
              const Gap(13),
              GestureDetector(
                onTap: () {
                  onSend();
                },
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentImageGrid extends StatelessWidget {
  const _CommentImageGrid({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final singleCacheWidth = (maxWidth * devicePixelRatio).round();
        final singleCacheHeight = (170 * devicePixelRatio).round();

        if (imageUrls.length == 1) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CustomNetworkImage(
              imageUrl: imageUrls.first,
              width: maxWidth,
              height: 170,
              fit: BoxFit.cover,
              cacheWidth: singleCacheWidth,
              cacheHeight: singleCacheHeight,
            ),
          );
        }

        final previewImages = imageUrls.take(3).toList();
        final perItemWidth =
            ((maxWidth - 12) / 3).clamp(1, double.infinity).toDouble();
        final itemCacheWidth = (perItemWidth * devicePixelRatio).round();
        final itemCacheHeight = (120 * devicePixelRatio).round();

        return SizedBox(
          height: 120,
          child: Row(
            children: previewImages
                .map(
                  (url) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CustomNetworkImage(
                          imageUrl: url,
                          width: perItemWidth,
                          height: 120,
                          fit: BoxFit.cover,
                          cacheWidth: itemCacheWidth,
                          cacheHeight: itemCacheHeight,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _DraftCommentPhoto {
  const _DraftCommentPhoto({
    required this.filePath,
    required this.fileName,
  });

  final String filePath;
  final String fileName;
}
