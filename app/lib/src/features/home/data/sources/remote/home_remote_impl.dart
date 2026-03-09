import 'package:app/src/core/api/client/dio/dio_client.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/home/data/models/comment_dto.dart';
import 'package:app/src/features/home/data/models/feed_dto.dart';
import 'package:app/src/features/home/data/models/feed_state_dto.dart';
import 'package:app/src/features/home/data/models/interaction_list_dto.dart';
import 'package:app/src/features/home/data/models/notification_dto.dart';
import 'package:app/src/features/home/data/models/post_dto.dart';
import 'package:app/src/features/home/data/models/status_response_dto.dart';
import 'package:app/src/features/home/data/models/threaded_comments_dto.dart';
import 'package:app/src/features/home/data/sources/remote/i_home_remote.dart';
import 'package:app/src/features/home/domain/requests/create_comment_request.dart';
import 'package:app/src/features/home/domain/requests/create_post_request.dart';
import 'package:app/src/features/home/domain/requests/feed_request.dart';
import 'package:app/src/features/home/domain/requests/feed_state_sync_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_comments_request.dart';
import 'package:app/src/features/home/domain/requests/get_post_likes_request.dart';
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
      ...List.generate(16, (index) {
        final seed = index + 5;
        final imageSets = <List<String>>[
          const [],
          [
            'https://images.unsplash.com/photo-1516979187457-637abb4f9353?w=400',
          ],
          [
            'https://images.unsplash.com/photo-1455885666463-9b3f9f36e099?w=400',
            'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=400',
          ],
        ];
        final contents = <String>[
          'Starting this week with 20 pages a day.',
          'Any recommendations for short classic novels?',
          'Today I highlighted 12 quotes from one chapter.',
          'Reading with tea is still the best combo.',
        ];
        final names = <String>[
          'Emma Storyline',
          'David Chapters',
          'Nora Bookmark',
          'Leo Novelist',
        ];

        return PostDto(
          id: 'post-$seed',
          userId: 'user-$seed',
          username: names[index % names.length],
          userAvatar: 'https://i.pravatar.cc/150?img=${(index % 60) + 10}',
          content: contents[index % contents.length],
          imageUrls: imageSets[index % imageSets.length],
          likesCount: 15 + (index * 7),
          commentsCount: 4 + (index * 3),
          isLiked: index % 3 == 0,
          createdAt: DateTime.now()
              .subtract(Duration(hours: 13 + index))
              .toIso8601String(),
        );
      }),
    ];
  }

  @override
  Future<Either<DomainException, List<PostDto>>> getPosts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _ensureMockPostsLoaded();
    return Right(List<PostDto>.from(_mockPosts!));
  }

  @override
  Future<Either<DomainException, FeedDto>> getFeed(FeedRequest request) async {
    try {
      final response = await _restClient.get(
        EndPoints.feed,
        queryParameters: request.toQuery(),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(UnknownException(message: 'Invalid feed response'));
          }
          final dto = FeedDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, StatusResponseDto>> createFeedPost(
    CreatePostRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.posts,
        data: request.toJson(),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid create feed post response'),
            );
          }
          final dto = StatusResponseDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, ThreadedCommentsDto>> getPostComments(
    GetPostCommentsRequest request,
  ) async {
    try {
      final response = await _restClient.get(
        EndPoints.postComments(request.postId),
        queryParameters: request.toQuery(),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid get post comments response'),
            );
          }
          final dto = ThreadedCommentsDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, StatusResponseDto>> createPostComment(
    String postId,
    CreateCommentRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.postComments(postId),
        data: request.toJson(),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid create post comment response'),
            );
          }
          final dto = StatusResponseDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, InteractionListDto>> getPostLikes(
    GetPostLikesRequest request,
  ) async {
    try {
      final response = await _restClient.get(
        EndPoints.postLikes(request.postId),
        queryParameters: request.toQuery(),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid get post likes response'),
            );
          }
          final dto = InteractionListDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, StatusResponseDto>> togglePostLike(
    String postId,
  ) async {
    try {
      final response = await _restClient.post(EndPoints.postLikes(postId));
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid toggle post like response'),
            );
          }
          final dto = StatusResponseDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
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
    if (parentCommentId != "") {
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
      userAvatar: "",
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

    if (parentCommentId == "") {
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

  // Notifications mock data and methods
  final List<NotificationDto> _mockNotifications = [
    NotificationDto(
      id: '1',
      type: 'like',
      notificationType: 'like',
      userId: 'user1',
      userName: 'Isabbekov',
      userAvatarUrl: '',
      userMeta: 'Moonstone - Intention - A',
      message: 'Did you like your video',
      accentText: '',
      ctaLabel: '',
      ctaValue: '',
      rightImageUrl: 'post-thumb-1',
      postId: 'post123',
      createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      isRead: false,
    ),
    NotificationDto(
      id: '2',
      type: 'follow',
      notificationType: 'subscriptions',
      userId: 'user2',
      userName: 'Zhajd',
      userAvatarUrl: '',
      userMeta: 'Moonstone - Intention - A',
      message: 'Subscribed to you',
      accentText: '',
      ctaLabel: 'View',
      ctaValue: '',
      rightImageUrl: '',
      postId: '',
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      isRead: false,
    ),
    NotificationDto(
      id: '3',
      type: 'comment',
      notificationType: 'comment',
      userId: 'user3',
      userName: 'Esimova',
      userAvatarUrl: '',
      userMeta: 'Lapiz Lazuli - Influence - A',
      message: 'Left a comment',
      accentText: '"Cool bro"',
      ctaLabel: '',
      ctaValue: '',
      rightImageUrl: 'post-thumb-2',
      postId: 'post456',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: true,
    ),
    NotificationDto(
      id: '4',
      type: 'rejected',
      notificationType: 'post',
      userId: 'user4',
      userName: 'You',
      userAvatarUrl: '',
      userMeta: '',
      message: 'Your post was not verified',
      accentText: 'reason',
      ctaLabel: 'Clear',
      ctaValue: 'Does not comply with social norms',
      rightImageUrl: 'post-thumb-3',
      postId: 'post789',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: true,
    ),
    NotificationDto(
      id: '5',
      type: 'pending',
      notificationType: 'help',
      userId: 'user5',
      userName: 'Ahanov',
      userAvatarUrl: '',
      userMeta: 'Ammolite - Fortitude - S',
      message: 'Request "Son\'s birthday"',
      accentText: '',
      ctaLabel: 'View',
      ctaValue: '',
      rightImageUrl: '',
      postId: '',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      isRead: true,
    ),
    NotificationDto(
      id: '6',
      type: 'published',
      notificationType: 'post',
      userId: 'me',
      userName: 'You',
      userAvatarUrl: '',
      userMeta: '',
      message: 'Your post has been successfully published',
      accentText: '',
      ctaLabel: '',
      ctaValue: '',
      rightImageUrl: 'post-thumb-4',
      postId: '',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
  ];

  @override
  Future<Either<DomainException, List<NotificationDto>>>
      getNotifications() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return Right(List<NotificationDto>.from(_mockNotifications));
  }

  @override
  Future<Either<DomainException, FeedStateDto>> getFeedState() async {
    try {
      final response = await _restClient.get(EndPoints.feedState);
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(UnknownException(message: 'Invalid feed state response'));
          }
          final dto = FeedStateDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, FeedStateDto>> syncFeedState(
    FeedStateSyncRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.feedStateSync,
        data: request.toJson(),
      );
      return response.fold(
        (error) => Left(error),
        (result) {
          final dynamic raw = result.data;
          if (raw is! Map) {
            return Left(
              UnknownException(message: 'Invalid feed state sync response'),
            );
          }
          final dto = FeedStateDto.fromJson(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          );
          return Right(dto);
        },
      );
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }


}

