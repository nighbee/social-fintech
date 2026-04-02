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
  static const int _defaultCooldownSeconds = 5 * 60;

  final HomeBloc _homeBloc = getIt<HomeBloc>();
  final DeviceId _deviceId = DeviceId();
  Timer? _feedStateSyncTimer;
  Timer? _reportSuccessTimer;
  String? _cachedDeviceId;
  bool _showReportSuccessBanner = false;
  bool _isAppForeground = true;
  bool _isFeedTabVisible = true;
  bool _forceSyncAfterResume = false;
  DateTime? _cooldownFreezeStartedAt;
  int? _localCooldownRemainingSeconds;
  DateTime? _appBackgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeBloc.add(const HomeEvent.loadStoreSummary());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_startFeedStateSync());
    });
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
      if (_appBackgroundedAt != null) {
        final elapsed = DateTime.now().difference(_appBackgroundedAt!);
        _advanceLocalCooldown(elapsed.inSeconds);
      }
      _appBackgroundedAt = null;
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
      _appBackgroundedAt ??= DateTime.now();
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
    _advanceLocalCooldown(_syncDeltaSeconds);
    unawaited(_syncFeedStateOnce(deltaSeconds: _syncDeltaSeconds));
  }

  FeedStateEntity _feedStateFromState(HomeState state) {
    return state.maybeWhen(
      loading: (viewModel) => viewModel.feedState,
      loaded: (viewModel) => viewModel.feedState,
      orElse: FeedStateEntity.empty,
    );
  }

  bool _hasLocalCooldown() {
    final local = _localCooldownRemainingSeconds;
    return local != null && local > 0;
  }

  bool _isCooldownActiveFromState(HomeState state) {
    if (_hasLocalCooldown()) {
      return true;
    }
    final feedState = _feedStateFromState(state);
    return feedState.shouldEnforceCooldown;
  }

  int _effectiveBreakSecondsFromState(HomeState state) {
    final local = _localCooldownRemainingSeconds;
    if (local != null && local > 0) {
      return local;
    }
    final feedState = _feedStateFromState(state);
    final serverBreak = feedState.safeBreakSecondsRemaining;
    if (feedState.shouldEnforceCooldown && serverBreak <= 0) {
      return _defaultCooldownSeconds;
    }
    return serverBreak;
  }

  bool _shouldFreezeCooldownFromState(HomeState state) {
    if (!_isAppForeground || !_isFeedTabVisible) {
      return false;
    }
    return _isCooldownActiveFromState(state);
  }

  void _updateCooldownFreezeState(HomeState state) {
    _ingestServerCooldownState(state);

    final shouldFreeze = _shouldFreezeCooldownFromState(state);
    if (shouldFreeze) {
      _cooldownFreezeStartedAt ??= DateTime.now();
      return;
    }
    _cooldownFreezeStartedAt = null;
  }

  void _ingestServerCooldownState(HomeState state) {
    final feedState = _feedStateFromState(state);
    if (feedState.shouldEnforceCooldown) {
      final serverBreak = feedState.safeBreakSecondsRemaining;
      final seeded = serverBreak > 0 ? serverBreak : _defaultCooldownSeconds;
      final local = _localCooldownRemainingSeconds;
      if (local == null || local <= 0) {
        _localCooldownRemainingSeconds = seeded;
      } else if (!_shouldFreezeCooldownFromState(state)) {
        _localCooldownRemainingSeconds = seeded;
      } else if (seeded > local) {
        _localCooldownRemainingSeconds = seeded;
      }
      return;
    }

    if (!_isAppForeground || !_isFeedTabVisible) {
      _localCooldownRemainingSeconds = 0;
    }
  }

  void _advanceLocalCooldown(int deltaSeconds) {
    if (deltaSeconds <= 0 || !_hasLocalCooldown()) {
      return;
    }
    if (_isAppForeground && _isFeedTabVisible) {
      return;
    }

    final next = (_localCooldownRemainingSeconds! - deltaSeconds)
        .clamp(0, _defaultCooldownSeconds);
    if (next == _localCooldownRemainingSeconds) {
      return;
    }

    if (mounted) {
      setState(() {
        _localCooldownRemainingSeconds = next;
      });
    } else {
      _localCooldownRemainingSeconds = next;
    }

    if (next == 0) {
      _forceSyncAfterResume = true;
    }
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

    if (_isCooldownActiveFromState(HomeState.loaded(viewModel: viewModel))) {
      if (_shouldFreezeCooldownFromState(_homeBloc.state)) {
        return '5 min break';
      }
      final breakMinutes =
          (_effectiveBreakSecondsFromState(HomeState.loaded(viewModel: viewModel)) /
                  60)
              .ceil();
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

    if (_isCooldownActiveFromState(HomeState.loaded(viewModel: viewModel))) {
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
    _isFeedTabVisible = TickerMode.of(context);

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
                            isInCooldown: _isCooldownActiveFromState(
                              HomeState.loaded(viewModel: viewModel),
                            ),
                            breakSecondsRemaining: _effectiveBreakSecondsFromState(
                              HomeState.loaded(viewModel: viewModel),
                            ),
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
