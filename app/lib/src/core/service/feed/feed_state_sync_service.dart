import 'dart:async';

import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/utils/device_id.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class FeedStateSyncService with WidgetsBindingObserver {
  FeedStateSyncService();

  static const Duration _syncInterval = Duration(seconds: 15);
  static const int _periodicDeltaSeconds = 15;
  static const Duration _minSyncGap = Duration(seconds: 2);

  final DeviceId _deviceId = DeviceId();

  Timer? _timer;
  GoRouter? _router;
  String _currentPath = RoutePaths.initial;
  String? _cachedDeviceId;
  DateTime? _lastSyncAt;
  DateTime? _lastAttemptAt;
  bool _isAppForeground = true;
  bool _syncInFlight = false;
  bool _started = false;
  bool _disposed = false;

  void start(GoRouter router) {
    if (_disposed || _started) {
      return;
    }

    _started = true;
    _router = router;
    _currentPath = _readCurrentPath(router);
    _lastSyncAt = DateTime.now();

    WidgetsBinding.instance.addObserver(this);
    router.routerDelegate.addListener(_onRouteChanged);

    _timer = Timer.periodic(_syncInterval, (_) {
      unawaited(_syncNow());
    });

    unawaited(_syncNow(force: true));
  }

  void stop() {
    if (!_started) {
      return;
    }

    _started = false;
    _timer?.cancel();
    _timer = null;

    final router = _router;
    if (router != null) {
      router.routerDelegate.removeListener(_onRouteChanged);
    }
    _router = null;

    WidgetsBinding.instance.removeObserver(this);
  }

  void dispose() {
    if (_disposed) {
      return;
    }

    stop();
    _disposed = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppForeground = true;
      unawaited(_syncNow(force: true));
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _isAppForeground = false;
    }
  }

  void _onRouteChanged() {
    final router = _router;
    if (router == null) {
      return;
    }

    final nextPath = _readCurrentPath(router);
    if (_currentPath == nextPath) {
      return;
    }

    _currentPath = nextPath;
    unawaited(_syncNow(force: true));
  }

  String _readCurrentPath(GoRouter router) {
    final uri = router.routeInformationProvider.value.uri;
    final path = uri.path;
    if (path.isEmpty) {
      return RoutePaths.initial;
    }
    return path;
  }

  bool _isFeedRoute(String path) {
    return path == RoutePaths.home;
  }

  bool _isSyncEligiblePath(String path) {
    return path.startsWith(RoutePaths.home) ||
        path.startsWith(RoutePaths.map) ||
        path.startsWith(RoutePaths.rating) ||
        path.startsWith(RoutePaths.chats) ||
        path.startsWith(RoutePaths.profile) ||
        path.startsWith(RoutePaths.createPost) ||
        path.startsWith(RoutePaths.notifications) ||
        path.startsWith(RoutePaths.search) ||
        path.startsWith(RoutePaths.store) ||
        path.startsWith(RoutePaths.profilePublications);
  }

  String _appSectionForPath(String path) {
    if (path.startsWith(RoutePaths.home)) {
      return 'feed';
    }
    if (path.startsWith(RoutePaths.map)) {
      return 'map';
    }
    if (path.startsWith(RoutePaths.profile)) {
      return 'profile';
    }
    if (path.startsWith(RoutePaths.chats)) {
      return 'chats';
    }
    if (path.startsWith(RoutePaths.rating)) {
      return 'rating';
    }
    return 'background';
  }

  Future<void> _syncNow({bool force = false}) async {
    if (!_started || _syncInFlight) {
      return;
    }

    if (!_isAppForeground && !force) {
      return;
    }

    final path = _currentPath;
    if (!_isSyncEligiblePath(path)) {
      _lastSyncAt = DateTime.now();
      return;
    }

    final now = DateTime.now();
    final lastAttemptAt = _lastAttemptAt;
    if (!force &&
        lastAttemptAt != null &&
        now.difference(lastAttemptAt) < _minSyncGap) {
      return;
    }

    final lastSyncAt = _lastSyncAt ?? now;
    final elapsedSeconds = now.difference(lastSyncAt).inSeconds;
    final deltaSeconds = force
      ? elapsedSeconds.clamp(1, 15)
      : _periodicDeltaSeconds;

    _lastAttemptAt = now;
    _lastSyncAt = now;
    _syncInFlight = true;

    try {
      HomeBloc? homeBloc;
      try {
        homeBloc = getIt<HomeBloc>();
      } catch (_) {
        return;
      }

      final deviceId = _cachedDeviceId ?? await _deviceId.getDeviceId();
      _cachedDeviceId = deviceId;

      if (homeBloc.isClosed) {
        try {
          homeBloc = getIt<HomeBloc>();
        } catch (_) {
          return;
        }
      }

      if (homeBloc.isClosed) {
        return;
      }

      homeBloc.add(
        HomeEvent.syncFeedState(
          deltaSeconds: deltaSeconds,
          deviceId: deviceId,
          isFeedActive: _isFeedRoute(path),
          appSection: _appSectionForPath(path),
        ),
      );
    } finally {
      _syncInFlight = false;
    }
  }
}
