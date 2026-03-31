import 'dart:async';

import 'package:app/src/core/base/base_bloc/bloc/base_bloc_widget.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/device_id.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/home/presentation/widgets/feed_app_bar.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      unawaited(_syncFeedStateOnce(deltaSeconds: 1));
      _feedStateSyncTimer ??=
          Timer.periodic(_feedStateSyncInterval, (_) => _onSyncTick());
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _feedStateSyncTimer?.cancel();
      _feedStateSyncTimer = null;
    }
  }

  Future<void> _startFeedStateSync() async {
    await _syncFeedStateOnce(deltaSeconds: 1);
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

  Future<void> _syncFeedStateOnce({required int deltaSeconds}) async {
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

    if (feedState.shouldEnforceCooldown &&
        feedState.safeBreakSecondsRemaining > 0) {
      final breakMinutes = (feedState.safeBreakSecondsRemaining / 60).ceil();
      return '$breakMinutes min';
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

    if (feedState.shouldEnforceCooldown &&
        feedState.safeBreakSecondsRemaining > 0) {
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
