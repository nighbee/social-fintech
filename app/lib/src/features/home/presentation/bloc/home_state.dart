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
    @Default(FeedEntity.empty()) FeedEntity feed,
    @Default(ThreadedCommentsEntity.empty()) ThreadedCommentsEntity comments,
    @Default(InteractionListEntity.empty()) InteractionListEntity likes,
    @Default(StatusResponseEntity.empty()) StatusResponseEntity lastAction,
    @Default(StoreSummaryEntity.empty()) StoreSummaryEntity storeSummary,
    @Default(ClaimDailyAccrualResultEntity.empty())
    ClaimDailyAccrualResultEntity lastStoreAccrualResult,
    @Default(<ProfileSearchResultEntity>[])
    List<ProfileSearchResultEntity> profileSearchResults,
    @Default(<ProfileSearchRecentItemEntity>[])
    List<ProfileSearchRecentItemEntity> profileSearchRecentItems,
    @Default(false) bool isProfileSearchLoading,
    @Default('') String profileSearchQuery,
    @Default('') String profileSearchError,
    @Default('') String postCommentsError,
    @Default(<LocalMediaPayload>[]) List<LocalMediaPayload> localMediaPayloads,
    @Default([]) List<CommentComposerPhoto> postComposerPhotos,
    String? replyingToCommentId,
    @Default(<String>[]) List<String> expandedReplyCommentIds,
    @Default([]) List<NotificationEntity> notifications,
    @Default(FeedStateEntity.empty()) FeedStateEntity feedState,
  }) = _HomeViewModel;

  List<PostResponseEntity> get posts => feed.items;
  List<CommentComposerPhoto> get composerPhotos => postComposerPhotos;

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

  List<CommentEntity> getTopLevelCommentsForPost(String postId) {
    return comments.comments
        .where((item) => (item.parentCommentId).trim().isEmpty)
        .map((item) => _toLegacyComment(item, postId: postId))
        .toList(growable: false);
  }

  List<CommentEntity> getRepliesForComment(String postId, String commentId) {
    return comments.comments
        .where(
          (item) => item.parentCommentId.trim() == commentId,
        )
        .map((item) => _toLegacyComment(item, postId: postId))
        .toList(growable: false);
  }

  bool isRepliesExpanded(String commentId) {
    return expandedReplyCommentIds.contains(commentId);
  }

  CommentEntity? getCommentById(String commentId) {
    for (final item in comments.comments) {
      if (item.commentId == commentId) {
        return _toLegacyComment(item, postId: '');
      }
    }
    return null;
  }

  CommentEntity _toLegacyComment(
    CommentResponseEntity comment, {
    required String postId,
  }) {
    String? resolveCommentAvatar() {
      final commentAvatar = comment.author.profilePicUrl.trim();
      if (commentAvatar.isNotEmpty) {
        return commentAvatar;
      }

      if (postId.isEmpty) {
        return null;
      }

      for (final post in feed.items.reversed) {
        if (post.postId != postId) {
          continue;
        }
        if (post.author.id != comment.author.id) {
          continue;
        }
        final authorAvatar = post.author.profilePicUrl.trim();
        if (authorAvatar.isNotEmpty) {
          return authorAvatar;
        }
      }

      return null;
    }

    return CommentEntity(
      id: comment.commentId,
      postId: postId,
      parentCommentId: comment.parentCommentId.trim().isEmpty
          ? null
          : comment.parentCommentId,
      rootCommentId: comment.rootCommentId.trim().isEmpty
          ? null
          : comment.rootCommentId,
      userId: comment.author.id,
      username: comment.author.username,
        userAvatar: resolveCommentAvatar(),
      content: comment.contentText,
      imageUrls: comment.mediaAttachments.map((item) => item.url).toList(),
      likesCount: comment.likesCount,
      isLiked: comment.viewerHasLiked,
      repliesCount: comment.replyCount,
      createdAt: DateTime.tryParse(comment.createdAt) ?? DateTime.now(),
    );
  }
}

