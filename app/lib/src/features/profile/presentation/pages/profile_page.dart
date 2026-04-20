import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:app/src/features/home/domain/requests/get_my_profile_posts_request.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_header_card.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_post_grid.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ProfilePageContent();
  }
}

class _ProfilePageContent extends StatefulWidget {
  const _ProfilePageContent();

  @override
  State<_ProfilePageContent> createState() => _ProfilePageContentState();
}

class _ProfilePageContentState extends State<_ProfilePageContent> {
  List<PostEntity> _myPosts = const [];
  bool _isPostsLoading = false;
  String? _postsError;
  String? _lastRouterLocation;
  VoidCallback? _routerListener;
  GoRouter? _router;

  void _openSettings() {
    final currentUserId = getIt<ProfileBloc>().state.maybeWhen(
          loaded: (viewModel) => viewModel.profile.userId,
          orElse: () => null,
        );
    // Полный путь + корневой стек (см. parentNavigatorKey у GoRoute settings) —
    // иначе в shell иногда остаётся старая заглушка / не тот билд.
    context.push(
      '${RoutePaths.profile}/settings',
      extra: <String, dynamic>{'userId': currentUserId},
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = getIt<ProfileBloc>();
      final shouldLoad = bloc.state.maybeWhen(
        initial: () => true,
        loadingError: (_) => true,
        orElse: () => false,
      );
      if (shouldLoad) {
        bloc.add(const ProfileEvent.loadProfile());
      }
      _loadMyPosts();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachRouterListenerIfNeeded();
  }

  @override
  void dispose() {
    if (_routerListener != null && _router != null) {
      _router!.routeInformationProvider.removeListener(_routerListener!);
    }
    super.dispose();
  }

  void _attachRouterListenerIfNeeded() {
    if (_routerListener != null) return;
    final router = GoRouter.of(context);
    _router = router;
    _lastRouterLocation ??= router.state.uri.path;
    void listener() {
      if (!mounted) return;
      final location = router.state.uri.path;
      final prev = _lastRouterLocation;
      _lastRouterLocation = location;

      final wasAwayFromProfileRoot = prev != null &&
          prev != RoutePaths.profile &&
          location == RoutePaths.profile;
      if (wasAwayFromProfileRoot) {
        _loadMyPosts(force: true);
      }
    }

    _routerListener = listener;
    router.routeInformationProvider.addListener(listener);
  }

  List<String> _gridImageUrlsForPost(PostResponseEntity post) {
    final urls = <String>[];
    for (final media in post.mediaAttachments) {
      final type = media.type.toLowerCase();
      if (type == 'video') {
        final thumb = media.thumbnailUrl.trim();
        final url = media.url.trim();
        if (thumb.isNotEmpty) {
          urls.add(thumb);
        } else if (url.isNotEmpty) {
          urls.add(url);
        }
      } else {
        final url = media.url.trim();
        if (url.isNotEmpty) urls.add(url);
      }
    }
    return urls;
  }

  List<PostEntity> _mapProfilePostsFromFeed(List<PostResponseEntity> items) {
    return items
        .map(
          (post) => PostEntity(
            id: post.postId,
            userId: post.author.id,
            username: post.author.username,
            content: post.contentText,
            imageUrls: _gridImageUrlsForPost(post),
            createdAt: DateTime.now(),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _loadMyPosts({bool force = false}) async {
    if (_isPostsLoading && !force) return;
    setState(() {
      _isPostsLoading = true;
      _postsError = null;
    });

    final result = await getIt<HomeBloc>().getMyProfilePostsListDirect(
      const GetMyProfilePostsRequest(limit: 30),
    );

    if (!mounted) return;

    result.fold(
      (error) {
        setState(() {
          _isPostsLoading = false;
          _postsError = error.message;
        });
      },
      (feed) {
        setState(() {
          _myPosts = _mapProfilePostsFromFeed(feed.items);
          _isPostsLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Layer 1: Fixed particle background (behind everything)
        Positioned.fill(
          child: Container(
            color: AppColors.colorff19191A,
            child: const IgnorePointer(
              child: ParticleAnimation(
                particleCount: 20,
                particleColors: [Color(0xFFFFFFFF)],
                minSize: 4.0,
                maxSize: 8.0,
                minDistanceBetweenParticles: 70.0,
              ),
            ),
          ),
        ),
        // Layer 2: Scaffold with transparent background (above particles)
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: CustomAppBar(
            backgroundColor: Colors.transparent,
            showLeading: false,
            actions: [
              GestureDetector(
                onTap: _openSettings,
                child: const Icon(
                  Icons.menu_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const Gap(16),
            ],
          ),
          bottomNavigationBar: const CustomNavBar(
            currentTab: RoutePaths.profile,
          ),
          body: SafeArea(
            child: BlocBuilder<ProfileBloc, ProfileState>(
              bloc: getIt<ProfileBloc>(),
              builder: (context, state) {
                return state.when(
                  initial: () =>
                      const Center(child: CircularProgressIndicator()),
                  loading: (_) =>
                      const Center(child: CircularProgressIndicator()),
                  loadingError: (message) => Center(child: Text(message)),
                  loaded: (ProfileViewModel viewmodel) {
                    final profile = viewmodel.profile;

                    return RefreshIndicator(
                      onRefresh: () => _loadMyPosts(force: true),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          // Profile Header Card
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                              child: ProfileHeaderCard(
                                displayName: profile.displayName,
                                userId: profile.userId,
                                firstName: profile.firstName,
                                lastName: profile.lastName,
                                avatarUrl: profile.avatarUrl,
                                bio: profile.bio,
                                city: profile.city,
                                country: profile.country,
                                region: profile.region,
                                rankTier: profile.rankTier,
                                reputationScore: profile.reputationScore,
                              ),
                            ),
                          ),
                          // Posts Grid
                          if (_isPostsLoading)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 48),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              ),
                            )
                          else if (_postsError != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 32,
                                ),
                                child: Center(
                                  child: Text(
                                    _postsError!,
                                    style: TextStyles.bodyMain.copyWith(
                                      color: Colors.white70,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            )
                          else
                            ProfilePostGrid(
                              posts: _myPosts,
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
