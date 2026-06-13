import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/features/home/domain/entities/feed_entity.dart';
import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:app/src/features/home/domain/requests/get_my_profile_posts_request.dart';
import 'package:app/src/features/home/domain/requests/get_profile_posts_request.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/home/presentation/widgets/publications_post_card.dart';
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:go_router/go_router.dart';

class ProfilePublicationsPage extends StatefulWidget {
  const ProfilePublicationsPage({
    required this.displayName,
    required this.initialPostId,
    required this.isCurrentUser,
    super.key,
    this.userId,
  });

  final String? userId;
  final String displayName;
  final String initialPostId;
  final bool isCurrentUser;

  @override
  State<ProfilePublicationsPage> createState() =>
      _ProfilePublicationsPageState();
}

class _ProfilePublicationsPageState extends State<ProfilePublicationsPage> {
  final ScrollController _scrollController = ScrollController();

  FeedEntity _feed = const FeedEntity.empty();
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialPosts();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitialPosts() async {
    setState(() {
      _isInitialLoading = true;
      _errorMessage = '';
    });

    final result = await _requestPosts();
    if (!mounted) return;

    result.fold(
      (error) {
        setState(() {
          _isInitialLoading = false;
          _errorMessage = error.message;
        });
      },
      (feed) {
        setState(() {
          _feed = feed;
          _isInitialLoading = false;
          _errorMessage = '';
        });
      },
    );
  }

  Future<void> _loadMorePosts() async {
    final nextCursor = _feed.nextCursor.trim();
    if (nextCursor.isEmpty || _isInitialLoading || _isLoadingMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    final result = await _requestPosts(cursor: nextCursor);
    if (!mounted) return;

    result.fold(
      (error) {
        setState(() {
          _isLoadingMore = false;
          if (_feed.items.isEmpty) {
            _errorMessage = error.message;
          }
        });
      },
      (feed) {
        setState(() {
          _feed = _mergeFeedPages(
            current: _feed,
            incoming: feed,
            cursor: nextCursor,
          );
          _isLoadingMore = false;
        });
      },
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _loadMorePosts();
    }
  }

  Future<Either<DomainException, FeedEntity>> _requestPosts({
    String? cursor,
  }) async {
    final bloc = getIt<HomeBloc>();
    final anchorPostId =
        cursor?.trim().isNotEmpty == true ? null : widget.initialPostId;

    if (widget.isCurrentUser) {
      return bloc.getMyProfilePostsListDirect(
        GetMyProfilePostsRequest(
          cursor: cursor,
          anchorPostId: anchorPostId,
          limit: 10,
        ),
      );
    }

    final userId = widget.userId?.trim() ?? '';
    if (userId.isEmpty) {
      return Left<DomainException, FeedEntity>(
        UnknownException(message: 'Unable to load publications.'),
      );
    }

    return bloc.getProfilePostsListDirect(
      GetProfilePostsRequest(
        userId: userId,
        cursor: cursor,
        anchorPostId: anchorPostId,
        limit: 10,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: AppColors.colorff19191A,
            child: const IgnorePointer(
              child: ParticleAnimation(
                particleCount: 14,
                particleColors: [Color(0xFFFFFFFF)],
                minSize: 1.0,
                maxSize: 3.0,
                minDistanceBetweenParticles: 92.0,
              ),
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _ProfilePublicationsAppBar(
            displayName: widget.displayName,
          ),
          body: SafeArea(
            child: _ProfilePublicationsBody(
              controller: _scrollController,
              feed: _feed,
              isInitialLoading: _isInitialLoading,
              isLoadingMore: _isLoadingMore,
              errorMessage: _errorMessage,
              isOwnerViewer: widget.isCurrentUser,
              onOwnerDeletedPost: (postId) {
                setState(() {
                  _feed = _feed.copyWith(
                    items: _feed.items
                        .where((p) => p.postId != postId)
                        .toList(),
                  );
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfilePublicationsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _ProfilePublicationsAppBar({
    required this.displayName,
  });

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 72,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      centerTitle: true,
      leading: GestureDetector(
        onTap: () => context.pop(),
        child: Center(
          child: Assets.icons.arrowBack.svg(
            width: 20,
            height: 20,
          ),
        ),
      ),
      title: _ProfilePublicationsTitle(displayName: displayName),
      actions: const [SizedBox(width: 48)],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72);
}

class _ProfilePublicationsTitle extends StatelessWidget {
  const _ProfilePublicationsTitle({
    required this.displayName,
  });

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Publications',
          style: TextStyles.titleMain.copyWith(color: Colors.white),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            displayName.trim(),
            style: TextStyles.bodySecondary.copyWith(
              color: AppColors.colorff9CA3AF,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _ProfilePublicationsBody extends StatelessWidget {
  const _ProfilePublicationsBody({
    required this.controller,
    required this.feed,
    required this.isInitialLoading,
    required this.isLoadingMore,
    required this.errorMessage,
    required this.isOwnerViewer,
    required this.onOwnerDeletedPost,
  });

  final ScrollController controller;
  final FeedEntity feed;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final String errorMessage;
  final bool isOwnerViewer;
  final ValueChanged<String> onOwnerDeletedPost;

  @override
  Widget build(BuildContext context) {
    if (isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.trim().isNotEmpty && feed.items.isEmpty) {
      return _ProfilePublicationsErrorState(message: errorMessage);
    }

    if (feed.items.isEmpty) {
      return const _ProfilePublicationsEmptyState();
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: feed.items.length + (isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        if (index >= feed.items.length) {
          return const _ProfilePublicationsLoadingMoreIndicator();
        }

        final post = feed.items[index];
        return PublicationsPostCard(
          anchorPost: post,
          bloc: getIt<HomeBloc>(),
          isOwnerMode: isOwnerViewer,
          onPostDeleted: () => onOwnerDeletedPost(post.postId),
        );
      },
    );
  }
}

class _ProfilePublicationsErrorState extends StatelessWidget {
  const _ProfilePublicationsErrorState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          message,
          style: TextStyles.bodyMain.copyWith(
            color: AppColors.colorffE5E5E5,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ProfilePublicationsEmptyState extends StatelessWidget {
  const _ProfilePublicationsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No publications yet',
        style: TextStyles.bodyMain.copyWith(
          color: AppColors.colorff9CA3AF,
        ),
      ),
    );
  }
}

class _ProfilePublicationsLoadingMoreIndicator extends StatelessWidget {
  const _ProfilePublicationsLoadingMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

FeedEntity _mergeFeedPages({
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
