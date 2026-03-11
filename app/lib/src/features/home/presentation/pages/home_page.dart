import 'dart:async';

import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/device_id.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/features/home/domain/requests/feed_request.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
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
  final DeviceId _deviceId = DeviceId();
  Timer? _feedSyncTimer;
  DateTime? _lastSyncAt;
  String? _currentDeviceId;
  bool _isAppActive = true;
  bool _wasOnFeedRoute = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bloc.add(const HomeEvent.loadFeed(request: FeedRequest()));
    _bloc.add(const HomeEvent.loadFeedState());
    _initDeviceId();
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
      _wasOnFeedRoute = false;
      _bloc.add(const HomeEvent.loadFeedState());
      _startFeedSyncTimer();
    } else {
      _feedSyncTimer?.cancel();
      _feedSyncTimer = null;
      _lastSyncAt = null;
    }
  }

  Future<void> _initDeviceId() async {
    try {
      final id = await _deviceId.getDeviceId();
      if (!mounted) return;
      setState(() {
        _currentDeviceId = id;
      });
    } catch (_) {}
  }

  void _startFeedSyncTimer() {
    _feedSyncTimer?.cancel();
    _lastSyncAt = DateTime.now();
    _feedSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || !_isAppActive) return;
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;

      if (isCurrentRoute && !_wasOnFeedRoute) {
        _wasOnFeedRoute = true;
        _lastSyncAt = DateTime.now();
        _bloc.add(const HomeEvent.loadFeedState());
        return;
      }

      if (!isCurrentRoute) {
        _wasOnFeedRoute = false;
        _lastSyncAt = DateTime.now();
        return;
      }

      final now = DateTime.now();
      final previous = _lastSyncAt ?? now;
      final deltaSeconds = now.difference(previous).inSeconds;
      _lastSyncAt = now;
      final deviceId = _currentDeviceId;

      if (deltaSeconds <= 0 || deviceId == null || deviceId.isEmpty) return;
      _bloc.add(
        HomeEvent.syncFeedState(
          deltaSeconds: deltaSeconds,
          deviceId: deviceId,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      bloc: _bloc,
      builder: (context, state) {
        return state.when(
          initial: () => Scaffold(
            backgroundColor: AppColors.colorff19191A,
            appBar: FeedAppBar(
              onCreatePostTap: () => context.push(RoutePaths.createPost),
            ),
            bottomNavigationBar:
                const CustomNavBar(currentTab: RoutePaths.home),
            body: const SafeArea(
                child: Center(child: CircularProgressIndicator())),
          ),
          loading: (viewModel) => Scaffold(
            backgroundColor: AppColors.colorff19191A,
            appBar: FeedAppBar(
              onCreatePostTap: () => context.push(RoutePaths.createPost),
              feedState: viewModel.feedState,
            ),
            bottomNavigationBar:
                const CustomNavBar(currentTab: RoutePaths.home),
            body: const SafeArea(
                child: Center(child: CircularProgressIndicator())),
          ),
          loaded: (viewModel) {
            final feedState = viewModel.feedState;
            final posts = viewModel.feed.items;

            if (posts.isEmpty) {
              return Scaffold(
                backgroundColor: AppColors.colorff19191A,
                appBar: FeedAppBar(
                  onCreatePostTap: () => context.push(RoutePaths.createPost),
                  feedState: feedState,
                ),
                bottomNavigationBar:
                    const CustomNavBar(currentTab: RoutePaths.home),
                body: SafeArea(
                  child: Center(
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
                ),
              );
            }

            final ScrollPhysics physics = FeedSoftLimitScrollPhysics(
              accumulatedActiveSeconds: feedState.accumulatedActiveSeconds,
              maxAllowedSeconds: feedState.maxAllowedSeconds,
              isInCooldown: feedState.shouldEnforceCooldown,
              breakSecondsRemaining: feedState.safeBreakSecondsRemaining,
            );

            return Scaffold(
              backgroundColor: AppColors.colorff19191A,
              appBar: FeedAppBar(
                onCreatePostTap: () => context.push(RoutePaths.createPost),
                feedState: feedState,
              ),
              bottomNavigationBar:
                  const CustomNavBar(currentTab: RoutePaths.home),
              body: SafeArea(
                child: ListView.separated(
                  physics: physics,
                  separatorBuilder: (context, index) => const Gap(18),
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return PostCardWidget(post: post);
                  },
                ),
              ),
            );
          },
          loadingError: (message) => Scaffold(
            backgroundColor: AppColors.colorff19191A,
            appBar: FeedAppBar(
              onCreatePostTap: () => context.push(RoutePaths.createPost),
            ),
            bottomNavigationBar:
                const CustomNavBar(currentTab: RoutePaths.home),
            body: SafeArea(
              child: Center(
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
          ),
        );
      },
    );
  }
}

