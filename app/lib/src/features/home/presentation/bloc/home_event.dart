part of 'home_bloc.dart';

@freezed
class HomeEvent with _$HomeEvent {
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
  const factory HomeEvent.getPostComments({
    required GetPostCommentsRequest request,
  }) = _GetPostComments;
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
  const factory HomeEvent.loadStoreSummaryV2() = _LoadStoreSummaryV2;
  const factory HomeEvent.claimStoreDailyAccrualV2({
    required ClaimDailyAccrualRequest request,
  }) = _ClaimStoreDailyAccrualV2;
  const factory HomeEvent.applyStoreSummaryV2({
    required StoreSummaryEntity storeSummary,
  }) = _ApplyStoreSummaryV2;
  const factory HomeEvent.applyPostSealResult({
    required String postId,
    required SendPostSealResultEntity result,
  }) = _ApplyPostSealResult;
}

