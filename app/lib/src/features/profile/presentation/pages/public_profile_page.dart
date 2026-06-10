import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/features/chats/data/sources/remote/i_chats_remote.dart';
import 'package:app/src/features/chats/presentation/mappers/chat_thread_preview_mapper.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:app/src/features/home/domain/requests/get_profile_posts_request.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/profile/domain/entities/public_profile_entity.dart';
import 'package:app/src/features/profile/domain/repositories/i_profile_repository.dart';
import 'package:app/src/features/profile/domain/requests/user_id_request.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:app/src/features/profile/presentation/mixins/show_profile_actions_bottom_sheet.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_header_card.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_post_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

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
    await SharePlus.instance.share(
      ShareParams(text: url),
    );
  }

  Future<void> _openReportReasons() async {
    final selection = await showModalBottomSheet<_ProfileReportReason>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF202020),
      barrierColor: Colors.black.withValues(alpha: 0.62),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => const _ProfileReportReasonsSheet(),
    );
    if (!mounted || selection == null) return;

    final result = await getIt<IProfileRepository>().reportUser(
      UserIdRequest(userId: widget.userId),
      reason: selection.apiReason,
      description: selection.label,
    );
    if (!mounted) return;

    result.fold(
      (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted')),
        );
      },
    );
  }

  Future<void> _openDirectMessageFromProfile(
      PublicProfileEntity profile) async {
    final remote = getIt<IChatsRemote>(instanceName: 'ChatsRemoteImpl');
    final result = await remote.openDirectConversation(
      recipientId: profile.userId.trim(),
    );
    if (!mounted) {
      return;
    }
    result.fold(
      (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      },
      (dto) {
        final preview = ChatThreadPreviewMapper.fromConversation(dto);
        context.pushNamed(
          RouteNames.chatConversation,
          pathParameters: <String, String>{'chatId': dto.id},
          extra: preview,
        );
      },
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

  List<Widget> _publicProfileToolbarAndGapSlivers({
    required BuildContext context,
    required ProfileBloc bloc,
    required ProfileState state,
  }) {
    final titleStyle = TextStyles.titleHeadline.copyWith(
      color: Colors.white,
      fontFamily: 'Lora',
      fontWeight: FontWeight.w600,
      fontSize: 18,
    );
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: SizedBox(
            height: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Assets.images.chevronLeft.image(
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
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
                          onReport: _openReportReasons,
                          onRestrict: () {
                            bloc.add(ProfileEvent.restrictUser(widget.userId));
                          },
                          onCopyUrl: _copyProfileUrlToClipboard,
                          onShare: _shareProfileLink,
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Assets.images.dots.image(
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
                IgnorePointer(
                  child: Text('Profile', style: titleStyle),
                ),
              ],
            ),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
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

  void _openUserStats(PublicProfileEntity profile) {
    context.pushNamed(
      RouteNames.profileStats,
      extra: <String, dynamic>{
        'userId': profile.userId,
        'isCurrentUser': false,
        'rankTier': profile.rankTier,
        'reputationScore': profile.reputationScore,
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
            if (viewModel.relationshipStatus.iBlockedThem ||
                viewModel.relationshipStatus.theyBlockedMe) {
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
              body: SafeArea(
                child: state.when(
                  initial: () => CustomScrollView(
                    slivers: [
                      ..._publicProfileToolbarAndGapSlivers(
                        context: context,
                        bloc: bloc,
                        state: state,
                      ),
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  ),
                  loading: (_) => CustomScrollView(
                    slivers: [
                      ..._publicProfileToolbarAndGapSlivers(
                        context: context,
                        bloc: bloc,
                        state: state,
                      ),
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  ),
                  loadingError: (message) => CustomScrollView(
                    slivers: [
                      ..._publicProfileToolbarAndGapSlivers(
                        context: context,
                        bloc: bloc,
                        state: state,
                      ),
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
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
                    ],
                  ),
                  loaded: (viewModel) {
                    final profile = viewModel.publicProfile;

                    return CustomScrollView(
                      slivers: [
                        ..._publicProfileToolbarAndGapSlivers(
                          context: context,
                          bloc: bloc,
                          state: state,
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                            child: ProfileHeaderCard(
                              displayName: profile.displayName,
                              userId: profile.userId,
                              username: profile.username,
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
                              onStatsTap: () => _openUserStats(profile),
                              onFollow: () => bloc.add(
                                ProfileEvent.becomeAlly(widget.userId),
                              ),
                              onUnfollow: () => bloc.add(
                                ProfileEvent.removeAlly(widget.userId),
                              ),
                              onUnblock: () => bloc.add(
                                ProfileEvent.unblockUser(widget.userId),
                              ),
                              onMessage: () =>
                                  _openDirectMessageFromProfile(profile),
                            ),
                          ),
                        ),
                        if (viewModel.relationshipStatus.iBlockedThem ||
                            viewModel.relationshipStatus.theyBlockedMe)
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
                                  viewModel.relationshipStatus.iBlockedThem
                                      ? 'You\'ve blocked this account'
                                      : 'This account is unavailable',
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
                                    viewModel.relationshipStatus.iBlockedThem
                                        ? 'Unblock this account to see their photos and videos. When you unblock them, they\'ll also be able to find your profile, see your content and message you again.'
                                        : 'You cannot view this account\'s posts or contact this user.',
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
                                  horizontal: 20,
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
                            SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              sliver: ProfilePostGrid(
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

class _ProfileReportReason {
  const _ProfileReportReason({
    required this.label,
    required this.apiReason,
  });

  final String label;
  final String apiReason;
}

class _ProfileReportReasonsSheet extends StatelessWidget {
  const _ProfileReportReasonsSheet();

  static const _reasons = <_ProfileReportReason>[
    _ProfileReportReason(label: 'Spam or scam', apiReason: 'spam'),
    _ProfileReportReason(label: 'Hate or harassment', apiReason: 'harassment'),
    _ProfileReportReason(
      label: 'Nudity or sexual content',
      apiReason: 'inappropriate',
    ),
    _ProfileReportReason(label: 'Violence', apiReason: 'inappropriate'),
    _ProfileReportReason(label: 'Illegal content', apiReason: 'other'),
    _ProfileReportReason(label: 'Gambling promotion', apiReason: 'other'),
    _ProfileReportReason(label: 'Copyright violation', apiReason: 'other'),
    _ProfileReportReason(label: 'Fake account', apiReason: 'fake_account'),
    _ProfileReportReason(label: 'Manipulation of Honor', apiReason: 'other'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Why are you reporting this account?',
              textAlign: TextAlign.center,
              style: TextStyles.titleMain.copyWith(
                color: AppColors.textBrand,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your report is anonymous.',
              textAlign: TextAlign.center,
              style: TextStyles.bodyMain.copyWith(
                color: const Color(0xFF838383),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _reasons.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                itemBuilder: (context, index) {
                  final reason = _reasons[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      reason.label,
                      style: TextStyles.bodyLarge.copyWith(
                        color: AppColors.textBrand,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF838383),
                    ),
                    onTap: () => Navigator.of(context).pop(reason),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
