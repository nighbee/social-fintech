part of 'home_bloc.dart';

@freezed
class HomeEvent with _$HomeEvent {
  const factory HomeEvent.loadPosts() = _LoadPosts;
  const factory HomeEvent.likePost(String postId) = _LikePost;
  const factory HomeEvent.unlikePost(String postId) = _UnlikePost;
  const factory HomeEvent.loadComments(String postId) = _LoadComments;
  const factory HomeEvent.addComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) = _AddComment;
  const factory HomeEvent.likeComment(String commentId) = _LikeComment;
  const factory HomeEvent.unlikeComment(String commentId) = _UnlikeComment;
  const factory HomeEvent.setReplyTarget(String? commentId) = _SetReplyTarget;
  const factory HomeEvent.toggleRepliesVisibility(String commentId) =
      _ToggleRepliesVisibility;
  const factory HomeEvent.addCommentPhoto(
    Uint8List bytes,
    String fileName,
  ) = _AddCommentPhoto;
  const factory HomeEvent.removeCommentPhoto(String fileName) =
      _RemoveCommentPhoto;
  const factory HomeEvent.clearCommentPhotos() = _ClearCommentPhotos;
}
