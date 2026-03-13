import 'dart:typed_data';

import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/base/base_bloc/bloc/base_bloc.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/injectable/service_register_proxy.dart';
import 'package:app/src/features/home/data/repositories/home_repository_impl.dart';
import 'package:app/src/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:app/src/features/home/domain/entities/claim_daily_accrual_result_entity.dart';
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
import 'package:app/src/features/home/domain/requests/get_post_seals_request.dart';
import 'package:app/src/features/home/domain/requests/media_attachment_request.dart';
import 'package:app/src/features/home/domain/requests/post_id_request.dart';
import 'package:app/src/features/home/domain/requests/report_post_request.dart';
import 'package:app/src/features/home/domain/requests/send_post_seal_request.dart';
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
  HomeBloc(
    @Named.from(HomeRepositoryImpl) this._repository,
    @Named.from(ProfileRepositoryImpl) this._profileRepository,
  )
      : super(const _Initial());

  final IHomeRepository _repository;
  final IProfileRepository _profileRepository;
  HomeViewModel _viewModel = HomeViewModel();
  @override
  Future<void> onEventHandler(HomeEvent event, Emitter emit) async {
    await event.when(
      loadFeed: (_) => _loadFeed(event as _LoadFeed, emit),
      addPostPhoto: (_, __) => _addPostPhoto(event as _AddPostPhoto, emit),
      removePostPhoto: (_) => _removePostPhoto(event as _RemovePostPhoto, emit),
      clearPostPhotos: () => _clearPostPhotos(emit),
      loadNotifications: () =>
          _loadNotifications(event as _LoadNotifications, emit),
      loadFeedState: () => _loadFeedState(event as _LoadFeedState, emit),
      syncFeedState: (_, __) => _syncFeedState(event as _SyncFeedState, emit),
      createFeedPost: (_, __) =>
          _createFeedPost(event as _CreateFeedPost, emit),
      getPostComments: (_) =>
          _getPostComments(event as _GetPostComments, emit),
      createPostComment: (_, __) =>
          _createPostComment(event as _CreatePostComment, emit),
      getPostLikes: (_) => _getPostLikes(event as _GetPostLikes, emit),
      togglePostLike: (_) =>
          _togglePostLike(event as _TogglePostLike, emit),
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
      searchProfiles: (_) =>
          _searchProfiles(event as _SearchProfiles, emit),
      clearProfileSearch: () => _clearProfileSearch(emit),
      addProfileSearchRecent: (_) =>
          _addProfileSearchRecent(event as _AddProfileSearchRecent, emit),
      removeProfileSearchRecent: (_) => _removeProfileSearchRecent(
        event as _RemoveProfileSearchRecent,
        emit,
      ),
      clearProfileSearchRecent: () => _clearProfileSearchRecent(emit),
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
        _viewModel = _viewModel.copyWith(feed: feed);
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

  Future<Either<DomainException, FeedEntity>> getInitialFeed({
    int limit = 20,
  }) async {
    return _repository.getFeed(FeedRequest(limit: limit));
  }

  Future<Either<DomainException, StoreSummaryEntity>> getStoreSummaryDirect()
      async {
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
    final trimmedQuery = request.query.trim();
    if (trimmedQuery.isEmpty) {
      const emptyResults = <ProfileSearchResultEntity>[];
      add(
        const HomeEvent.applyProfileSearchResults(
          results: emptyResults,
        ),
      );
      return const Right(emptyResults);
    }

    final result = await _profileRepository.searchProfiles(request);
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
      },
    );
    return result;
  }

  Future<Either<DomainException, ReportPostResultEntity>> reportPostDirect(
    PostIdRequest requestId,
    ReportPostRequest request,
  ) async {
    return _repository.reportPost(requestId, request);
  }

  Future<void> _applyPostSealResult(
    _ApplyPostSealResult event,
    Emitter emit,
  ) async {
    final updatedItems = _viewModel.feed.items.map((item) {
      if (item.postId != event.postId) return item;
      return item.copyWith(
        metrics: item.metrics.copyWith(
          silvers: item.metrics.silvers + 1,
        ),
      );
    }).toList();

    _viewModel = _viewModel.copyWith(
      lastAction: StatusResponseEntity(
        status: event.result.status,
        message: event.result.ledgerEntryId,
      ),
      feed: _viewModel.feed.copyWith(items: updatedItems),
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
    final trimmedQuery = event.request.query.trim();
    if (trimmedQuery.isEmpty) {
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
      profileSearchQuery: trimmedQuery,
      profileSearchError: '',
    );
    emit(HomeState.loaded(viewModel: _viewModel));

    final result = await _profileRepository.searchProfiles(event.request);
    result.fold(
      (error) {
        if (_viewModel.profileSearchQuery != trimmedQuery) return;
        _viewModel = _viewModel.copyWith(
          isProfileSearchLoading: false,
          profileSearchError: error.message,
          profileSearchResults: const <ProfileSearchResultEntity>[],
        );
        emit(HomeState.loaded(viewModel: _viewModel));
      },
      (results) {
        if (_viewModel.profileSearchQuery != trimmedQuery) return;
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
  }

  Future<void> _clearProfileSearchRecent(Emitter emit) async {
    _viewModel = _viewModel.copyWith(
      profileSearchRecentItems: const <ProfileSearchRecentItemEntity>[],
    );
    emit(HomeState.loaded(viewModel: _viewModel));
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

  Future<Either<DomainException, CommentResponseEntity>> createPostCommentDirect(
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
            items: [createdPost, ..._viewModel.feed.items],
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

    final Either<DomainException, ThreadedCommentsEntity> result =
        await _repository.getPostComments(event.request);
    result.fold(
      (error) => emit(HomeState.loadingError(error.message)),
      (comments) {
        _viewModel = _viewModel.copyWith(comments: comments);
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
      (error) => emit(HomeState.loadingError(error.message)),
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
      final withParentReplyCount = _viewModel.comments.comments
          .map((comment) {
            if (comment.commentId != parentId) {
              return comment;
            }
            return comment.copyWith(replyCount: comment.replyCount + 1);
          })
          .toList();
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

    _viewModel = _viewModel.copyWith(
      lastAction: const StatusResponseEntity(status: 'success'),
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
      (error) => emit(HomeState.loadingError(error.message)),
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
      (error) => emit(HomeState.loadingError(error.message)),
      (updatedPost) {
        final items = _viewModel.feed.items.map((item) {
          if (item.postId != event.postId) return item;
          return updatedPost;
        }).toList();

        _viewModel = _viewModel.copyWith(
          lastAction: const StatusResponseEntity(status: 'success'),
          feed: _viewModel.feed.copyWith(items: items),
        );
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  @override
  Future<void> close() {
    getIt.resetBloc(this);
    return super.close();
  }
}
