import 'dart:convert';
import 'dart:typed_data';

import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/base/base_bloc/bloc/base_bloc.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/injectable/service_register_proxy.dart';
import 'package:app/src/core/service/storage/app_storage/storage_service.dart';
import 'package:app/src/features/home/data/repositories/home_repository_impl.dart';
import 'package:app/src/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:app/src/features/home/domain/entities/claim_daily_accrual_result_entity.dart';
import 'package:app/src/features/home/domain/entities/comment_entity.dart';
import 'package:app/src/features/home/domain/entities/comment_response_entity.dart';
import 'package:app/src/features/home/domain/entities/profile_search_recent_item_entity.dart';
import 'package:app/src/features/home/domain/entities/store_summary_entity.dart';
import 'package:app/src/features/home/domain/entities/feed_entity.dart';
import 'package:app/src/features/home/domain/entities/feed_state_entity.dart';
import 'package:app/src/features/home/domain/entities/interaction_list_entity.dart';
import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:app/src/features/home/domain/entities/notification_entity.dart';
import 'package:app/src/features/home/domain/entities/seal_list_entity.dart';
import 'package:app/src/features/home/domain/entities/send_post_seal_result_entity.dart';
import 'package:app/src/features/home/domain/entities/status_response_entity.dart';
import 'package:app/src/features/home/domain/entities/threaded_comments_entity.dart';
import 'package:app/src/features/home/domain/entities/report_post_result_entity.dart';
import 'package:app/src/features/home/domain/models/local_media_payload.dart';
import 'package:app/src/features/home/domain/requests/create_comment_request.dart';
import 'package:app/src/features/home/domain/requests/create_post_request.dart';
import 'package:app/src/features/home/domain/requests/comment_id_request.dart';
import 'package:app/src/features/home/domain/requests/claim_daily_accrual_request.dart';
import 'package:app/src/features/home/domain/requests/feed_request.dart';
import 'package:app/src/features/home/domain/requests/feed_state_sync_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_comments_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_likes_request.dart';
import 'package:app/src/features/home/domain/requests/get_my_profile_posts_request.dart';
import 'package:app/src/features/home/domain/requests/get_profile_posts_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_seals_request.dart';
import 'package:app/src/features/home/domain/requests/media_attachment_request.dart';
import 'package:app/src/features/home/domain/requests/post_id_request.dart';
import 'package:app/src/features/home/domain/requests/report_post_request.dart';
import 'package:app/src/features/home/domain/requests/send_post_seal_request.dart';
import 'package:app/src/features/home/domain/requests/update_post_request.dart';
import 'package:app/src/features/home/domain/requests/upload_feed_media_request.dart';
import 'package:app/src/features/home/domain/repositories/i_home_repository.dart';
import 'package:app/src/features/profile/domain/entities/profile_search_result_entity.dart';
import 'package:app/src/features/profile/domain/repositories/i_profile_repository.dart';
import 'package:app/src/features/profile/domain/requests/search_profiles_request.dart';
import 'package:fpdart/fpdart.dart';

part 'home_bloc.freezed.dart';
part 'home_event.dart';
part 'home_state.dart';

@injectable
class HomeBloc extends BaseBloc<HomeEvent, HomeState> {
  static const String _kProfileSearchRecentPrefsKey =
      'brightbund_profile_search_recent_v1';

  HomeBloc(
    @Named.from(HomeRepositoryImpl) this._repository,
    @Named.from(ProfileRepositoryImpl) this._profileRepository,
  ) : super(const _Initial());

  final IHomeRepository _repository;
  final IProfileRepository _profileRepository;
  HomeViewModel _viewModel = HomeViewModel();
  FeedEntity _profilePostsGridCache = const FeedEntity.empty();
  FeedEntity _profilePostsListCache = const FeedEntity.empty();
  FeedEntity _myProfilePostsListCache = const FeedEntity.empty();
  String _profilePostsGridUserId = '';
  String _profilePostsListUserId = '';
  String _activeCommentsPostId = '';
  final Set<String> _sendingSealPostIds = <String>{};

  FeedEntity get profilePostsGridCache => _profilePostsGridCache;
  FeedEntity get profilePostsListCache => _profilePostsListCache;
  FeedEntity get myProfilePostsListCache => _myProfilePostsListCache;
  String get profilePostsGridUserId => _profilePostsGridUserId;
  String get profilePostsListUserId => _profilePostsListUserId;

  @override
  Future<void> onEventHandler(HomeEvent event, Emitter emit) async {
    await event.when(
      loadPosts: () => _loadPosts(emit),
      loadFeed: (_) => _loadFeed(event as _LoadFeed, emit),
      addPostPhoto: (_, __) => _addPostPhoto(event as _AddPostPhoto, emit),
      removePostPhoto: (_) => _removePostPhoto(event as _RemovePostPhoto, emit),
      clearPostPhotos: () => _clearPostPhotos(emit),
      loadNotifications: () =>
          _loadNotifications(event as _LoadNotifications, emit),
      loadFeedState: () => _loadFeedState(event as _LoadFeedState, emit),
      syncFeedState: (_, __, ___, ____) =>
          _syncFeedState(event as _SyncFeedState, emit),
      createFeedPost: (_, __) =>
          _createFeedPost(event as _CreateFeedPost, emit),
      createPost: (_) => _createPostCompat(event as _CreatePost, emit),
      loadComments: (_) => _loadCommentsCompat(event as _LoadComments, emit),
      getPostComments: (_) => _getPostComments(event as _GetPostComments, emit),
      addComment: (_, __, ___) => _addCommentCompat(event as _AddComment, emit),
      setReplyTarget: (_) =>
          _setReplyTargetCompat(event as _SetReplyTarget, emit),
      addCommentPhoto: (_, __) =>
          _addCommentPhotoCompat(event as _AddCommentPhoto, emit),
      removeCommentPhoto: (_) =>
          _removeCommentPhotoCompat(event as _RemoveCommentPhoto, emit),
      toggleRepliesVisibility: (_) => _toggleRepliesVisibilityCompat(
        event as _ToggleRepliesVisibility,
        emit,
      ),
      likeComment: (_) => _likeCommentCompat(event as _LikeComment, emit),
      unlikeComment: (_) => _unlikeCommentCompat(event as _UnlikeComment, emit),
      createPostComment: (_, __) =>
          _createPostComment(event as _CreatePostComment, emit),
      getPostLikes: (_) => _getPostLikes(event as _GetPostLikes, emit),
      togglePostLike: (_) => _togglePostLike(event as _TogglePostLike, emit),
      applyPostSealResult: (_, __) =>
          _applyPostSealResult(event as _ApplyPostSealResult, emit),
      loadStoreSummary: () =>
          _loadStoreSummary(event as _LoadStoreSummary, emit),
      claimStoreDailyAccrual: (_) => _claimStoreDailyAccrual(
        event as _ClaimStoreDailyAccrual,
        emit,
      ),
      applyStoreSummary: (_) =>
          _applyStoreSummary(event as _ApplyStoreSummary, emit),
      searchProfiles: (_) => _searchProfiles(event as _SearchProfiles, emit),
      clearProfileSearch: () => _clearProfileSearch(emit),
      addProfileSearchRecent: (_) =>
          _addProfileSearchRecent(event as _AddProfileSearchRecent, emit),
      removeProfileSearchRecent: (_) => _removeProfileSearchRecent(
        event as _RemoveProfileSearchRecent,
        emit,
      ),
      clearProfileSearchRecent: () => _clearProfileSearchRecent(emit),
      hydrateProfileSearchRecent: () => _hydrateProfileSearchRecent(emit),
      applyProfileSearchResults: (_) => _applyProfileSearchResults(
        event as _ApplyProfileSearchResults,
        emit,
      ),
    );
  }

  Future<void> _addPostPhoto(_AddPostPhoto event, Emitter emit) async {
    _viewModel = _viewModel.addPostComposerPhoto(
      CommentComposerPhoto(bytes: event.bytes, fileName: event.fileName),
    );
    emit(HomeState.loaded(viewModel: _viewModel));
  }

  Future<void> _removePostPhoto(_RemovePostPhoto event, Emitter emit) async {
    _viewModel = _viewModel.removePostComposerPhoto(event.fileName);
    emit(HomeState.loaded(viewModel: _viewModel));
  }

  Future<void> _clearPostPhotos(Emitter emit) async {
    _viewModel = _viewModel.copyWith(postComposerPhotos: const []);
    emit(HomeState.loaded(viewModel: _viewModel));
  }

  Future<void> _loadPosts(Emitter emit) async {
    await _loadFeed(const _LoadFeed(request: FeedRequest()), emit);
  }

  Future<void> _createPostCompat(_CreatePost event, Emitter emit) async {
    final request = CreatePostRequest(
      caption: event.content,
      mediaAttachments: const <MediaAttachmentRequest>[],
      visibility: 'ANYONE',
      commentPermission: 'ANYONE',
      hideLikesCount: false,
    );
    final payloads = _viewModel.postComposerPhotos
        .map(
          (photo) => LocalMediaPayload(
            localUrl: photo.fileName,
            bytes: photo.bytes,
          ),
        )
        .toList(growable: false);
    await _createFeedPost(
      _CreateFeedPost(request: request, localMediaPayloads: payloads),
      emit,
    );
    _viewModel = _viewModel.copyWith(
      postComposerPhotos: const [],
    );
  }

  Future<void> _loadCommentsCompat(_LoadComments event, Emitter emit) async {
    _activeCommentsPostId = event.postId;
    await _getPostComments(
      _GetPostComments(
        request: GetPostCommentsRequest(postId: event.postId),
      ),
      emit,
    );
  }

  Future<void> _addCommentCompat(_AddComment event, Emitter emit) async {
    final mediaAttachments = _viewModel.postComposerPhotos
        .map(
          (photo) => MediaAttachmentRequest(
            type: 'image',
            url: 'local://${photo.fileName}',
          ),
        )
        .toList(growable: false);
    await _createPostComment(
      _CreatePostComment(
        postId: event.postId,
        request: CreateCommentRequest(
          parentId: event.parentCommentId,
          contentText: event.content,
          mediaAttachments: mediaAttachments,
        ),
      ),
      emit,
    );
    if (_viewModel.postCommentsError.trim().isNotEmpty) {
      return;
    }
    _viewModel = _viewModel.copyWith(
      replyingToCommentId: null,
      postComposerPhotos: const [],
    );
    emit(HomeState.loaded(viewModel: _viewModel));
  }

  Future<void> _setReplyTargetCompat(
      _SetReplyTarget event, Emitter emit) async {
    _viewModel = _viewModel.copyWith(replyingToCommentId: event.commentId);
    emit(HomeState.loaded(viewModel: _viewModel));
  }

  Future<void> _addCommentPhotoCompat(
    _AddCommentPhoto event,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.addPostComposerPhoto(
      CommentComposerPhoto(bytes: event.bytes, fileName: event.fileName),
    );
    emit(HomeState.loaded(viewModel: _viewModel));
  }

  Future<void> _removeCommentPhotoCompat(
    _RemoveCommentPhoto event,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.removePostComposerPhoto(event.fileName);
    emit(HomeState.loaded(viewModel: _viewModel));
  }

  Future<void> _toggleRepliesVisibilityCompat(
    _ToggleRepliesVisibility event,
    Emitter emit,
  ) async {
    final current = _viewModel.expandedReplyCommentIds;
    final contains = current.contains(event.commentId);
    if (contains) {
      _viewModel = _viewModel.copyWith(
        expandedReplyCommentIds: current
            .where((id) => id != event.commentId)
            .toList(growable: false),
      );
      emit(HomeState.loaded(viewModel: _viewModel));
      return;
    }

    _viewModel = _viewModel.copyWith(
      expandedReplyCommentIds: <String>[...current, event.commentId],
    );
    emit(HomeState.loaded(viewModel: _viewModel));

    final alreadyLoaded = _viewModel.comments.comments.any(
      (comment) => comment.parentCommentId == event.commentId,
    );
    if (alreadyLoaded || _activeCommentsPostId.isEmpty) return;

    final result = await _repository.getPostComments(
      GetPostCommentsRequest(
        postId: _activeCommentsPostId,
        parentId: event.commentId,
      ),
    );
    result.fold(
      (_) {
        _viewModel = _viewModel.copyWith(
          expandedReplyCommentIds: _viewModel.expandedReplyCommentIds
              .where((id) => id != event.commentId)
              .toList(growable: false),
        );
        emit(HomeState.loaded(viewModel: _viewModel));
      },
      (replies) {
        final commentsById = <String, CommentResponseEntity>{
          for (final comment in _viewModel.comments.comments)
            comment.commentId: comment,
          for (final reply in replies.comments) reply.commentId: reply,
        };
        _viewModel = _viewModel.copyWith(
          comments: _viewModel.comments.copyWith(
            comments: commentsById.values.toList(growable: false),
          ),
        );
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _likeCommentCompat(_LikeComment event, Emitter emit) async {
    CommentResponseEntity? current;
    for (final item in _viewModel.comments.comments) {
      if (item.commentId == event.commentId) {
        current = item;
        break;
      }
    }
    if (current?.viewerHasLiked == true) {
      emit(HomeState.loaded(viewModel: _viewModel));
      return;
    }
    await _toggleCommentLikeCompat(event.commentId, emit);
  }

  Future<void> _unlikeCommentCompat(_UnlikeComment event, Emitter emit) async {
    CommentResponseEntity? current;
    for (final item in _viewModel.comments.comments) {
      if (item.commentId == event.commentId) {
        current = item;
        break;
      }
    }
    if (current?.viewerHasLiked != true) {
      emit(HomeState.loaded(viewModel: _viewModel));
      return;
    }
    await _toggleCommentLikeCompat(event.commentId, emit);
  }

  Future<void> _toggleCommentLikeCompat(String commentId, Emitter emit) async {
    final result = await _repository.toggleCommentLike(
      CommentIdRequest(commentId: commentId),
    );
    result.fold(
      (error) => emit(HomeState.loadingError(error.message)),
      (updatedComment) {
        final updatedComments = _viewModel.comments.comments.map((item) {
          if (item.commentId != updatedComment.commentId) {
            return item;
          }
          return updatedComment;
        }).toList(growable: false);
        _viewModel = _viewModel.copyWith(
          comments: _viewModel.comments.copyWith(comments: updatedComments),
        );
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _loadNotifications(
      _LoadNotifications event, Emitter emit) async {
    try {
      final result = await _repository.getNotifications();
      result.fold(
        (error) => emit(HomeState.loadingError(error.message)),
        (notifications) {
          _viewModel = _viewModel.copyWith(notifications: notifications);
          emit(HomeState.loaded(viewModel: _viewModel));
        },
      );
    } catch (e) {
      emit(HomeState.loadingError(e.toString()));
    }
  }

  Future<void> _loadFeed(_LoadFeed event, Emitter emit) async {
    emit(HomeState.loading(viewModel: _viewModel));
    final result = await _repository.getFeed(event.request);
    result.fold(
      (error) => emit(HomeState.loadingError(error.message)),
      (feed) {
        _viewModel = _viewModel.copyWith(
          feed: _mergeIncomingFeedWithCurrent(
            current: _viewModel.feed,
            incoming: feed,
          ),
        );
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _loadFeedState(_LoadFeedState event, Emitter emit) async {
    final result = await _repository.getFeedState();
    result.fold(
      (error) => emit(HomeState.loadingError(error.message)),
      (feedState) {
        _viewModel = _viewModel.copyWith(feedState: feedState);
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _syncFeedState(_SyncFeedState event, Emitter emit) async {
    final request = FeedStateSyncRequest(
      deltaSeconds: event.deltaSeconds,
      deviceId: event.deviceId,
      isFeedActive: event.isFeedActive,
      appSection: event.appSection,
    );
    final result = await _repository.syncFeedState(request);
    result.fold(
      (error) => emit(HomeState.loadingError(error.message)),
      (feedState) {
        _viewModel = _viewModel.copyWith(feedState: feedState);
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<Either<DomainException, FeedEntity>> getFeed(
    FeedRequest request,
  ) async {
    return _repository.getFeed(request);
  }

  Future<Either<DomainException, FeedEntity>> getProfilePostsGridDirect(
    GetProfilePostsRequest request,
  ) async {
    final result = await _repository.getProfilePostsGrid(request);
    result.fold(
      (_) {},
      (feed) {
        final currentFeed = _profilePostsGridUserId == request.userId
            ? _profilePostsGridCache
            : const FeedEntity.empty();
        _profilePostsGridCache = _mergeFeedForCursor(
          current: currentFeed,
          incoming: feed,
          cursor: request.cursor,
        );
        _profilePostsGridUserId = request.userId;
      },
    );
    return result;
  }

  Future<Either<DomainException, FeedEntity>> getProfilePostsListDirect(
    GetProfilePostsRequest request,
  ) async {
    final result = await _repository.getProfilePostsList(request);
    result.fold(
      (_) {},
      (feed) {
        final currentFeed = _profilePostsListUserId == request.userId
            ? _profilePostsListCache
            : const FeedEntity.empty();
        _profilePostsListCache = _mergeFeedForCursor(
          current: currentFeed,
          incoming: feed,
          cursor: request.cursor,
        );
        _profilePostsListUserId = request.userId;
      },
    );
    return result;
  }

  Future<Either<DomainException, FeedEntity>> getMyProfilePostsListDirect(
    GetMyProfilePostsRequest request,
  ) async {
    final result = await _repository.getMyProfilePostsList(request);
    result.fold(
      (_) {},
      (feed) {
        _myProfilePostsListCache = _mergeFeedForCursor(
          current: _myProfilePostsListCache,
          incoming: feed,
          cursor: request.cursor,
        );
      },
    );
    return result;
  }

  Future<Either<DomainException, FeedEntity>> getInitialFeed({
    int limit = 20,
  }) async {
    return _repository.getFeed(FeedRequest(limit: limit));
  }

  Future<Either<DomainException, StoreSummaryEntity>>
      getStoreSummaryDirect() async {
    final result = await _repository.getStoreSummary();
    result.fold(
      (_) {},
      (storeSummary) {
        add(HomeEvent.applyStoreSummary(storeSummary: storeSummary));
      },
    );
    return result;
  }

  Future<Either<DomainException, List<ProfileSearchResultEntity>>>
      searchProfilesDirect(
    SearchProfilesRequest request,
  ) async {
    final normalizedQuery = request.normalizedQuery;
    if (normalizedQuery.isEmpty) {
      const emptyResults = <ProfileSearchResultEntity>[];
      add(
        const HomeEvent.applyProfileSearchResults(
          results: emptyResults,
        ),
      );
      return const Right(emptyResults);
    }

    final result = await _profileRepository.searchProfiles(
      request.copyWith(query: normalizedQuery),
    );
    result.fold(
      (_) {},
      (results) {
        add(HomeEvent.applyProfileSearchResults(results: results));
      },
    );
    return result;
  }

  Future<Either<DomainException, SealListEntity>> getPostSealsDirect(
    GetPostSealsRequest request,
  ) async {
    if (request.postId.startsWith('local-')) {
      return const Right(SealListEntity.empty());
    }
    return _repository.getPostSeals(request);
  }

  Future<Either<DomainException, SendPostSealResultEntity>> sendPostSealDirect(
    String postId,
    SendPostSealRequest request,
  ) async {
    if (postId.startsWith('local-')) {
      return const Right(SendPostSealResultEntity.empty());
    }

    if (_sendingSealPostIds.contains(postId)) {
      return Left(
        UnknownException(
          message: 'Silver honor is already being sent. Please wait.',
        ),
      );
    }

    _sendingSealPostIds.add(postId);

    try {
      final result = await _repository.sendPostSeal(
        PostIdRequest(postId: postId),
        request,
      );
      result.fold(
        (_) {},
        (sendResult) {
          add(
            HomeEvent.applyPostSealResult(
              postId: postId,
              result: sendResult,
            ),
          );
          add(const HomeEvent.loadStoreSummary());
        },
      );
      return result;
    } finally {
      _sendingSealPostIds.remove(postId);
    }
  }

  Future<Either<DomainException, ReportPostResultEntity>> reportPostDirect(
    PostIdRequest requestId,
    ReportPostRequest request,
  ) async {
    return _repository.reportPost(requestId, request);
  }

  Future<Either<DomainException, StatusResponseEntity>> updatePostDirect(
    String postId,
    UpdatePostRequest request,
  ) async {
    if (postId.startsWith('local-')) {
      _applyUpdatedPostToViewModel(postId: postId, request: request);
      return const Right(StatusResponseEntity(status: 'success'));
    }

    final result = await _repository.updatePost(
      PostIdRequest(postId: postId),
      request,
    );
    result.fold(
      (_) {},
      (_) {
        _applyUpdatedPostToViewModel(postId: postId, request: request);
      },
    );
    return result;
  }

  Future<Either<DomainException, StatusResponseEntity>> deletePostDirect(
    String postId,
  ) async {
    if (postId.startsWith('local-')) {
      _applyDeletedPostToViewModel(postId);
      return const Right(StatusResponseEntity(status: 'success'));
    }

    final result = await _repository.deletePost(PostIdRequest(postId: postId));
    result.fold(
      (_) {},
      (_) {
        _applyDeletedPostToViewModel(postId);
      },
    );
    return result;
  }

  Future<void> _applyPostSealResult(
    _ApplyPostSealResult event,
    Emitter emit,
  ) async {
    FeedEntity incrementSealCount(FeedEntity feed) {
      return feed.copyWith(
        items: feed.items.map((item) {
          if (item.postId != event.postId) {
            return item;
          }
          return item.copyWith(
            metrics: item.metrics.copyWith(
              silvers: item.metrics.silvers + 1,
            ),
          );
        }).toList(),
      );
    }

    final currentSummary = _viewModel.storeSummary;
    final nextBalance = currentSummary.balance.copyWith(
      silverBalance: event.result.newBalance,
    );

    _profilePostsListCache = incrementSealCount(_profilePostsListCache);
    _myProfilePostsListCache = incrementSealCount(_myProfilePostsListCache);

    _viewModel = _viewModel.copyWith(
      lastAction: StatusResponseEntity(
        status: event.result.status,
        message: event.result.ledgerEntryId,
      ),
      storeSummary: currentSummary.copyWith(balance: nextBalance),
      feed: incrementSealCount(_viewModel.feed),
    );
    emit(HomeState.loaded(viewModel: _viewModel));
  }

  Future<void> _loadStoreSummary(
    _LoadStoreSummary event,
    Emitter emit,
  ) async {
    final result = await _repository.getStoreSummary();
    result.fold(
      (error) => emit(HomeState.loadingError(error.message)),
      (storeSummary) {
        _viewModel = _viewModel.copyWith(storeSummary: storeSummary);
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _claimStoreDailyAccrual(
    _ClaimStoreDailyAccrual event,
    Emitter emit,
  ) async {
    final result = await _repository.claimStoreDailyAccrual(event.request);
    DomainException? claimError;
    ClaimDailyAccrualResultEntity? accrualResult;
    result.fold(
      (error) => claimError = error,
      (entity) => accrualResult = entity,
    );
    if (claimError != null) {
      emit(HomeState.loadingError(claimError!.message));
      return;
    }

    _viewModel = _viewModel.copyWith(
      lastStoreAccrualResult: accrualResult!,
    );

    final summaryResult = await _repository.getStoreSummary();
    summaryResult.fold(
      (_) {
        emit(HomeState.loaded(viewModel: _viewModel));
      },
      (storeSummary) {
        _viewModel = _viewModel.copyWith(storeSummary: storeSummary);
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _applyStoreSummary(
    _ApplyStoreSummary event,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.copyWith(storeSummary: event.storeSummary);
    emit(HomeState.loaded(viewModel: _viewModel));
  }

  Future<void> _searchProfiles(
    _SearchProfiles event,
    Emitter emit,
  ) async {
    final normalizedQuery = event.request.normalizedQuery;
    if (normalizedQuery.isEmpty) {
      _viewModel = _viewModel.copyWith(
        isProfileSearchLoading: false,
        profileSearchQuery: '',
        profileSearchError: '',
        profileSearchResults: const <ProfileSearchResultEntity>[],
      );
      emit(HomeState.loaded(viewModel: _viewModel));
      return;
    }

    _viewModel = _viewModel.copyWith(
      isProfileSearchLoading: true,
      profileSearchQuery: normalizedQuery,
      profileSearchError: '',
    );
    emit(HomeState.loaded(viewModel: _viewModel));

    final result = await _profileRepository.searchProfiles(
      event.request.copyWith(query: normalizedQuery),
    );
    result.fold(
      (error) {
        if (_viewModel.profileSearchQuery != normalizedQuery) return;
        _viewModel = _viewModel.copyWith(
          isProfileSearchLoading: false,
          profileSearchError: error.message,
          profileSearchResults: const <ProfileSearchResultEntity>[],
        );
        emit(HomeState.loaded(viewModel: _viewModel));
      },
      (results) {
        if (_viewModel.profileSearchQuery != normalizedQuery) return;
        _viewModel = _viewModel.copyWith(
          isProfileSearchLoading: false,
          profileSearchError: '',
          profileSearchResults: results,
        );
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _clearProfileSearch(Emitter emit) async {
    _viewModel = _viewModel.copyWith(
      isProfileSearchLoading: false,
      profileSearchQuery: '',
      profileSearchError: '',
      profileSearchResults: const <ProfileSearchResultEntity>[],
    );
    emit(HomeState.loaded(viewModel: _viewModel));
  }

  Map<String, dynamic> _profileSearchRecentItemToJson(
    ProfileSearchRecentItemEntity e,
  ) {
    return <String, dynamic>{
      'searchedAt': e.searchedAt.toIso8601String(),
      'profile': <String, dynamic>{
        'userId': e.profile.userId,
        'displayName': e.profile.displayName,
        'avatarUrl': e.profile.avatarUrl,
        'reputationScore': e.profile.reputationScore,
        'rankTier': e.profile.rankTier,
      },
    };
  }

  Future<void> _persistProfileSearchRecent() async {
    final prefs = KeyValueStorageImpl();
    final encoded = jsonEncode(
      _viewModel.profileSearchRecentItems
          .map(_profileSearchRecentItemToJson)
          .toList(growable: false),
    );
    await prefs.set<String>(_kProfileSearchRecentPrefsKey, encoded);
  }

  Future<List<ProfileSearchRecentItemEntity>>
      _readProfileSearchRecentFromStorage() async {
    final prefs = KeyValueStorageImpl();
    final raw = prefs.get<String>(_kProfileSearchRecentPrefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <ProfileSearchRecentItemEntity>[];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (dynamic e) => ProfileSearchRecentItemEntity.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <ProfileSearchRecentItemEntity>[];
    }
  }

  Future<void> _hydrateProfileSearchRecent(Emitter emit) async {
    final fromDisk = await _readProfileSearchRecentFromStorage();
    if (fromDisk.isEmpty) {
      return;
    }
    _viewModel = _viewModel.copyWith(profileSearchRecentItems: fromDisk);
    emit(
      state.map(
        initial: (_) => HomeState.loaded(viewModel: _viewModel),
        loading: (_) => HomeState.loading(viewModel: _viewModel),
        loadingError: (_) => HomeState.loaded(viewModel: _viewModel),
        loaded: (_) => HomeState.loaded(viewModel: _viewModel),
      ),
    );
  }

  Future<void> _addProfileSearchRecent(
    _AddProfileSearchRecent event,
    Emitter emit,
  ) async {
    final updatedItems = <ProfileSearchRecentItemEntity>[
      ProfileSearchRecentItemEntity(
        profile: event.result,
        searchedAt: DateTime.now(),
      ),
      ..._viewModel.profileSearchRecentItems.where(
        (item) => item.profile.userId != event.result.userId,
      ),
    ].take(10).toList();

    _viewModel = _viewModel.copyWith(profileSearchRecentItems: updatedItems);
    emit(HomeState.loaded(viewModel: _viewModel));
    await _persistProfileSearchRecent();
  }

  Future<void> _removeProfileSearchRecent(
    _RemoveProfileSearchRecent event,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.copyWith(
      profileSearchRecentItems: _viewModel.profileSearchRecentItems
          .where((item) => item.profile.userId != event.userId)
          .toList(),
    );
    emit(HomeState.loaded(viewModel: _viewModel));
    await _persistProfileSearchRecent();
  }

  Future<void> _clearProfileSearchRecent(Emitter emit) async {
    _viewModel = _viewModel.copyWith(
      profileSearchRecentItems: const <ProfileSearchRecentItemEntity>[],
    );
    emit(HomeState.loaded(viewModel: _viewModel));
    await _persistProfileSearchRecent();
  }

  Future<void> _applyProfileSearchResults(
    _ApplyProfileSearchResults event,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.copyWith(
      isProfileSearchLoading: false,
      profileSearchQuery: _viewModel.profileSearchQuery,
      profileSearchError: '',
      profileSearchResults: event.results,
    );
    emit(HomeState.loaded(viewModel: _viewModel));
  }

  Future<Either<DomainException, CommentResponseEntity>>
      toggleCommentLikeDirect(String commentId) async {
    final result = await _repository.toggleCommentLike(
      CommentIdRequest(commentId: commentId),
    );
    result.fold(
      (_) {},
      (updatedComment) {
        final updatedComments = _viewModel.comments.comments.map((comment) {
          if (comment.commentId != updatedComment.commentId) {
            return comment;
          }
          return updatedComment;
        }).toList();

        _viewModel = _viewModel.copyWith(
          comments: _viewModel.comments.copyWith(comments: updatedComments),
        );
      },
    );
    return result;
  }

  Future<Either<DomainException, MediaAttachmentRequest>>
      uploadCommentMediaDirect(
    UploadFeedMediaRequest request,
  ) async {
    return _repository.uploadFeedMedia(request);
  }

  Future<Either<DomainException, CommentResponseEntity>>
      createPostCommentDirect(
    String postId,
    CreateCommentRequest request,
  ) async {
    if (postId.startsWith('local-')) {
      return Right(const CommentResponseEntity.empty());
    }

    final result = await _repository.createPostComment(
      PostIdRequest(postId: postId),
      request,
    );
    result.fold(
      (_) {},
      (createdComment) {
        _applyCreatedCommentToViewModel(
          postId: postId,
          parentId: request.parentId,
          createdComment: createdComment,
        );
      },
    );
    return result;
  }

  Future<void> _createFeedPost(_CreateFeedPost event, Emitter emit) async {
    final Either<DomainException, PostResponseEntity> result =
        await _repository.createFeedPost(
      event.request,
      event.localMediaPayloads,
    );
    if (result.isLeft()) {
      result.fold(
        (error) => emit(HomeState.loadingError(error.message)),
        (_) {},
      );
      return;
    }

    result.fold(
      (_) {},
      (createdPost) {
        final ownCreatedPost = createdPost.copyWith(isOwnPost: true);
        final mergedLocalMediaPayloads = <LocalMediaPayload>[
          ..._viewModel.localMediaPayloads,
        ];
        for (final payload in event.localMediaPayloads) {
          final exists = mergedLocalMediaPayloads.any(
            (item) => item.localUrl == payload.localUrl,
          );
          if (!exists) {
            mergedLocalMediaPayloads.add(payload);
          }
        }
        _viewModel = _viewModel.copyWith(
          lastAction: const StatusResponseEntity(status: 'success'),
          localMediaPayloads: mergedLocalMediaPayloads,
          feed: _viewModel.feed.copyWith(
            items: [ownCreatedPost, ..._viewModel.feed.items],
          ),
        );
      },
    );
    emit(HomeState.loaded(viewModel: _viewModel));
  }

  Future<void> _getPostComments(
    _GetPostComments event,
    Emitter emit,
  ) async {
    if (event.request.postId.startsWith('local-')) {
      _viewModel = _viewModel.copyWith(
        comments: const ThreadedCommentsEntity.empty(),
      );
      emit(HomeState.loaded(viewModel: _viewModel));
      return;
    }

    _viewModel = _viewModel.copyWith(postCommentsError: '');
    emit(HomeState.loaded(viewModel: _viewModel));

    final Either<DomainException, ThreadedCommentsEntity> result =
        await _repository.getPostComments(event.request);
    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(
          comments: const ThreadedCommentsEntity.empty(),
          postCommentsError: error.message,
        );
        emit(HomeState.loaded(viewModel: _viewModel));
      },
      (comments) {
        _viewModel = _viewModel.copyWith(
          comments: comments,
          postCommentsError: '',
        );
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _createPostComment(
    _CreatePostComment event,
    Emitter emit,
  ) async {
    if (event.postId.startsWith('local-')) {
      emit(HomeState.loaded(viewModel: _viewModel));
      return;
    }

    final Either<DomainException, CommentResponseEntity> result =
        await _repository.createPostComment(
      PostIdRequest(postId: event.postId),
      event.request,
    );
    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(postCommentsError: error.message);
        emit(HomeState.loaded(viewModel: _viewModel));
      },
      (createdComment) {
        _applyCreatedCommentToViewModel(
          postId: event.postId,
          parentId: event.request.parentId,
          createdComment: createdComment,
        );
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  void _applyCreatedCommentToViewModel({
    required String postId,
    required String? parentId,
    required CommentResponseEntity createdComment,
  }) {
    List<CommentResponseEntity> updatedComments;
    if (parentId == null) {
      updatedComments = _prependUniqueComment(
        createdComment,
        _viewModel.comments.comments,
      );
    } else {
      final withParentReplyCount = _viewModel.comments.comments.map((comment) {
        if (comment.commentId != parentId) {
          return comment;
        }
        return comment.copyWith(replyCount: comment.replyCount + 1);
      }).toList();
      updatedComments = _prependUniqueComment(
        createdComment,
        withParentReplyCount,
      );
    }

    final updatedPosts = _viewModel.feed.items.map((post) {
      if (post.postId != postId) return post;
      return post.copyWith(
        metrics: post.metrics.copyWith(
          comments: post.metrics.comments + 1,
        ),
      );
    }).toList();

    _profilePostsListCache = _incrementCommentCountInFeed(
      _profilePostsListCache,
      postId,
    );
    _myProfilePostsListCache = _incrementCommentCountInFeed(
      _myProfilePostsListCache,
      postId,
    );

    _viewModel = _viewModel.copyWith(
      lastAction: const StatusResponseEntity(status: 'success'),
      postCommentsError: '',
      comments: _viewModel.comments.copyWith(
        comments: updatedComments,
      ),
      feed: _viewModel.feed.copyWith(items: updatedPosts),
    );
  }

  List<CommentResponseEntity> _prependUniqueComment(
    CommentResponseEntity comment,
    List<CommentResponseEntity> source,
  ) {
    final exists = source.any((item) => item.commentId == comment.commentId);
    if (exists) return source;
    return [comment, ...source];
  }

  Future<void> _getPostLikes(_GetPostLikes event, Emitter emit) async {
    if (event.request.postId.startsWith('local-')) {
      _viewModel = _viewModel.copyWith(
        likes: const InteractionListEntity.empty(),
      );
      emit(HomeState.loaded(viewModel: _viewModel));
      return;
    }

    final Either<DomainException, InteractionListEntity> result =
        await _repository.getPostLikes(event.request);
    result.fold(
      (_) {
        _viewModel = _viewModel.copyWith(
          likes: const InteractionListEntity.empty(),
        );
        emit(HomeState.loaded(viewModel: _viewModel));
      },
      (likes) {
        _viewModel = _viewModel.copyWith(likes: likes);
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _togglePostLike(
    _TogglePostLike event,
    Emitter emit,
  ) async {
    if (event.postId.startsWith('local-')) {
      final items = _viewModel.feed.items.map((item) {
        if (item.postId != event.postId) return item;
        final isLiked = item.viewerHasLiked;
        final currentLikes = item.metrics.likes;
        final nextLikes = isLiked
            ? (currentLikes > 0 ? currentLikes - 1 : 0)
            : currentLikes + 1;
        return item.copyWith(
          viewerHasLiked: !isLiked,
          metrics: item.metrics.copyWith(likes: nextLikes),
        );
      }).toList();

      _viewModel = _viewModel.copyWith(
        feed: _viewModel.feed.copyWith(items: items),
      );
      emit(HomeState.loaded(viewModel: _viewModel));
      return;
    }

    final Either<DomainException, PostResponseEntity> result =
        await _repository.togglePostLike(
      PostIdRequest(postId: event.postId),
    );
    result.fold(
      (_) => emit(HomeState.loaded(viewModel: _viewModel)),
      (updatedPost) {
        _profilePostsListCache = _replacePostInFeed(
          _profilePostsListCache,
          updatedPost,
        );
        _myProfilePostsListCache = _replacePostInFeed(
          _myProfilePostsListCache,
          updatedPost,
        );

        _viewModel = _viewModel.copyWith(
          lastAction: const StatusResponseEntity(status: 'success'),
          feed: _replacePostInFeed(_viewModel.feed, updatedPost),
        );
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  FeedEntity _mergeFeedForCursor({
    required FeedEntity current,
    required FeedEntity incoming,
    required String? cursor,
  }) {
    final trimmedCursor = cursor?.trim() ?? '';
    if (trimmedCursor.isEmpty) {
      return incoming;
    }

    final mergedItems = <PostResponseEntity>[
      ...current.items,
      for (final item in incoming.items)
        if (!current.items.any((existing) => existing.postId == item.postId))
          item,
    ];

    return current.copyWith(
      items: mergedItems,
      nextCursor: incoming.nextCursor,
    );
  }

  void _applyUpdatedPostToViewModel({
    required String postId,
    required UpdatePostRequest request,
  }) {
    _profilePostsGridCache = _applyPostUpdateToFeed(
      _profilePostsGridCache,
      postId: postId,
      request: request,
    );
    _profilePostsListCache = _applyPostUpdateToFeed(
      _profilePostsListCache,
      postId: postId,
      request: request,
    );
    _myProfilePostsListCache = _applyPostUpdateToFeed(
      _myProfilePostsListCache,
      postId: postId,
      request: request,
    );
    _viewModel = _viewModel.copyWith(
      lastAction: const StatusResponseEntity(status: 'success'),
      feed: _applyPostUpdateToFeed(
        _viewModel.feed,
        postId: postId,
        request: request,
      ),
    );
  }

  FeedEntity _applyPostUpdateToFeed(
    FeedEntity feed, {
    required String postId,
    required UpdatePostRequest request,
  }) {
    final hasChanges = request.hideLikesCount != null ||
        (request.commentPermission?.trim().isNotEmpty ?? false);
    if (!hasChanges) {
      return feed;
    }

    final hasPost = feed.items.any((item) => item.postId == postId);
    if (!hasPost) {
      return feed;
    }

    final trimmedCommentPermission = request.commentPermission?.trim() ?? '';

    return feed.copyWith(
      items: feed.items.map((item) {
        if (item.postId != postId) {
          return item;
        }

        var updatedItem = item;

        if (request.hideLikesCount != null) {
          updatedItem = updatedItem.copyWith(
            hideLikesCount: request.hideLikesCount!,
          );
        }

        if (trimmedCommentPermission.isNotEmpty) {
          updatedItem = updatedItem.copyWith(
            permissions: updatedItem.permissions.copyWith(
              canComment: trimmedCommentPermission != 'NO_ONE',
            ),
          );
        }

        return updatedItem;
      }).toList(),
    );
  }

  void _applyDeletedPostToViewModel(String postId) {
    _profilePostsGridCache =
        _removePostFromFeed(_profilePostsGridCache, postId);
    _profilePostsListCache =
        _removePostFromFeed(_profilePostsListCache, postId);
    _myProfilePostsListCache =
        _removePostFromFeed(_myProfilePostsListCache, postId);
    _viewModel = _viewModel.copyWith(
      lastAction: const StatusResponseEntity(status: 'success'),
      feed: _removePostFromFeed(_viewModel.feed, postId),
    );
  }

  FeedEntity _incrementCommentCountInFeed(FeedEntity feed, String postId) {
    return feed.copyWith(
      items: feed.items.map((item) {
        if (item.postId != postId) return item;
        return item.copyWith(
          metrics: item.metrics.copyWith(
            comments: item.metrics.comments + 1,
          ),
        );
      }).toList(),
    );
  }

  FeedEntity _replacePostInFeed(
      FeedEntity feed, PostResponseEntity updatedPost) {
    return feed.copyWith(
      items: feed.items.map((item) {
        if (item.postId != updatedPost.postId) return item;
        return _mergePostForLikeUpdate(
          current: item,
          incoming: updatedPost,
        );
      }).toList(),
    );
  }

  FeedEntity _mergeIncomingFeedWithCurrent({
    required FeedEntity current,
    required FeedEntity incoming,
  }) {
    if (current.items.isEmpty || incoming.items.isEmpty) {
      return incoming;
    }

    final mergedItems = incoming.items.map((incomingPost) {
      PostResponseEntity? currentPost;
      for (final item in current.items) {
        if (item.postId == incomingPost.postId) {
          currentPost = item;
          break;
        }
      }
      if (currentPost == null) {
        return incomingPost;
      }
      return _mergePostForLikeUpdate(
        current: currentPost,
        incoming: incomingPost,
      );
    }).toList(growable: false);

    return incoming.copyWith(items: mergedItems);
  }

  PostResponseEntity _mergePostForLikeUpdate({
    required PostResponseEntity current,
    required PostResponseEntity incoming,
  }) {
    final incomingAvatar = incoming.author.profilePicUrl.trim();

    final mergedAuthor = incoming.author.copyWith(
      id: incoming.author.id.trim().isEmpty
          ? current.author.id
          : incoming.author.id,
      username: incoming.author.username.trim().isEmpty
          ? current.author.username
          : incoming.author.username,
      fullName: incoming.author.fullName.trim().isEmpty
          ? current.author.fullName
          : incoming.author.fullName,
      profilePicUrl: incomingAvatar.isEmpty
          ? current.author.profilePicUrl
          : incoming.author.profilePicUrl,
      rank: incoming.author.rank.trim().isEmpty
          ? current.author.rank
          : incoming.author.rank,
      rankSubLevel: incoming.author.rankSubLevel.trim().isEmpty
          ? current.author.rankSubLevel
          : incoming.author.rankSubLevel,
    );

    final incomingTimeAgo = incoming.timeAgo.trim().toLowerCase();
    final currentTimeAgo = current.timeAgo.trim().toLowerCase();
    final shouldKeepCurrentTimeAgo = incomingTimeAgo.isEmpty ||
        (incomingTimeAgo == 'just now' &&
            currentTimeAgo.isNotEmpty &&
            currentTimeAgo != 'just now');

    return incoming.copyWith(
      author: mergedAuthor,
      timeAgo: shouldKeepCurrentTimeAgo ? current.timeAgo : incoming.timeAgo,
      contentText: incoming.contentText.trim().isEmpty
          ? current.contentText
          : incoming.contentText,
      mediaAttachments: incoming.mediaAttachments.isEmpty
          ? current.mediaAttachments
          : incoming.mediaAttachments,
      visibility: incoming.visibility.trim().isEmpty
          ? current.visibility
          : incoming.visibility,
    );
  }

  FeedEntity _removePostFromFeed(FeedEntity feed, String postId) {
    return feed.copyWith(
      items: feed.items.where((item) => item.postId != postId).toList(),
    );
  }

  @override
  Future<void> close() {
    getIt.resetBloc(this);
    return super.close();
  }
}
