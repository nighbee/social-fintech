part of 'home_bloc.dart';

@freezed
class HomeState with _$HomeState {
  const factory HomeState.initial() = _Initial;
  const factory HomeState.loading({required HomeViewModel viewModel}) =
      _Loading;
  const factory HomeState.loadingError(String message) = _LoadingError;
  const factory HomeState.loaded({required HomeViewModel viewModel}) = _Loaded;
}

@freezed
class CommentComposerPhoto with _$CommentComposerPhoto {
  const factory CommentComposerPhoto({
    required Uint8List bytes,
    required String fileName,
  }) = _CommentComposerPhoto;
}

@freezed
class HomeViewModel with _$HomeViewModel {
  const HomeViewModel._();
  factory HomeViewModel({
    @Default([]) List<PostEntity> posts,
    @Default({}) Map<String, List<CommentEntity>> commentsByPost,
    @Default(<String>{}) Set<String> expandedReplyCommentIds,
    @Default([]) List<CommentComposerPhoto> composerPhotos,
    @Default([]) List<CommentComposerPhoto> postComposerPhotos,
    String? replyingToCommentId,
    String? currentlyViewingPostId,
    @Default([]) List<NotificationEntity> notifications,
    @Default(FeedStateEntity.empty()) FeedStateEntity feedState,
  }) = _HomeViewModel;

  List<CommentEntity>? getCommentsForPost(String postId) {
    return commentsByPost[postId];
  }

  HomeViewModel copyWithPost(PostEntity updatedPost) {
    return copyWith(
      posts: posts.map((post) {
        return post.id == updatedPost.id ? updatedPost : post;
      }).toList(),
    );
  }

  HomeViewModel copyWithComment(CommentEntity updatedComment, String postId) {
    final currentComments = commentsByPost[postId] ?? [];
    final updatedComments = currentComments.map((comment) {
      return comment.id == updatedComment.id ? updatedComment : comment;
    }).toList();

    return copyWith(
      commentsByPost: {...commentsByPost, postId: updatedComments},
    );
  }

  HomeViewModel prependPost(PostEntity post) {
    return copyWith(posts: [post, ...posts]);
  }

  HomeViewModel addCommentToPost(
    CommentEntity newComment,
    String postId, {
    String? parentCommentId,
  }) {
    final currentComments = commentsByPost[postId] ?? [];
    final normalizedComment = parentCommentId == null
        ? newComment.copyWith(
            parentCommentId: null,
            rootCommentId: null,
          )
        : newComment.copyWith(
            parentCommentId: parentCommentId,
            rootCommentId: newComment.rootCommentId ?? parentCommentId,
          );

    final updatedComments = parentCommentId == null
        ? [normalizedComment, ...currentComments]
        : [...currentComments, normalizedComment];

    return copyWith(
      commentsByPost: {
        ...commentsByPost,
        postId: updatedComments,
      },
    );
  }

  HomeViewModel incrementRepliesCount(String postId, String parentCommentId) {
    final currentComments = commentsByPost[postId] ?? [];
    final updatedComments = currentComments.map((comment) {
      if (comment.id == parentCommentId) {
        return comment.copyWith(repliesCount: comment.repliesCount + 1);
      }
      return comment;
    }).toList();
    return copyWith(
      commentsByPost: {...commentsByPost, postId: updatedComments},
    );
  }

  List<CommentEntity> getTopLevelCommentsForPost(String postId) {
    final comments = commentsByPost[postId] ?? [];
    return comments.where((comment) => comment.parentCommentId == null).toList();
  }

  List<CommentEntity> getRepliesForComment(String postId, String commentId) {
    final comments = commentsByPost[postId] ?? [];
    return comments
        .where((comment) => comment.parentCommentId == commentId)
        .toList();
  }

  CommentEntity? getCommentById(String commentId) {
    for (final comments in commentsByPost.values) {
      for (final comment in comments) {
        if (comment.id == commentId) {
          return comment;
        }
      }
    }
    return null;
  }

  bool isRepliesExpanded(String commentId) {
    return expandedReplyCommentIds.contains(commentId);
  }

  HomeViewModel toggleRepliesVisibility(String commentId) {
    final updatedExpandedIds = Set<String>.from(expandedReplyCommentIds);
    if (updatedExpandedIds.contains(commentId)) {
      updatedExpandedIds.remove(commentId);
    } else {
      updatedExpandedIds.add(commentId);
    }
    return copyWith(expandedReplyCommentIds: updatedExpandedIds);
  }

  HomeViewModel addComposerPhoto(CommentComposerPhoto photo) {
    if (composerPhotos.any((item) => item.fileName == photo.fileName)) {
      return this;
    }
    return copyWith(composerPhotos: [...composerPhotos, photo]);
  }

  HomeViewModel removeComposerPhoto(String fileName) {
    return copyWith(
      composerPhotos: composerPhotos
          .where((photo) => photo.fileName != fileName)
          .toList(),
    );
  }

  HomeViewModel addPostComposerPhoto(CommentComposerPhoto photo) {
    if (postComposerPhotos.any((item) => item.fileName == photo.fileName)) {
      return this;
    }
    return copyWith(postComposerPhotos: [...postComposerPhotos, photo]);
  }

  HomeViewModel removePostComposerPhoto(String fileName) {
    return copyWith(
      postComposerPhotos: postComposerPhotos
          .where((photo) => photo.fileName != fileName)
          .toList(),
    );
  }
}
