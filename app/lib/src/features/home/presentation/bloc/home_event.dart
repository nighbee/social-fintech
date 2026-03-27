part of 'home_bloc.dart';

@freezed
class HomeEvent with _$HomeEvent {
  const factory HomeEvent.loadPosts() = _LoadPosts;
  const factory HomeEvent.loadFeed({
    required FeedRequest request,
  }) = _LoadFeed;
  const factory HomeEvent.addPostPhoto(
    Uint8List bytes,
    String fileName,
  ) = _AddPostPhoto;
  const factory HomeEvent.removePostPhoto(String fileName) = _RemovePostPhoto;
  const factory HomeEvent.clearPostPhotos() = _ClearPostPhotos;
  const factory HomeEvent.loadNotifications() = _LoadNotifications;
  const factory HomeEvent.loadFeedState() = _LoadFeedState;
  const factory HomeEvent.syncFeedState({
    required int deltaSeconds,
    required String deviceId,
  }) = _SyncFeedState;
  const factory HomeEvent.createFeedPost({
    required CreatePostRequest request,
    @Default(<LocalMediaPayload>[]) List<LocalMediaPayload> localMediaPayloads,
  }) = _CreateFeedPost;
  const factory HomeEvent.createPost({
    required String content,
  }) = _CreatePost;
  const factory HomeEvent.loadComments(String postId) = _LoadComments;
  const factory HomeEvent.getPostComments({
    required GetPostCommentsRequest request,
  }) = _GetPostComments;
  const factory HomeEvent.addComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) = _AddComment;
  const factory HomeEvent.setReplyTarget(String? commentId) = _SetReplyTarget;
  const factory HomeEvent.addCommentPhoto(
    Uint8List bytes,
    String fileName,
  ) = _AddCommentPhoto;
  const factory HomeEvent.removeCommentPhoto(String fileName) =
      _RemoveCommentPhoto;
  const factory HomeEvent.toggleRepliesVisibility(String commentId) =
      _ToggleRepliesVisibility;
  const factory HomeEvent.likeComment(String commentId) = _LikeComment;
  const factory HomeEvent.unlikeComment(String commentId) = _UnlikeComment;
  const factory HomeEvent.createPostComment({
    required String postId,
    required CreateCommentRequest request,
  }) = _CreatePostComment;
  const factory HomeEvent.getPostLikes({
    required GetPostLikesRequest request,
  }) = _GetPostLikes;
  const factory HomeEvent.togglePostLike({
    required String postId,
  }) = _TogglePostLike;
  const factory HomeEvent.loadStoreSummary() = _LoadStoreSummary;
  const factory HomeEvent.claimStoreDailyAccrual({
    required ClaimDailyAccrualRequest request,
  }) = _ClaimStoreDailyAccrual;
  const factory HomeEvent.searchProfiles({
    required SearchProfilesRequest request,
  }) = _SearchProfiles;
  const factory HomeEvent.clearProfileSearch() = _ClearProfileSearch;
  const factory HomeEvent.addProfileSearchRecent({
    required ProfileSearchResultEntity result,
  }) = _AddProfileSearchRecent;
  const factory HomeEvent.removeProfileSearchRecent({
    required String userId,
  }) = _RemoveProfileSearchRecent;
  const factory HomeEvent.clearProfileSearchRecent() =
      _ClearProfileSearchRecent;
  const factory HomeEvent.applyStoreSummary({
    required StoreSummaryEntity storeSummary,
  }) = _ApplyStoreSummary;
  const factory HomeEvent.applyProfileSearchResults({
    required List<ProfileSearchResultEntity> results,
  }) = _ApplyProfileSearchResults;
  const factory HomeEvent.applyPostSealResult({
    required String postId,
    required SendPostSealResultEntity result,
  }) = _ApplyPostSealResult;
}

