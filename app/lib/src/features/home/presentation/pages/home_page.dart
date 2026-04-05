import 'dart:async';

import 'package:app/src/core/base/base_bloc/bloc/base_bloc_widget.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/features/home/domain/entities/feed_entity.dart';
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
  static const int _defaultCooldownSeconds = 5 * 60;

  final HomeBloc _homeBloc = getIt<HomeBloc>();
  Timer? _reportSuccessTimer;
  bool _showReportSuccessBanner = false;
  bool _isAppForeground = true;
  bool _isFeedTabVisible = true;
  DateTime? _cooldownFreezeStartedAt;
  int? _localCooldownRemainingSeconds;
  DateTime? _appBackgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeBloc.add(const HomeEvent.loadStoreSummary());
    _homeBloc.add(const HomeEvent.loadFeedState());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reportSuccessTimer?.cancel();
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
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _isAppForeground = false;
      _appBackgroundedAt ??= DateTime.now();
    }
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
      // Keep local fallback aligned with backend on every sync so
      // header timer reflects real break progress without visual freezing.
      _localCooldownRemainingSeconds = seeded;
      return;
    }

    // Server is authoritative: clear any local fallback cooldown as soon as
    // backend no longer enforces it.
    _localCooldownRemainingSeconds = 0;
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
      _cooldownFreezeStartedAt = null;
    }
  }

  void _syncFeedVisibilityFromContext(BuildContext context) {
    final isFeedTabVisibleNow = TickerMode.of(context);
    if (_isFeedTabVisible == isFeedTabVisibleNow) {
      return;
    }

    _isFeedTabVisible = isFeedTabVisibleNow;
  }

  String _timerLabelFromViewModel(HomeViewModel viewModel) {
    final feedState = viewModel.feedState;
    if (feedState.serverTimestamp.isEmpty) {
      return '20 min';
    }

    if (_isCooldownActiveFromState(HomeState.loaded(viewModel: viewModel))) {
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

  FeedEntity? _feedForBodyFromState(HomeState state) {
    return state.maybeWhen(
      loading: (viewModel) => viewModel.feed,
      loaded: (viewModel) => viewModel.feed,
      orElse: () => null,
    );
  }

  String? _errorFromState(HomeState state) {
    return state.maybeWhen(
      loadingError: (message) => message,
      orElse: () => null,
    );
  }

  bool _shouldRebuildBody(HomeState previous, HomeState current) {
    final previousFeed = _feedForBodyFromState(previous);
    final currentFeed = _feedForBodyFromState(current);
    if (previousFeed != null && currentFeed != null) {
      return previousFeed != currentFeed;
    }

    final previousError = _errorFromState(previous);
    final currentError = _errorFromState(current);
    if (previousError != null && currentError != null) {
      return previousError != currentError;
    }

    return previous.runtimeType != current.runtimeType;
  }

  bool _shouldRebuildTimer(HomeState previous, HomeState current) {
    return _timerLabelFromState(previous) != _timerLabelFromState(current) ||
        _timerToneFromState(previous) != _timerToneFromState(current) ||
        _silverCountFromState(previous) != _silverCountFromState(current);
  }

  @override
  Widget build(BuildContext context) {
    _syncFeedVisibilityFromContext(context);

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
              buildWhen: _shouldRebuildTimer,
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
          bottomNavigationBar: CustomNavBar(
            currentTab: RoutePaths.home,
          ),
          body: SafeArea(
            child: BaseBlocWidget<HomeBloc, HomeEvent, HomeState>(
              bloc: _homeBloc,
              starterEvent: const HomeEvent.loadPosts(),
              buildWhen: _shouldRebuildBody,
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
                              bloc: _homeBloc,
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
