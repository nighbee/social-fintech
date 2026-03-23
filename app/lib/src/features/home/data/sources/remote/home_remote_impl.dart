import 'package:app/src/core/api/client/dio/dio_client.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/home/data/models/comment_dto.dart';
import 'package:app/src/features/home/data/models/post_dto.dart';
import 'package:app/src/features/home/data/sources/remote/i_home_remote.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@named
@LazySingleton(as: IHomeRemote)
class HomeRemoteImpl implements IHomeRemote {
  HomeRemoteImpl(@Named.from(DioClient) this._restClient);

  final RestClient _restClient;

  final Map<String, List<CommentDto>> _mockComments = {};
  List<PostDto>? _mockPosts;
  int _postIdCounter = 1000;
  int _commentIdCounter = 1;

  List<CommentDto> _getMockCommentsForPost(String postId) {
    if (!_mockComments.containsKey(postId)) {
      final topCommentId = 'comment-${_commentIdCounter++}';
      final secondCommentId = 'comment-${_commentIdCounter++}';
      final replyOneId = 'comment-${_commentIdCounter++}';
      final replyTwoId = 'comment-${_commentIdCounter++}';
      _mockComments[postId] = [
        CommentDto(
          id: topCommentId,
          postId: postId,
          userId: 'user-5',
          username: 'Alice Reader',
          userAvatar: 'https://i.pravatar.cc/150?img=20',
          content: 'Great post! Really enjoyed reading this.',
          imageUrls: const [],
          likesCount: 5,
          isLiked: false,
          repliesCount: 2,
          createdAt: DateTime.now()
              .subtract(const Duration(minutes: 30))
              .toIso8601String(),
        ),
        CommentDto(
          id: replyOneId,
          postId: postId,
          parentCommentId: topCommentId,
          rootCommentId: topCommentId,
          userId: 'user-7',
          username: 'Merey Zhumagul',
          userAvatar: 'https://i.pravatar.cc/150?img=45',
          content: 'Nice take!',
          imageUrls: const [],
          likesCount: 1,
          isLiked: false,
          repliesCount: 0,
          createdAt: DateTime.now()
              .subtract(const Duration(minutes: 20))
              .toIso8601String(),
        ),
        CommentDto(
          id: replyTwoId,
          postId: postId,
          parentCommentId: topCommentId,
          rootCommentId: topCommentId,
          userId: 'user-8',
          username: 'Zhanar Yesmoldayeva',
          userAvatar: 'https://i.pravatar.cc/150?img=46',
          content: 'Awesome!',
          imageUrls: const [],
          likesCount: 0,
          isLiked: false,
          repliesCount: 0,
          createdAt: DateTime.now()
              .subtract(const Duration(minutes: 10))
              .toIso8601String(),
        ),
        CommentDto(
          id: secondCommentId,
          postId: postId,
          userId: 'user-6',
          username: 'Bob BookLover',
          userAvatar: 'https://i.pravatar.cc/150?img=33',
          content: 'This is exactly what I needed to see today!',
          imageUrls: const [
            'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400',
          ],
          likesCount: 2,
          isLiked: true,
          repliesCount: 0,
          createdAt: DateTime.now()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        ),
      ];
    }
    return _mockComments[postId]!;
  }

  Future<void> _ensureMockPostsLoaded() async {
    _mockPosts ??= [
      PostDto(
        id: 'post-1',
        userId: 'user-1',
        username: 'Ayaulym Yesmoldayeva',
        userAvatar: 'https://i.pravatar.cc/150?img=1',
        content: 'A good music and a good book makes life truly... see more',
        imageUrls: [
          'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=400',
          'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=400',
          'https://images.unsplash.com/photo-1495446815901-a7297e633e8d?w=400',
        ],
        likesCount: 29,
        commentsCount: 44,
        createdAt:
            DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      ),
      PostDto(
        id: 'post-2',
        userId: 'user-2',
        username: 'John Bookworm',
        userAvatar: 'https://i.pravatar.cc/150?img=12',
        content: 'Just finished "The Great Gatsby". What a masterpiece!',
        imageUrls: [
          'https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=400',
        ],
        likesCount: 87,
        commentsCount: 23,
        createdAt:
            DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      ),
      PostDto(
        id: 'post-3',
        userId: 'user-3',
        username: 'Sarah Reader',
        userAvatar: 'https://i.pravatar.cc/150?img=5',
        content:
            'My cozy reading corner is finally complete! Perfect spot for weekend reading sessions.',
        imageUrls: [
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400',
        ],
        likesCount: 156,
        commentsCount: 67,
        createdAt:
            DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(),
      ),
      PostDto(
        id: 'post-4',
        userId: 'user-4',
        username: 'Mike Literature',
        userAvatar: 'https://i.pravatar.cc/150?img=8',
        content: 'Currently reading 5 books at once. Is that normal?',
        imageUrls: [],
        likesCount: 42,
        commentsCount: 18,
        createdAt: DateTime.now()
            .subtract(const Duration(hours: 12))
            .toIso8601String(),
      ),
    ];
  }

  @override
  Future<Either<DomainException, List<PostDto>>> getPosts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _ensureMockPostsLoaded();
    return Right(List<PostDto>.from(_mockPosts!));
  }

  @override
  Future<Either<DomainException, PostDto>> createPost(
    String content,
    List<String> imageFileNames,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _ensureMockPostsLoaded();

    final post = PostDto(
      id: 'post-${_postIdCounter++}',
      userId: 'current-user',
      username: 'You',
      userAvatar: 'https://i.pravatar.cc/150?img=50',
      content: content,
      imageUrls: imageFileNames
          .map(
            (name) =>
                'https://picsum.photos/seed/${Uri.encodeComponent(name)}/900/900',
          )
          .toList(),
      likesCount: 0,
      commentsCount: 0,
      isLiked: false,
      createdAt: DateTime.now().toIso8601String(),
    );

    _mockPosts = [post, ..._mockPosts!];
    return Right(post);
  }

  @override
  Future<Either<DomainException, PostDto>> likePost(String postId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _ensureMockPostsLoaded();

    final index = _mockPosts!.indexWhere((post) => post.id == postId);
    if (index == -1) {
      return Left(UnknownException(message: 'Post not found'));
    }

    final post = _mockPosts![index];
    if (post.isLiked) {
      return Right(post);
    }

    final updated = post.copyWith(
      likesCount: post.likesCount + 1,
      isLiked: true,
    );
    _mockPosts![index] = updated;
    return Right(updated);
  }

  @override
  Future<Either<DomainException, PostDto>> unlikePost(String postId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _ensureMockPostsLoaded();

    final index = _mockPosts!.indexWhere((post) => post.id == postId);
    if (index == -1) {
      return Left(UnknownException(message: 'Post not found'));
    }

    final post = _mockPosts![index];
    if (!post.isLiked) {
      return Right(post);
    }

    final updated = post.copyWith(
      likesCount: post.likesCount > 0 ? post.likesCount - 1 : 0,
      isLiked: false,
    );
    _mockPosts![index] = updated;
    return Right(updated);
  }

  @override
  Future<Either<DomainException, List<CommentDto>>> getComments(
    String postId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final comments = _getMockCommentsForPost(postId);
    return Right(comments);
  }

  @override
  Future<Either<DomainException, CommentDto>> addComment(
    String postId,
    String content,
    String? parentCommentId,
    List<String> imageFileNames,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final existing = _getMockCommentsForPost(postId);
    String? rootCommentId;
    if (parentCommentId != null) {
      final parentIndex = existing.indexWhere((c) => c.id == parentCommentId);
      if (parentIndex != -1) {
        final parent = existing[parentIndex];
        rootCommentId = parent.rootCommentId ?? parent.id;
        existing[parentIndex] = parent.copyWith(
          repliesCount: parent.repliesCount + 1,
        );
      }
    }

    final newComment = CommentDto(
      id: 'comment-${_commentIdCounter++}',
      postId: postId,
      parentCommentId: parentCommentId,
      rootCommentId: rootCommentId,
      userId: 'current-user',
      username: 'You',
      userAvatar: null,
      content: content,
      imageUrls: imageFileNames
          .map(
            (name) =>
                'https://picsum.photos/seed/${Uri.encodeComponent(name)}/500/500',
          )
          .toList(),
      likesCount: 0,
      isLiked: false,
      repliesCount: 0,
      createdAt: DateTime.now().toIso8601String(),
    );

    if (parentCommentId == null) {
      _mockComments[postId] = [newComment, ...existing];
    } else {
      _mockComments[postId] = [...existing, newComment];
    }

    return Right(newComment);
  }

  @override
  Future<Either<DomainException, CommentDto>> likeComment(
    String commentId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));

    for (final postId in _mockComments.keys) {
      final comments = _mockComments[postId]!;
      final index = comments.indexWhere((c) => c.id == commentId);
      if (index != -1) {
        final comment = comments[index];
        if (!comment.isLiked) {
          _mockComments[postId] = List.from(comments)
            ..[index] = comment.copyWith(
              likesCount: comment.likesCount + 1,
              isLiked: true,
            );
          return Right(_mockComments[postId]![index]);
        }
      }
    }

    return Left(UnknownException(message: 'Comment not found'));
  }

  @override
  Future<Either<DomainException, CommentDto>> unlikeComment(
    String commentId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));

    for (final postId in _mockComments.keys) {
      final comments = _mockComments[postId]!;
      final index = comments.indexWhere((c) => c.id == commentId);
      if (index != -1) {
        final comment = comments[index];
        if (comment.isLiked) {
          _mockComments[postId] = List.from(comments)
            ..[index] = comment.copyWith(
              likesCount: comment.likesCount > 0 ? comment.likesCount - 1 : 0,
              isLiked: false,
            );
          return Right(_mockComments[postId]![index]);
        }
      }
    }

    return Left(UnknownException(message: 'Comment not found'));
  }
}
