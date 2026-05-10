import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:app/src/features/home/domain/requests/get_profile_posts_request.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:app/src/features/profile/presentation/mixins/show_profile_actions_bottom_sheet.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_header_card.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_post_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PublicProfilePage extends StatefulWidget {
  final String userId;

  const PublicProfilePage({super.key, required this.userId});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage>
    with ShowProfileActionsBottomSheet {
  List<PostEntity> _theirPosts = const [];
  bool _isPostsLoading = false;
  String? _postsError;
  String? _postsFetchedForUserId;

  @override
  void initState() {
    super.initState();
    getIt<ProfileBloc>().add(ProfileEvent.loadPublicProfile(widget.userId));
  }

  @override
  void didUpdateWidget(covariant PublicProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _theirPosts = const [];
      _postsError = null;
      _postsFetchedForUserId = null;
      _isPostsLoading = false;
      getIt<ProfileBloc>().add(ProfileEvent.loadPublicProfile(widget.userId));
    }
  }

  String _publicationsDisplayName({
    required String displayName,
    required String firstName,
    required String lastName,
    required String userId,
  }) {
    final dn = displayName.trim();
    if (dn.isNotEmpty) return dn;
    final name = '$firstName $lastName'.trim();
    if (name.isNotEmpty) return name;
    return userId.trim();
  }

  String _profileShareUrl(String userId) {
    final id = userId.trim();
    return 'https://brightbund.app/profile/$id';
  }

  Future<void> _copyProfileUrlToClipboard() async {
    final url = _profileShareUrl(widget.userId);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile link copied')),
    );
  }

  Future<void> _shareProfileLink() async {
    final url = _profileShareUrl(widget.userId);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile link copied — paste it to share'),
      ),
    );
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

  Future<void> _fetchTheirPostsIfNeeded() async {
    if (!mounted) return;
    if (_postsFetchedForUserId == widget.userId) return;
    if (_isPostsLoading) return;

    final requestedUserId = widget.userId;

    setState(() {
      _isPostsLoading = true;
      _postsError = null;
    });

    // Grid endpoint returns `UserPostsGridResponse` (minimal fields); list returns full posts.
    final result = await getIt<HomeBloc>().getProfilePostsListDirect(
      GetProfilePostsRequest(userId: requestedUserId, limit: 30),
    );

    if (!mounted || widget.userId != requestedUserId) return;

    result.fold(
      (error) {
        setState(() {
          _isPostsLoading = false;
          _postsError = error.message;
        });
      },
      (feed) {
        setState(() {
          _isPostsLoading = false;
          _theirPosts = _mapProfilePostsFromFeed(feed.items);
          _postsFetchedForUserId = requestedUserId;
        });
      },
    );
  }

  void _openTheirPublications(
    BuildContext context, {
    required String displayName,
    required String initialPostId,
  }) {
    context.pushNamed(
      RouteNames.profilePublications,
      extra: <String, dynamic>{
        'displayName': displayName,
        'initialPostId': initialPostId,
        'isCurrentUser': false,
        'userId': widget.userId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = getIt<ProfileBloc>();

    return BlocConsumer<ProfileBloc, ProfileState>(
      bloc: bloc,
      listenWhen: (previous, current) => current.maybeWhen(
        loaded: (_) => true,
        orElse: () => false,
      ),
      listener: (context, state) {
        state.maybeWhen(
          loaded: (viewModel) {
            if (viewModel.relationshipStatus.iBlockedThem) {
              if (!mounted) return;
              setState(() {
                _theirPosts = const [];
                _postsError = null;
                _isPostsLoading = false;
                _postsFetchedForUserId = null;
              });
              return;
            }
            _fetchTheirPostsIfNeeded();
          },
          orElse: () {},
        );
      },
      builder: (context, state) {
        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: AppColors.colorff19191A,
                child: const IgnorePointer(
                  child: ParticleAnimation(
                    particleCount: 20,
                    particleColors: [Color(0xFFFFFFFF)],
                    minSize: 4,
                    maxSize: 8,
                    minDistanceBetweenParticles: 70,
                  ),
                ),
              ),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                title: Text(
                  'Profile',
                  style: TextStyles.titleHeadline.copyWith(
                    color: Colors.white,
                    fontFamily: 'Lora',
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {
                      showProfileActionsBottomSheet(
                        context,
                        userName: state.maybeMap(
                          loaded: (s) =>
                              s.viewModel.publicProfile.displayName,
                          orElse: () => 'User',
                        ),
                        onBlock: () {
                          bloc.add(ProfileEvent.blockUser(widget.userId));
                        },
                        onReport: () {
                          bloc.add(ProfileEvent.reportUser(widget.userId));
                        },
                        onRestrict: () {
                          bloc.add(ProfileEvent.restrictUser(widget.userId));
                        },
                        onCopyUrl: _copyProfileUrlToClipboard,
                        onShare: _shareProfileLink,
                      );
                    },
                  ),
                ],
              ),
              body: SafeArea(
                child: state.when(
                  initial: () =>
                      const Center(child: CircularProgressIndicator()),
                  loading: (_) =>
                      const Center(child: CircularProgressIndicator()),
                  loadingError: (message) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          message,
                          style: TextStyles.bodyMain.copyWith(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  loaded: (viewModel) {
                    final profile = viewModel.publicProfile;

                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
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
                              isPublicProfile: true,
                              relationshipStatus: viewModel.relationshipStatus,
                              onFollow: () => bloc.add(
                                ProfileEvent.becomeAlly(widget.userId),
                              ),
                              onUnfollow: () => bloc.add(
                                ProfileEvent.removeAlly(widget.userId),
                              ),
                              onUnblock: () => bloc.add(
                                ProfileEvent.unblockUser(widget.userId),
                              ),
                            ),
                          ),
                        ),
                        if (viewModel.relationshipStatus.iBlockedThem)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Assets.icons.blocked.svg(
                                  width: 64,
                                  height: 64,
                                  colorFilter: const ColorFilter.mode(
                                    Colors.white,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'You\'ve blocked this account',
                                  style: TextStyles.titleMain.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                  ),
                                  child: Text(
                                    'Unblock this account to see their photos and videos. When you unblock them, they\'ll also be able to find your profile, see your content and message you again.',
                                    style: TextStyles.bodyMain.copyWith(
                                      color: const Color(0xFF6D6D6D),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          if (_isPostsLoading)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 48),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
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
                              posts: _theirPosts,
                              onPostTap: (postId) => _openTheirPublications(
                                context,
                                displayName: _publicationsDisplayName(
                                  displayName: profile.displayName,
                                  firstName: profile.firstName,
                                  lastName: profile.lastName,
                                  userId: profile.userId,
                                ),
                                initialPostId: postId,
                              ),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
