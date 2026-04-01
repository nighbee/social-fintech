import 'dart:async';

import 'package:app/src/core/base/base_bloc/bloc/base_bloc_widget.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/device_id.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/features/home/domain/entities/feed_state_entity.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/home/presentation/widgets/feed_app_bar.dart';
import 'package:app/src/features/home/presentation/widgets/feed_soft_limit_scroll_physics.dart';
import 'package:app/src/features/home/presentation/widgets/post_card_widget.dart';
import 'package:app/src/features/home/presentation/widgets/reported_post_card_widget.dart';
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
  static const Duration _feedStateSyncInterval = Duration(seconds: 15);
  static const int _syncDeltaSeconds = 15;

  final HomeBloc _homeBloc = getIt<HomeBloc>();
  final DeviceId _deviceId = DeviceId();
  Timer? _feedStateSyncTimer;
  Timer? _reportSuccessTimer;
  String? _cachedDeviceId;
  bool _showReportSuccessBanner = false;
  bool _isAppForeground = true;
  bool _forceSyncAfterResume = false;
  DateTime? _cooldownFreezeStartedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeBloc.add(const HomeEvent.loadStoreSummary());
    unawaited(_startFeedStateSync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feedStateSyncTimer?.cancel();
    _reportSuccessTimer?.cancel();
    _feedStateSyncTimer = null;
    _reportSuccessTimer = null;
    super.dispose();
  }

  void _onPostReported() {
    if (!mounted) {
      return;
    }
    setState(() {
      _showReportSuccessBanner = true;
    });
    _reportSuccessTimer?.cancel();
    _reportSuccessTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showReportSuccessBanner = false;
      });
    });
  }

  void _dismissReportSuccessBanner() {
    _reportSuccessTimer?.cancel();
    _reportSuccessTimer = null;
    if (!mounted) {
      return;
    }
    setState(() {
      _showReportSuccessBanner = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppForeground = true;
      unawaited(_syncFeedStateOnce(deltaSeconds: 1, force: true));
      _feedStateSyncTimer ??=
          Timer.periodic(_feedStateSyncInterval, (_) => _onSyncTick());
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _isAppForeground = false;
      _forceSyncAfterResume = true;
      _feedStateSyncTimer?.cancel();
      _feedStateSyncTimer = null;
    }
  }

  Future<void> _startFeedStateSync() async {
    await _syncFeedStateOnce(deltaSeconds: 1, force: true);
    if (!mounted) {
      return;
    }
    _feedStateSyncTimer?.cancel();
    _feedStateSyncTimer =
        Timer.periodic(_feedStateSyncInterval, (_) => _onSyncTick());
  }

  void _onSyncTick() {
    unawaited(_syncFeedStateOnce(deltaSeconds: _syncDeltaSeconds));
  }

  FeedStateEntity _feedStateFromState(HomeState state) {
    return state.maybeWhen(
      loading: (viewModel) => viewModel.feedState,
      loaded: (viewModel) => viewModel.feedState,
      orElse: FeedStateEntity.empty,
    );
  }

  bool _isFeedRouteActive() {
    if (!mounted) {
      return false;
    }
    try {
      final currentPath =
          GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
      return currentPath == RoutePaths.home ||
          currentPath.startsWith('${RoutePaths.home}/');
    } catch (_) {
      // Fail-open to avoid accidentally over-syncing cooldown when route info
      // is temporarily unavailable.
      return true;
    }
  }

  bool _shouldFreezeCooldownFromState(HomeState state) {
    if (!_isAppForeground || !_isFeedRouteActive()) {
      return false;
    }
    final feedState = _feedStateFromState(state);
    return feedState.shouldEnforceCooldown;
  }

  void _updateCooldownFreezeState(HomeState state) {
    final shouldFreeze = _shouldFreezeCooldownFromState(state);
    if (shouldFreeze) {
      _cooldownFreezeStartedAt ??= DateTime.now();
      return;
    }
    _cooldownFreezeStartedAt = null;
  }

  Future<void> _syncFeedStateOnce({
    required int deltaSeconds,
    bool force = false,
  }) async {
    final shouldFreeze = _shouldFreezeCooldownFromState(_homeBloc.state);
    final mustForceSync = force || _forceSyncAfterResume;
    if (shouldFreeze && !mustForceSync) {
      if (_cooldownFreezeStartedAt == null && mounted) {
        setState(() {
          _cooldownFreezeStartedAt = DateTime.now();
        });
      }
      return;
    }

    _forceSyncAfterResume = false;
    final deviceId = _cachedDeviceId ?? await _deviceId.getDeviceId();
    _cachedDeviceId = deviceId;
    if (!mounted) {
      return;
    }
    _homeBloc.add(
      HomeEvent.syncFeedState(
        deltaSeconds: deltaSeconds,
        deviceId: deviceId,
      ),
    );
  }

  String _timerLabelFromViewModel(HomeViewModel viewModel) {
    final feedState = viewModel.feedState;
    if (feedState.serverTimestamp.isEmpty) {
      return '20 min';
    }

    if (feedState.shouldEnforceCooldown) {
      if (_shouldFreezeCooldownFromState(_homeBloc.state)) {
        return '5 min break';
      }
      final breakMinutes = (feedState.safeBreakSecondsRemaining / 60).ceil();
      return '$breakMinutes min break';
    }

    final maxAllowedSeconds = feedState.maxAllowedSeconds;
    if (maxAllowedSeconds <= 0) {
      return 'No limit';
    }

    final remainingSeconds =
        (maxAllowedSeconds - feedState.accumulatedActiveSeconds)
            .clamp(0, maxAllowedSeconds);
    final remainingMinutes = (remainingSeconds / 60).ceil();
    return '$remainingMinutes min';
  }

  FeedTimerTone _timerToneFromViewModel(HomeViewModel viewModel) {
    final feedState = viewModel.feedState;
    if (feedState.serverTimestamp.isEmpty) {
      return FeedTimerTone.normal;
    }

    if (feedState.shouldEnforceCooldown) {
      return FeedTimerTone.breakTime;
    }

    final maxAllowedSeconds = feedState.maxAllowedSeconds;
    if (maxAllowedSeconds <= 0) {
      return FeedTimerTone.normal;
    }

    final remainingSeconds =
        (maxAllowedSeconds - feedState.accumulatedActiveSeconds)
            .clamp(0, maxAllowedSeconds);
    final remainingMinutes = (remainingSeconds / 60).ceil();

    if (remainingMinutes <= 5) {
      return FeedTimerTone.warning;
    }

    return FeedTimerTone.normal;
  }

  String _timerLabelFromState(HomeState state) {
    return state.maybeWhen(
      loading: _timerLabelFromViewModel,
      loaded: _timerLabelFromViewModel,
      orElse: () => '20 min',
    );
  }

  FeedTimerTone _timerToneFromState(HomeState state) {
    return state.maybeWhen(
      loading: _timerToneFromViewModel,
      loaded: _timerToneFromViewModel,
      orElse: () => FeedTimerTone.normal,
    );
  }

  int _silverCountFromState(HomeState state) {
    return state.maybeWhen(
      loading: (viewModel) => viewModel.storeSummary.silverHonorsCount,
      loaded: (viewModel) => viewModel.storeSummary.silverHonorsCount,
      orElse: () => 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: AppColors.mainBackground,
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
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: BlocBuilder<HomeBloc, HomeState>(
              bloc: _homeBloc,
              builder: (context, state) {
                return FeedAppBar(
                  onCreatePostTap: () => context.push(RoutePaths.createPost),
                  onNotificationsTap: () =>
                      context.push(RoutePaths.notifications),
                  silverCount: _silverCountFromState(state),
                  timerLabel: _timerLabelFromState(state),
                  timerTone: _timerToneFromState(state),
                );
              },
            ),
          ),
          bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.home),
          body: SafeArea(
            child: BaseBlocWidget<HomeBloc, HomeEvent, HomeState>(
              bloc: _homeBloc,
              starterEvent: const HomeEvent.loadPosts(),
              builder: (context, state, bloc) {
                return state.when(
                  initial: () =>
                      const Center(child: CircularProgressIndicator()),
                  loading: (_) =>
                      const Center(child: CircularProgressIndicator()),
                  loaded: (viewModel) {
                    _updateCooldownFreezeState(HomeState.loaded(
                      viewModel: viewModel,
                    ));

                    if (viewModel.posts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.article_outlined,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            const Gap(16),
                            Text(
                              'No posts yet',
                              style: TextStyles.titleHeadline.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Stack(
                      children: [
                        ListView.separated(
                          physics: FeedSoftLimitScrollPhysics(
                            accumulatedActiveSeconds:
                                viewModel.feedState.accumulatedActiveSeconds,
                            maxAllowedSeconds:
                                viewModel.feedState.maxAllowedSeconds,
                            isInCooldown:
                                viewModel.feedState.shouldEnforceCooldown,
                            breakSecondsRemaining:
                                viewModel.feedState.safeBreakSecondsRemaining,
                            freezeBreakCountdown:
                                _shouldFreezeCooldownFromState(
                              HomeState.loaded(viewModel: viewModel),
                            ),
                            cooldownFreezeStartedAt: _cooldownFreezeStartedAt,
                          ),
                          separatorBuilder: (context, index) => Gap(18),
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          itemCount: viewModel.posts.length,
                          itemBuilder: (context, index) {
                            final post = viewModel.posts[index];
                            return PostCardWidget(
                              post: post,
                              onReported: _onPostReported,
                            );
                          },
                        ),
                        if (_showReportSuccessBanner)
                          Positioned(
                            top: 16,
                            left: 20,
                            right: 20,
                            child: ReportedPostCardWidget(
                              onClose: _dismissReportSuccessBanner,
                            ),
                          ),
                      ],
                    );
                  },
                  loadingError: (message) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.error,
                        ),
                        const Gap(16),
                        Text(
                          'Error loading posts',
                          style: TextStyles.titleHeadline.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          message,
                          style: TextStyles.bodyMain.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
