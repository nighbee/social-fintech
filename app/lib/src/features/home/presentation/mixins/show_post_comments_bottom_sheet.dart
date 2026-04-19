import 'dart:math' as math;

import 'package:app/src/core/widgets/gap_extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/helpers/image_picker_helper.dart';
import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:app/src/features/home/domain/entities/comment_entity.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';

mixin ShowPostCommentsBottomSheet {
  void showPostCommentsBottomSheet(
    BuildContext context, {
    required PostEntity post,
  }) {
    context.showRoundedModalBottomSheet(
      backgroundColor: Colors.transparent,
      maxHeightFactor: 0.92,
      child: ActionBottomSheet(
        backgroundColor: const Color(0xFF161616),
        backgroundOpacity: 1,
        enableGlassEffect: false,
        enableDropShadow: false,
        child: PostCommentsBottomSheet(post: post),
      ),
    );
  }
}

class PostCommentsBottomSheet extends StatefulWidget {
  const PostCommentsBottomSheet({super.key, required this.post});

  final PostEntity post;

  @override
  State<PostCommentsBottomSheet> createState() =>
      _PostCommentsBottomSheetState();
}

class _PostCommentsBottomSheetState extends State<PostCommentsBottomSheet> {
  late final TextEditingController _commentController;
  late final FocusNode _focusNode;
  late final HomeBloc _bloc;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _focusNode = FocusNode();
    _bloc = getIt<HomeBloc>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bloc.add(HomeEvent.loadComments(widget.post.id));
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String? _currentReplyTargetId() {
    return _bloc.state.maybeWhen(
      loading: (viewModel) => viewModel.replyingToCommentId,
      loaded: (viewModel) => viewModel.replyingToCommentId,
      orElse: () => null,
    );
  }

  List<CommentComposerPhoto> _currentComposerPhotos() {
    return _bloc.state.maybeWhen(
      loading: (viewModel) => viewModel.composerPhotos,
      loaded: (viewModel) => viewModel.composerPhotos,
      orElse: () => const [],
    );
  }

  Future<void> _pickPhoto() async {
    await ImagePickerHelper.showImagePicker(
      context: context,
      onImageSelected: (bytes, fileName) {
        _bloc.add(HomeEvent.addCommentPhoto(bytes, fileName));
      },
    );
  }

  void _onSendComment() {
    final text = _commentController.text.trim();
    final photoFileNames =
        _currentComposerPhotos().map((photo) => photo.fileName).toList();
    if (text.isEmpty && photoFileNames.isEmpty) return;

    _bloc.add(
      HomeEvent.addComment(
        postId: widget.post.id,
        content: text,
        parentCommentId: _currentReplyTargetId(),
      ),
    );
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return SafeArea(
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
              child: BlocBuilder<HomeBloc, HomeState>(
                bloc: _bloc,
                builder: (context, state) {
                  return state.when(
                    initial: () => const SizedBox.shrink(),
                    loading: (_) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    loadingError: (_) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Failed to load comments',
                            style: TextStyles.bodyMain.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const Gap(8),
                          IconButton(
                            icon:
                                const Icon(Icons.refresh, color: Colors.white),
                            onPressed: () {
                              _bloc.add(HomeEvent.loadComments(widget.post.id));
                            },
                          ),
                        ],
                      ),
                    ),
                    loaded: (viewModel) {
                      final topLevelComments =
                          viewModel.getTopLevelCommentsForPost(widget.post.id);
                      final replyTarget = viewModel.replyingToCommentId == null
                          ? null
                          : viewModel.getCommentById(
                              viewModel.replyingToCommentId!,
                            );

                      return Column(
                        children: [
                          Expanded(
                            child: topLevelComments.isEmpty
                                ? Center(
                                    child: Text(
                                      'No comments yet',
                                      style: TextStyles.bodyMain.copyWith(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    shrinkWrap: true,
                                    itemCount: topLevelComments.length,
                                    separatorBuilder: (_, __) => const Gap(12),
                                    itemBuilder: (context, index) {
                                      final comment = topLevelComments[index];
                                      return PostCommentItem(
                                        comment: comment,
                                        postId: widget.post.id,
                                        viewModel: viewModel,
                                        depth: 0,
                                        onReply: (target) {
                                          _bloc.add(
                                            HomeEvent.setReplyTarget(target.id),
                                          );
                                          _focusNode.requestFocus();
                                        },
                                      );
                                    },
                                  ),
                          ),
                          const Gap(12),
                          _CommentInputBar(
                            controller: _commentController,
                            focusNode: _focusNode,
                            onSend: _onSendComment,
                            onPickPhoto: _pickPhoto,
                            replyToUsername: replyTarget?.username,
                            composerPhotos: viewModel.composerPhotos,
                            onRemovePhoto: (fileName) {
                              _bloc.add(HomeEvent.removeCommentPhoto(fileName));
                            },
                            onCancelReply: () {
                              _bloc.add(const HomeEvent.setReplyTarget(null));
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PostCommentItem extends StatelessWidget {
  const PostCommentItem({
    super.key,
    required this.comment,
    required this.postId,
    required this.viewModel,
    required this.depth,
    required this.onReply,
    this.isLastInThread = true,
    this.connectsToParent = false,
  });

  final CommentEntity comment;
  final String postId;
  final HomeViewModel viewModel;
  final int depth;
  final ValueChanged<CommentEntity> onReply;
  final bool isLastInThread;
  final bool connectsToParent;

  double _actionInset(int targetDepth) {
    final connectorWidth = targetDepth == 0 ? 0.0 : (targetDepth * 16 + 8.0);
    return connectorWidth + 46.0;
  }

  double _hideActionInset(int targetDepth) {
    return math.max(0, _actionInset(targetDepth) - 12);
  }

  @override
  Widget build(BuildContext context) {
    final bloc = getIt<HomeBloc>();
    final replies = viewModel.getRepliesForComment(postId, comment.id);
    final hasReplies = replies.isNotEmpty || comment.repliesCount > 0;
    final isExpanded = viewModel.isRepliesExpanded(comment.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ThreadConnector(
              depth: depth,
              isLastInThread: isLastInThread,
              connectsToParent: connectsToParent,
            ),
            if (comment.userAvatar != null && comment.userAvatar!.isNotEmpty)
              CustomNetworkImage(
                imageUrl: comment.userAvatar!,
                width: 36,
                height: 36,
                borderRadius: BorderRadius.circular(18),
              )
            else
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  comment.username.isNotEmpty
                      ? comment.username[0].toUpperCase()
                      : '?',
                  style: TextStyles.bodyMain.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                        child: Text(
                          comment.username,
                          style: TextStyles.bodyMain.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        timeago.format(comment.createdAt),
                        style: TextStyles.bodyMain.copyWith(
                          color: const Color(0xFF565656),
                        ),
                      ),
                    ].addGap(4),
                  ),
                  const Gap(6),
                  Text(
                    comment.content,
                    style: TextStyles.bodyMain.copyWith(color: Colors.white),
                  ),
                  if (comment.imageUrls.isNotEmpty) const Gap(8),
                  if (comment.imageUrls.isNotEmpty)
                    _CommentImageGrid(imageUrls: comment.imageUrls),
                  const Gap(8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => onReply(comment),
                        child: Text(
                          'Reply',
                          style: TextStyles.bodyMain.copyWith(
                            color: const Color(0xFF838383),
                          ),
                        ),
                      ),
                      const Gap(18),
                      Text(
                        'See Translation',
                        style: TextStyles.bodyMain.copyWith(
                          color: const Color(0xFF6F6F6F),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (hasReplies && !isExpanded) const Gap(8),
                  if (hasReplies && !isExpanded)
                    Padding(
                      padding: EdgeInsets.only(left: _actionInset(depth)),
                      child: GestureDetector(
                        onTap: () {
                          bloc.add(
                              HomeEvent.toggleRepliesVisibility(comment.id));
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 1,
                              color: const Color(0xFF4A4A4A),
                            ),
                            const Gap(8),
                            Text(
                              'View ${math.max(replies.length, comment.repliesCount)} replies',
                              style: TextStyles.bodyMain.copyWith(
                                color: const Color(0xFF8A8A8A),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            CommentLikeButton(
              commentId: comment.id,
              isLiked: comment.isLiked,
              count: comment.likesCount,
            ),
          ],
        ),
        if (hasReplies && isExpanded && replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...replies.asMap().entries.map(
                  (entry) {
                    final replyIndex = entry.key;
                    final reply = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PostCommentItem(
                        comment: reply,
                        postId: postId,
                        viewModel: viewModel,
                        depth: depth + 1,
                        onReply: onReply,
                        isLastInThread: replyIndex == replies.length - 1,
                        connectsToParent: replyIndex == 0,
                      ),
                    );
                  },
                ),
                GestureDetector(
                  onTap: () {
                    bloc.add(HomeEvent.toggleRepliesVisibility(comment.id));
                  },
                  child: Padding(
                    padding: EdgeInsets.only(left: _hideActionInset(depth + 1)),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 1,
                          color: const Color(0xFF4A4A4A),
                        ),
                        const Gap(8),
                        Text(
                          'Hide',
                          style: TextStyles.bodyMain.copyWith(
                            color: const Color(0xFF8A8A8A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ThreadConnector extends StatelessWidget {
  const _ThreadConnector({
    required this.depth,
    required this.isLastInThread,
    required this.connectsToParent,
  });

  final int depth;
  final bool isLastInThread;
  final bool connectsToParent;

  @override
  Widget build(BuildContext context) {
    if (depth == 0) return const SizedBox.shrink();
    return SizedBox(
      width: depth * 16 + 8,
      height: 58,
      child: CustomPaint(
        painter: _ThreadConnectorPainter(
          depth: depth,
          isLastInThread: isLastInThread,
          connectsToParent: connectsToParent,
          color: const Color(0xFF474747),
        ),
      ),
    );
  }
}

class _ThreadConnectorPainter extends CustomPainter {
  _ThreadConnectorPainter({
    required this.depth,
    required this.isLastInThread,
    required this.connectsToParent,
    required this.color,
  });

  final int depth;
  final bool isLastInThread;
  final bool connectsToParent;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;

    const baseX = 9.0;
    const elbowY = 22.0;
    final topY = connectsToParent ? -20.0 : 0.0;
    for (int i = 0; i < depth - 1; i++) {
      final x = baseX + (i * 16.0);
      canvas.drawLine(Offset(x, topY), Offset(x, size.height), paint);
    }

    final branchX = baseX + ((depth - 1) * 16.0);
    final path = Path()
      ..moveTo(branchX, topY)
      ..lineTo(branchX, elbowY - 4)
      ..quadraticBezierTo(branchX, elbowY, branchX + 5, elbowY)
      ..lineTo(size.width, elbowY);
    canvas.drawPath(path, paint);

    if (!isLastInThread) {
      canvas.drawLine(
        Offset(branchX, elbowY),
        Offset(branchX, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThreadConnectorPainter oldDelegate) {
    return oldDelegate.depth != depth || oldDelegate.color != color;
  }
}

class CommentLikeButton extends StatelessWidget {
  const CommentLikeButton({
    super.key,
    required this.commentId,
    required this.isLiked,
    required this.count,
  });

  final String commentId;
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
            final targetComment = viewModel.getCommentById(commentId);
            if (targetComment == null) {
              return Column(
                children: [
                  Assets.icons.like.svg(),
                  Text(
                    count.toString(),
                    style: TextStyles.bodyMain.copyWith(
                      color: const Color(0xFF838383),
                    ),
                  ),
                ],
              );
            }

            final currentlyLiked = targetComment.isLiked;
            final currentCount = targetComment.likesCount;

            return GestureDetector(
              onTap: () {
                if (currentlyLiked) {
                  bloc.add(HomeEvent.unlikeComment(commentId));
                } else {
                  bloc.add(HomeEvent.likeComment(commentId));
                }
              },
              child: Column(
                children: [
                  SvgPicture.string(
                    currentlyLiked ? _filledLikeIcon : _outlineLikeIcon,
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(
                      currentlyLiked ? Colors.red : const Color(0xFF838383),
                      BlendMode.srcIn,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    currentCount.toString(),
                    style: TextStyles.bodyMain.copyWith(
                      color:
                          currentlyLiked ? Colors.red : const Color(0xFF838383),
                    ),
                  ),
                ],
              ),
            );
          },
          orElse: () => Column(
            children: [
              Assets.icons.like.svg(),
              Text(
                count.toString(),
                style: TextStyles.bodyMain.copyWith(
                  color: const Color(0xFF838383),
                ),
              ),
            ],
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

class _CommentInputBar extends StatelessWidget {
  const _CommentInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onPickPhoto,
    required this.composerPhotos,
    required this.onRemovePhoto,
    this.replyToUsername,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onPickPhoto;
  final List<CommentComposerPhoto> composerPhotos;
  final ValueChanged<String> onRemovePhoto;
  final String? replyToUsername;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    final hasReply = replyToUsername != null && replyToUsername!.isNotEmpty;
    final hasPhotos = composerPhotos.isNotEmpty;
    final inputMinHeight = hasPhotos ? 92.0 : 44.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        border: const Border(
          top: BorderSide(color: Color(0x2AFFFFFF), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              Expanded(
                child: Container(
                  constraints: BoxConstraints(minHeight: inputMinHeight),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0x61FFFFFF),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoTheme(
                        data: CupertinoTheme.of(context).copyWith(
                          primaryColor: const Color(0xFFE6E6E6),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            textSelectionTheme: const TextSelectionThemeData(
                              cursorColor: Color(0xFFE6E6E6),
                              selectionColor: Color(0x40FFFFFF),
                              selectionHandleColor: Color(0xFFE6E6E6),
                            ),
                          ),
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            style: TextStyles.bodyMain.copyWith(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            cursorColor: const Color(0xFFE6E6E6),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: hasReply
                                  ? 'Replying to $replyToUsername'
                                  : 'Add a comment...',
                              hintStyle: TextStyles.bodyMain.copyWith(
                                color: const Color(0xFF8C8C8C),
                                fontSize: 14,
                              ),
                            ),
                            onSubmitted: (_) => onSend(),
                          ),
                        ),
                      ),
                      if (hasPhotos) const SizedBox(height: 8),
                      if (hasPhotos)
                        _ComposerPhotoThumb(
                          photo: composerPhotos.first,
                          extraCount: composerPhotos.length - 1,
                          onRemove: onRemovePhoto,
                        ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: onSend,
                child: Assets.icons.sendIcon.svg(),
              ),
            ].addGap(13),
          ),
        ],
      ),
    );
  }
}

class _ComposerPhotoThumb extends StatelessWidget {
  const _ComposerPhotoThumb({
    required this.photo,
    required this.extraCount,
    required this.onRemove,
  });

  final CommentComposerPhoto photo;
  final int extraCount;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            photo.bytes,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => onRemove(photo.fileName),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(
                Icons.close,
                size: 11,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (extraCount > 0)
          Positioned(
            left: 3,
            bottom: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '+$extraCount',
                style: TextStyles.bodyMain.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CommentImageGrid extends StatelessWidget {
  const _CommentImageGrid({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomNetworkImage(
          imageUrl: imageUrls.first,
          width: double.infinity,
          height: 170,
          fit: BoxFit.cover,
        ),
      );
    }

    final previewImages = imageUrls.take(3).toList();
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
                      width: double.infinity,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
