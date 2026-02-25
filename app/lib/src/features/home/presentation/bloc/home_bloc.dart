import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/base/base_bloc/bloc/base_bloc.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/injectable/service_register_proxy.dart';
import 'package:app/src/features/home/data/repositories/home_repository_impl.dart';
import 'package:app/src/features/home/domain/entities/comment_entity.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:app/src/features/home/domain/repositories/i_home_repository.dart';

part 'home_bloc.freezed.dart';
part 'home_event.dart';
part 'home_state.dart';

@injectable
class HomeBloc extends BaseBloc<HomeEvent, HomeState> {
  HomeBloc(@Named.from(HomeRepositoryImpl) this._repository)
      : super(const _Initial());

  final IHomeRepository _repository;
  HomeViewModel _viewModel = HomeViewModel();

  @override
  Future<void> onEventHandler(HomeEvent event, Emitter emit) async {
    await event.when(
      loadPosts: () => _loadPosts(event as _LoadPosts, emit),
      createPost: (_) => _createPost(event as _CreatePost, emit),
      likePost: (_) => _likePost(event as _LikePost, emit),
      unlikePost: (_) => _unlikePost(event as _UnlikePost, emit),
      loadComments: (_) => _loadComments(event as _LoadComments, emit),
      addComment: (_, __, ___) => _addComment(event as _AddComment, emit),
      likeComment: (_) => _likeComment(event as _LikeComment, emit),
      unlikeComment: (_) => _unlikeComment(event as _UnlikeComment, emit),
      setReplyTarget: (_) => _setReplyTarget(event as _SetReplyTarget, emit),
      toggleRepliesVisibility: (_) => _toggleRepliesVisibility(
        event as _ToggleRepliesVisibility,
        emit,
      ),
      addCommentPhoto: (_, __) => _addCommentPhoto(
        event as _AddCommentPhoto,
        emit,
      ),
      removeCommentPhoto: (_) => _removeCommentPhoto(
        event as _RemoveCommentPhoto,
        emit,
      ),
      clearCommentPhotos: () => _clearCommentPhotos(emit),
      addPostPhoto: (_, __) => _addPostPhoto(event as _AddPostPhoto, emit),
      removePostPhoto: (_) => _removePostPhoto(event as _RemovePostPhoto, emit),
      clearPostPhotos: () => _clearPostPhotos(emit),
    );
  }

  Future<void> _loadPosts(_LoadPosts event, Emitter emit) async {
    try {
      emit(HomeState.loading(viewModel: _viewModel));
      final result = await _repository.getPosts();

      result.fold(
        (error) => emit(HomeState.loadingError(error.message)),
        (posts) {
          _viewModel = _viewModel.copyWith(posts: posts);
          emit(HomeState.loaded(viewModel: _viewModel));
        },
      );
    } catch (e) {
      emit(HomeState.loadingError(e.toString()));
    }
  }

  Future<void> _likePost(_LikePost event, Emitter emit) async {
    final postIndex = _viewModel.posts.indexWhere((p) => p.id == event.postId);
    if (postIndex == -1) {
      emit(HomeState.loadingError('Post not found: ${event.postId}'));
      return;
    }

    // Optimistic update
    final post = _viewModel.posts[postIndex];
    final updatedPost = post.copyWith(
      isLiked: true,
      likesCount: post.likesCount + 1,
    );
    _viewModel = _viewModel.copyWithPost(updatedPost);
    emit(HomeState.loaded(viewModel: _viewModel));

    // Actual API call
    final result = await _repository.likePost(event.postId);
    result.fold(
      (error) {
        // Rollback on error
        final revertedPost = post.copyWith(
          isLiked: false,
          likesCount: post.likesCount,
        );
        _viewModel = _viewModel.copyWithPost(revertedPost);
        emit(HomeState.loadingError(error.message));
      },
      (actualPost) {
        // Update with actual data from server
        _viewModel = _viewModel.copyWithPost(actualPost);
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _createPost(_CreatePost event, Emitter emit) async {
    final hasContent = event.content.trim().isNotEmpty;
    final hasPhotos = _viewModel.postComposerPhotos.isNotEmpty;
    if (!hasContent && !hasPhotos) {
      emit(const HomeState.loadingError('Post content is empty'));
      return;
    }

    final result = await _repository.createPost(
      event.content.trim(),
      _viewModel.postComposerPhotos.map((photo) => photo.fileName).toList(),
    );

    result.fold(
      (error) => emit(HomeState.loadingError(error.message)),
      (post) {
        _viewModel = _viewModel.prependPost(post).copyWith(
          postComposerPhotos: const [],
        );
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _unlikePost(_UnlikePost event, Emitter emit) async {
    final postIndex = _viewModel.posts.indexWhere((p) => p.id == event.postId);
    if (postIndex == -1) {
      emit(HomeState.loadingError('Post not found: ${event.postId}'));
      return;
    }

    // Optimistic update
    final post = _viewModel.posts[postIndex];
    final updatedPost = post.copyWith(
      isLiked: false,
      likesCount: post.likesCount > 0 ? post.likesCount - 1 : 0,
    );
    _viewModel = _viewModel.copyWithPost(updatedPost);
    emit(HomeState.loaded(viewModel: _viewModel));

    // Actual API call
    final result = await _repository.unlikePost(event.postId);
    result.fold(
      (error) {
        // Rollback on error
        final revertedPost = post.copyWith(
          isLiked: true,
          likesCount: post.likesCount,
        );
        _viewModel = _viewModel.copyWithPost(revertedPost);
        emit(HomeState.loadingError(error.message));
      },
      (actualPost) {
        // Update with actual data from server
        _viewModel = _viewModel.copyWithPost(actualPost);
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _loadComments(_LoadComments event, Emitter emit) async {
    emit(HomeState.loading(viewModel: _viewModel));

    final result = await _repository.getComments(event.postId);
    result.fold(
      (error) => emit(HomeState.loadingError(error.message)),
      (comments) {
        _viewModel = _viewModel.copyWith(
          commentsByPost: {
            ..._viewModel.commentsByPost,
            event.postId: comments
          },
          currentlyViewingPostId: event.postId,
        );
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _addComment(_AddComment event, Emitter emit) async {
    final result = await _repository.addComment(
      event.postId,
      event.content,
      event.parentCommentId,
      _viewModel.composerPhotos.map((photo) => photo.fileName).toList(),
    );
    result.fold(
      (error) => emit(HomeState.loadingError(error.message)),
      (newComment) {
        // Add comment to state
        _viewModel = _viewModel.addCommentToPost(
          newComment,
          event.postId,
          parentCommentId: event.parentCommentId,
        );

        if (event.parentCommentId != null) {
          _viewModel = _viewModel.incrementRepliesCount(
            event.postId,
            event.parentCommentId!,
          );
        }

        // Update post's comment count only if post is present in state.
        final postIndex = _viewModel.posts.indexWhere(
          (p) => p.id == event.postId,
        );
        if (postIndex != -1) {
          final post = _viewModel.posts[postIndex];
          final updatedPost = post.copyWith(
            commentsCount: post.commentsCount + 1,
          );
          _viewModel = _viewModel.copyWithPost(updatedPost);
        }

        _viewModel = _viewModel.copyWith(replyingToCommentId: null);
        _viewModel = _viewModel.copyWith(composerPhotos: const []);
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _likeComment(_LikeComment event, Emitter emit) async {
    // Find the comment and post
    CommentEntity? targetComment;
    String? targetPostId;

    for (final entry in _viewModel.commentsByPost.entries) {
      try {
        final comment = entry.value.firstWhere((c) => c.id == event.commentId);
        targetComment = comment;
        targetPostId = entry.key;
        break;
      } catch (e) {
        continue;
      }
    }

    if (targetComment == null || targetPostId == null) return;

    // Optimistic update
    final updatedComment = targetComment.copyWith(
      isLiked: true,
      likesCount: targetComment.likesCount + 1,
    );
    _viewModel = _viewModel.copyWithComment(updatedComment, targetPostId);
    emit(HomeState.loaded(viewModel: _viewModel));

    // Actual API call
    final result = await _repository.likeComment(event.commentId);
    result.fold(
      (error) {
        // Rollback on error
        _viewModel = _viewModel.copyWithComment(targetComment!, targetPostId!);
        emit(HomeState.loadingError(error.message));
      },
      (actualComment) {
        // Update with actual data from server
        _viewModel = _viewModel.copyWithComment(actualComment, targetPostId!);
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _unlikeComment(_UnlikeComment event, Emitter emit) async {
    // Find the comment and post
    CommentEntity? targetComment;
    String? targetPostId;

    for (final entry in _viewModel.commentsByPost.entries) {
      try {
        final comment = entry.value.firstWhere((c) => c.id == event.commentId);
        targetComment = comment;
        targetPostId = entry.key;
        break;
      } catch (e) {
        continue;
      }
    }

    if (targetComment == null || targetPostId == null) return;

    // Optimistic update
    final updatedComment = targetComment.copyWith(
      isLiked: false,
      likesCount:
          targetComment.likesCount > 0 ? targetComment.likesCount - 1 : 0,
    );
    _viewModel = _viewModel.copyWithComment(updatedComment, targetPostId);
    emit(HomeState.loaded(viewModel: _viewModel));

    // Actual API call
    final result = await _repository.unlikeComment(event.commentId);
    result.fold(
      (error) {
        // Rollback on error
        _viewModel = _viewModel.copyWithComment(targetComment!, targetPostId!);
        emit(HomeState.loadingError(error.message));
      },
      (actualComment) {
        // Update with actual data from server
        _viewModel = _viewModel.copyWithComment(actualComment, targetPostId!);
        emit(HomeState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _setReplyTarget(_SetReplyTarget event, Emitter emit) async {
    _viewModel = _viewModel.copyWith(replyingToCommentId: event.commentId);
    emit(HomeState.loaded(viewModel: _viewModel));
  }

  Future<void> _toggleRepliesVisibility(
    _ToggleRepliesVisibility event,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.toggleRepliesVisibility(event.commentId);
    emit(HomeState.loaded(viewModel: _viewModel));
  }

  Future<void> _addCommentPhoto(_AddCommentPhoto event, Emitter emit) async {
    _viewModel = _viewModel.addComposerPhoto(
      CommentComposerPhoto(bytes: event.bytes, fileName: event.fileName),
    );
    emit(HomeState.loaded(viewModel: _viewModel));
  }

  Future<void> _removeCommentPhoto(
    _RemoveCommentPhoto event,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.removeComposerPhoto(event.fileName);
    emit(HomeState.loaded(viewModel: _viewModel));
  }

  Future<void> _clearCommentPhotos(Emitter emit) async {
    _viewModel = _viewModel.copyWith(composerPhotos: const []);
    emit(HomeState.loaded(viewModel: _viewModel));
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

  @override
  Future<void> close() {
    getIt.resetBloc(this);
    return super.close();
  }
}
