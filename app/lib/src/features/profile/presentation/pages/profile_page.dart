import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:app/src/features/profile/presentation/utils/profile_posts_grid_mapper.dart';
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

  Future<void> _loadMyPosts() async {
    if (_isPostsLoading) return;
    setState(() {
      _isPostsLoading = true;
      _postsError = null;
    });

    final restClient = getIt<RestClient>(instanceName: 'DioClient');
    final response = await restClient.get(
      EndPoints.profileMePosts,
      queryParameters: <String, dynamic>{'limit': 30},
    );

    if (!mounted) return;

    response.fold(
      (error) {
        setState(() {
          _isPostsLoading = false;
          _postsError = error.message;
        });
      },
      (result) {
        final mapped = mapProfilePostsGridItems(result.data)
            .map(
              (item) => PostEntity(
                id: item.id,
                userId: '',
                username: '',
                content: '',
                imageUrls: item.imageUrls,
                createdAt: DateTime.now(),
              ),
            )
            .toList(growable: false);

        setState(() {
          _myPosts = mapped;
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

                    return CustomScrollView(
                      slivers: [
                        // Profile Header Card
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ProfileHeaderCard(
                              displayName: profile.displayName,
                              userId: profile.userId,
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
                              child: Center(child: CircularProgressIndicator()),
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
