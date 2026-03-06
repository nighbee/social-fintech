import 'dart:async';

import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/home/domain/entities/feed_state_entity.dart';
import 'package:app/src/features/home/presentation/widgets/feed_app_bar.dart';
import 'package:app/src/features/home/presentation/widgets/feed_soft_limit_scroll_physics.dart';
import 'package:app/src/features/home/presentation/widgets/post_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final HomeBloc _bloc = getIt<HomeBloc>();
  Timer? _feedSyncTimer;
  DateTime? _lastSyncAt;
  bool _isAppActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bloc.add(const HomeEvent.loadPosts());
    _bloc.add(const HomeEvent.loadFeedState());
    _startFeedSyncTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feedSyncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isResumed = state == AppLifecycleState.resumed;
    _isAppActive = isResumed;

    if (isResumed) {
      _bloc.add(const HomeEvent.loadFeedState());
      _startFeedSyncTimer();
    } else {
      _feedSyncTimer?.cancel();
      _feedSyncTimer = null;
      _lastSyncAt = null;
    }
  }

  void _startFeedSyncTimer() {
    _feedSyncTimer?.cancel();
    _lastSyncAt = DateTime.now();
    _feedSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || !_isAppActive) return;
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
      if (!isCurrentRoute) {
        _lastSyncAt = DateTime.now();
        return;
      }

      final now = DateTime.now();
      final previous = _lastSyncAt ?? now;
      final deltaSeconds = now.difference(previous).inSeconds;
      _lastSyncAt = now;

      if (deltaSeconds <= 0) return;
      _bloc.add(HomeEvent.syncFeedState(deltaSeconds: deltaSeconds));
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      bloc: _bloc,
      builder: (context, state) {
        return state.when(
          initial: () => _buildScaffold(
            context,
            const Center(child: CircularProgressIndicator()),
          ),
          loading: (viewModel) => _buildScaffold(
            context,
            const Center(child: CircularProgressIndicator()),
            feedState: viewModel.feedState,
          ),
          loaded: (viewModel) {
            if (viewModel.posts.isEmpty) {
              return _buildScaffold(
                context,
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 64,
                        color: AppColors.colorff9CA3AF,
                      ),
                      const Gap(16),
                      Text(
                        'No posts yet',
                        style: TextStyles.titleHeadline.copyWith(
                          color: AppColors.colorff9CA3AF,
                        ),
                      ),
                    ],
                  ),
                ),
                feedState: viewModel.feedState,
              );
            }

            final maxAllowedSeconds = viewModel.feedState.maxAllowedSeconds > 0
                ? viewModel.feedState.maxAllowedSeconds
                : 20 * 60;
            final ScrollPhysics physics = FeedSoftLimitScrollPhysics(
              accumulatedActiveSeconds:
                  viewModel.feedState.accumulatedActiveSeconds,
              maxAllowedSeconds: maxAllowedSeconds,
            );

            return _buildScaffold(
              context,
              ListView.separated(
                physics: physics,
                separatorBuilder: (context, index) => const Gap(18),
                padding: const EdgeInsets.all(16),
                itemCount: viewModel.posts.length,
                itemBuilder: (context, index) {
                  final post = viewModel.posts[index];
                  return PostCardWidget(post: post);
                },
              ),
              feedState: viewModel.feedState,
            );
          },
          loadingError: (message) => _buildScaffold(
            context,
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 64, color: AppColors.colorffEF4444),
                  const Gap(16),
                  Text(
                    'Error loading posts',
                    style: TextStyles.titleHeadline.copyWith(
                      color: AppColors.colorffEF4444,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    message,
                    style: TextStyles.bodyMain.copyWith(
                      color: AppColors.colorff9CA3AF,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    Widget body, {
    FeedStateEntity feedState = const FeedStateEntity.empty(),
  }) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: FeedAppBar(
        onCreatePostTap: () => context.push(RoutePaths.createPost),
        feedState: feedState,
      ),
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.home),
      body: SafeArea(child: body),
    );
  }
}
