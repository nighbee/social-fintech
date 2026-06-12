import 'dart:async';

import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/service/storage/app_storage/storage_service.dart';
import 'package:app/src/core/service/storage/key_store.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:app/src/features/map/domain/entities/map_region_assignment_entity.dart';
import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_application_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:app/src/features/map/domain/requests/map_nearby_tasks_request.dart';
import 'package:app/src/features/map/domain/requests/map_region_assignment_request.dart';
import 'package:app/src/features/map/domain/requests/map_task_application_id_request.dart';
import 'package:app/src/features/map/domain/requests/map_task_id_request.dart';
import 'package:app/src/features/map/presentation/bloc/map_bloc.dart';
import 'package:app/src/features/map/presentation/models/active_executor_application.dart';
import 'package:app/src/features/map/presentation/services/map_champion_service.dart';
import 'package:app/src/features/map/presentation/services/map_dialog_service.dart';
import 'package:app/src/features/map/presentation/services/map_persistence_service.dart';
import 'package:app/src/features/map/presentation/services/map_polling_service.dart';
import 'package:app/src/features/map/presentation/services/map_request_marker_service.dart';
import 'package:app/src/features/map/presentation/services/map_location_settings.dart';
import 'package:app/src/features/map/presentation/services/map_self_marker_service.dart';
import 'package:app/src/features/map/presentation/utils/map_flow_evaluator.dart';
import 'package:app/src/features/map/presentation/utils/map_marker_zoom_scale.dart';
import 'package:app/src/features/profile/data/local/location_access_prefs.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapPageController {
  MapPageController({
    required MapBloc mapBloc,
    required MapPersistenceService persistence,
    required MapPollingService polling,
    required MapDialogService dialogs,
    required void Function(
      MapChampionEntity champion,
      List<MapChampionEntity> champions,
    ) onChampionTap,
    required void Function(VoidCallback fn) requestSetState,
  })  : _mapBloc = mapBloc,
        _persistence = persistence,
        _polling = polling,
        _dialogs = dialogs,
        _championService = MapChampionService(),
        _requestMarkerService = MapRequestMarkerService(),
        _selfMarkerService = MapSelfMarkerService(),
        _requestSetState = requestSetState,
        _onChampionTapCallback = onChampionTap;

  final MapBloc _mapBloc;
  final MapPersistenceService _persistence;
  final MapPollingService _polling;
  final MapDialogService _dialogs;
  final MapChampionService _championService;
  final MapRequestMarkerService _requestMarkerService;
  final MapSelfMarkerService _selfMarkerService;
  final void Function(VoidCallback fn) _requestSetState;
  final void Function(
    MapChampionEntity champion,
    List<MapChampionEntity> champions,
  ) _onChampionTapCallback;
  MapBloc get mapBloc => _mapBloc;

  MapboxMap? mapboxMap;
  String? selectedApplicationId;
  final Set<String> locallyRejectedApplicationIds = <String>{};
  String? handledCancelResult;
  String? handledApplyApplicationId;
  String? handledConfirmResultTaskId;
  DateTime? lastExecutorCompletionCheckAt;
  bool executorCompletionShown = false;
  bool executorFlowDismissed = false;
  String executorTaskStatus = '';
  String executorCreatorName = '';
  String executorCreatorAvatarUrl = '';
  bool _executorRejectedDialogShownThisSession = false;
  String? handledTaskApplicationActionResult;
  final Set<String> locallyCanceledExecutorApplicationIds = <String>{};
  int consecutiveMissingAppliedTaskChecks = 0;
  double currentLatitude = 43.2567;
  double currentLongitude = 76.9286;
  double? _deviceLatitude;
  double? _deviceLongitude;
  var _didAssignRegionWithDeviceLocation = false;
  var _didCameraFollowFirstDeviceFix = false;
  bool isRequestExpanded = false;
  Offset myRequestPanelOffset = Offset.zero;
  String? _lastChampionsRegionKey;
  DateTime? _lastEmptyChampionsFetchAt;
  String? _lastHandledAutoClosedTaskId;
  String? _lastHandledVerifiedApplicationId;
  String? _lastSelfPinAvatarUrl;
  DateTime? _lastCreatorTaskCreatedAtUtc;
  String? selectedNearbyTaskId;
  final Set<String> _locallyBlockedNearbyTaskIds = <String>{};
  DateTime? _lastMarkerSelectionAt;
  Future<void>? _teardownFuture;
  int? _lastMarkerZoomStep;
  double _lastCameraZoom = 14.5;
  Timer? _cameraGeoRefreshDebounce;
  Timer? _styleRepairDebounce;
  double? _lastRegionAssignLat;
  double? _lastRegionAssignLon;
  bool _styleRepairInProgress = false;
  DateTime? _lastStyleRepairAt;
  int? _stickyChampionResolution;
  int? _fallbackChampionResolution;
  bool? _lastLocationOptInSent;
  bool _didCheckInitialLocationOnboarding = false;
  DateTime? _lastExecutorRestoreAttemptAt;
  String? _lastExecutorRestoreAttemptUserId;
  String? _lastKnownExecutorTaskId;
  String? _lastKnownExecutorApplicationId;

  static const double _regionReassignDistanceMeters = 450;
  static const Duration _cameraGeoRefreshDebounceDuration =
      Duration(milliseconds: 650);
  static const Duration _styleRepairCooldown = Duration(seconds: 8);

  DateTime? get lastCreatorTaskCreatedAtUtc => _lastCreatorTaskCreatedAtUtc;
  String? get currentUserAvatarUrl => _resolveProfileAvatarUrl();

  String? _resolveCurrentUserId() {
    // Auth state is the source of truth for current session identity.
    // Profile bloc can be briefly stale during account switch.
    final fromAuth = getIt<AuthBloc>().state.maybeWhen(
          authenticated: (login) => login.user.id,
          orElse: () => null,
        );
    final authId = fromAuth?.trim();
    if (authId != null && authId.isNotEmpty) {
      return authId;
    }

    final fromProfile = getIt<ProfileBloc>().state.maybeWhen(
          loaded: (vm) => vm.profile.userId,
          loading: (vm) => vm.profile.userId,
          orElse: () => null,
        );
    final profileId = fromProfile?.trim();
    if (profileId != null && profileId.isNotEmpty) {
      return profileId;
    }
    return null;
  }

  void onInit() {
    _lastChampionsRegionKey = null;
    _lastEmptyChampionsFetchAt = null;
    _mapBloc.add(const MapEvent.loadMap());
    unawaited(_persistence.clearLegacyGlobalExecutorApplication());
    unawaited(_restoreSavedMapCenter());
    unawaited(_restoreLastCreatorTaskCreatedAt());
    unawaited(_restoreActiveExecutorApplication());
    _mapBloc.add(const MapEvent.getMyTasks());
    _mapBloc.add(const MapEvent.getAppliedTasks());
  }

  Future<void> teardownMapResources() {
    return _teardownFuture ??= _teardownMapResourcesOnce();
  }

  void onDispose() {
    unawaited(teardownMapResources());
  }

  Future<void> _teardownMapResourcesOnce() async {
    _cameraGeoRefreshDebounce?.cancel();
    _cameraGeoRefreshDebounce = null;
    _styleRepairDebounce?.cancel();
    _styleRepairDebounce = null;
    _polling.dispose();
    _lastMarkerZoomStep = null;
    _stickyChampionResolution = null;
    _fallbackChampionResolution = null;
    await _championService.dispose();
    await _requestMarkerService.dispose();
    await _selfMarkerService.dispose();
    mapboxMap = null;
  }

  void toggleRequestExpanded() {
    isRequestExpanded = !isRequestExpanded;
  }

  void updateMyRequestPanelOffset(DragUpdateDetails details) {
    final next = myRequestPanelOffset + details.delta;
    myRequestPanelOffset = Offset(
      next.dx.clamp(-48.0, 48.0),
      next.dy.clamp(-140.0, 36.0),
    );
  }

  void resetMyRequestPanelOffset() {
    myRequestPanelOffset = Offset.zero;
  }

  void selectNearbyTask(String taskId) {
    selectedNearbyTaskId = selectedNearbyTaskId == taskId ? null : taskId;
    unawaited(_requestMarkerService.setSelectedTask(selectedNearbyTaskId));
  }

  void applyToNearbyTask(MapTaskEntity task) {
    bool containsAny(String value, List<String> tokens) {
      for (final token in tokens) {
        if (value.contains(token)) {
          return true;
        }
      }
      return false;
    }

    final normalizedTaskStatus = task.status.trim().toLowerCase();
    final normalizedApplicationStatus = task.applicationStatus.trim().toLowerCase();
    final isTaskClosed = containsAny(
      normalizedTaskStatus,
      <String>['cancelled', 'canceled', 'completed', 'closed'],
    );
    final isTaskAlreadyAssigned = containsAny(
      normalizedTaskStatus,
      <String>[
        'accepted',
        'assigned',
        'arrived',
        'in_progress',
        'code_required',
        'code_verified',
        'confirmed',
      ],
    );
    final isAlreadyRejected = containsAny(
      normalizedApplicationStatus,
      <String>['rejected', 'declined', 'withdrawn'],
    );
    final isApplicationAlreadyAssigned = containsAny(
      normalizedApplicationStatus,
      <String>[
        'accepted',
        'assigned',
        'arrived',
        'in_progress',
        'code_required',
        'code_verified',
        'confirmed',
      ],
    );
    final isTaskFull =
        task.workersNeeded > 0 && task.workersFilled >= task.workersNeeded;
    final isLocallyBlocked = _locallyBlockedNearbyTaskIds.contains(task.id);
    final activeApply = _mapBloc.viewModel.applyToTaskResult;
    final hasActiveSameTaskApplication =
        activeApply.taskId == task.id &&
            activeApply.applicationId.trim().isNotEmpty &&
            !containsAny(
              activeApply.status.trim().toLowerCase(),
              <String>['rejected', 'declined', 'withdrawn', 'completed'],
            );
    if (isTaskClosed ||
        isTaskAlreadyAssigned ||
        isAlreadyRejected ||
        isApplicationAlreadyAssigned ||
        isTaskFull ||
        isLocallyBlocked ||
        hasActiveSameTaskApplication) {
      return;
    }

    final creatorName = task.creatorUsername.trim();
    final creatorAvatarUrl = task.creatorAvatarUrl.trim();
    if (creatorName.isNotEmpty) {
      executorCreatorName = creatorName;
    }
    if (creatorAvatarUrl.isNotEmpty) {
      executorCreatorAvatarUrl = creatorAvatarUrl;
    }
    _mapBloc.add(MapEvent.applyToTask(MapTaskIdRequest(taskId: task.id)));
  }

  void clearNearbyTaskSelection() {
    final lastMarkerTap = _lastMarkerSelectionAt;
    if (lastMarkerTap != null &&
        DateTime.now().difference(lastMarkerTap) <
            const Duration(milliseconds: 180)) {
      return;
    }
    selectedNearbyTaskId = null;
    if (isRequestExpanded) {
      isRequestExpanded = false;
    }
    unawaited(_requestMarkerService.clearSelection());
  }

  Future<void> onLoadingError(BuildContext context, String message) async {
    final lower = message.toLowerCase();
    if (lower.contains('code')) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> onLoaded(
    BuildContext context,
    MapViewModel viewModel, {
    required void Function(VoidCallback fn) runSetState,
    required bool mounted,
    required Future<void> Function() onNavigateExecutorCompleted,
  }) async {
    unawaited(_tryShowInitialLocationOnboarding(context));
    _tryRestoreActiveExecutorApplicationIfNeeded(viewModel);
    _rememberExecutorApplication(viewModel);
    _tryRehydrateExecutorFromLastKnown(viewModel);
    _rememberLatestCreatorTaskCreatedAt(viewModel);

    if (MapFlowEvaluator.findCreatorActiveTask(viewModel.myTasks) == null &&
        myRequestPanelOffset != Offset.zero) {
      myRequestPanelOffset = Offset.zero;
      _requestSetState(() {});
    }

    final nearbyForMarkers = _nearbyTasksWithMyStatuses(viewModel);
    _reconcileSelectedNearbyTask(nearbyForMarkers);
    await _requestMarkerService.syncTasks(nearbyForMarkers);
    await _requestMarkerService.setSelectedTask(selectedNearbyTaskId);
    _ensureChampionsLoaded(viewModel);
    _refreshTaskApplications(viewModel);
    await _tryHandleCreatorAutoClosedTask(context, viewModel);
    await _tryShowCreatorConfirmDialog(context, viewModel);
    await _tryCheckExecutorCompletion(
      context,
      viewModel,
      runSetState: runSetState,
      mounted: mounted,
      onNavigateExecutorCompleted: onNavigateExecutorCompleted,
    );

    await _tryShowExecutorRejectedDialog(context, viewModel);

    if (viewModel.cancelTaskResult.isNotEmpty &&
        viewModel.cancelTaskResult != handledCancelResult) {
      handledCancelResult = viewModel.cancelTaskResult;
      context.push(RoutePaths.mapRequestCanceled);
    }

    if (viewModel.confirmCompletionResult.taskId.isNotEmpty &&
        viewModel.confirmCompletionResult.taskId !=
            handledConfirmResultTaskId) {
      handledConfirmResultTaskId = viewModel.confirmCompletionResult.taskId;
      selectedApplicationId = null;
      _mapBloc.add(const MapEvent.getMyTasks());
      _mapBloc.add(const MapEvent.getAppliedTasks());
      _refreshNearbyTasks();
      context.push(RoutePaths.mapRequestCompleted);
    }

    final verifyApplicationId = viewModel.verifyCodeResult.applicationId;
    final verifyStatus = viewModel.verifyCodeResult.status.trim().toLowerCase();
    if (verifyApplicationId.isNotEmpty &&
        verifyStatus == 'code_verified' &&
        verifyApplicationId != _lastHandledVerifiedApplicationId) {
      _lastHandledVerifiedApplicationId = verifyApplicationId;
      unawaited(_clearActiveExecutorApplication());
    }

    if (viewModel.applyToTaskResult.applicationId.isNotEmpty &&
        viewModel.applyToTaskResult.applicationId !=
            handledApplyApplicationId) {
      handledApplyApplicationId = viewModel.applyToTaskResult.applicationId;
      executorTaskStatus = viewModel.applyToTaskResult.status;
      executorFlowDismissed = false;
      final taskId = viewModel.applyToTaskResult.taskId.trim();
      final selectedTaskId = selectedNearbyTaskId?.trim() ?? '';
      final lookupTaskId = taskId.isNotEmpty ? taskId : selectedTaskId;
      final nearbyTask = viewModel.nearbyTasks.cast<MapTaskEntity?>().firstWhere(
            (task) => task?.id == lookupTaskId,
            orElse: () => null,
          );
      final creatorName = nearbyTask?.creatorUsername.trim() ?? '';
      final creatorAvatarUrl = nearbyTask?.creatorAvatarUrl.trim() ?? '';
      if (creatorName.isNotEmpty) {
        executorCreatorName = creatorName;
      }
      if (creatorAvatarUrl.isNotEmpty) {
        executorCreatorAvatarUrl = creatorAvatarUrl;
      }
      consecutiveMissingAppliedTaskChecks = 0;
      _dialogs.resetRejectedHandledId();
      final persistTaskId = taskId.isNotEmpty ? taskId : selectedTaskId;
      if (persistTaskId.isNotEmpty) {
        unawaited(
          _persistActiveExecutorApplication(
            persistTaskId,
            viewModel.applyToTaskResult.applicationId,
          ),
        );
      }
    }

    if (viewModel.taskApplicationActionResult.isEmpty) {
      handledTaskApplicationActionResult = null;
    } else if (viewModel.taskApplicationActionResult !=
        handledTaskApplicationActionResult) {
      handledTaskApplicationActionResult =
          viewModel.taskApplicationActionResult;
      _handleTaskApplicationActionResult(
        context,
        viewModel,
        runSetState: runSetState,
      );
    }

    // Чемпионы: пустой список тоже синхронизировать (убрать старые пины после loadMap).
    final championsForViewport = _championsForCurrentZoom(viewModel.champions);
    unawaited(
      _championService.updateChampions(
        championsForViewport,
        viewModel.assignedRegion,
        fallbackLatitude: currentLatitude,
        fallbackLongitude: currentLongitude,
      ),
    );

    final avatar = _resolveProfileAvatarUrl();
    if (avatar != _lastSelfPinAvatarUrl) {
      _lastSelfPinAvatarUrl = avatar;
      unawaited(_selfMarkerService.reloadAppearance(avatarUrl: avatar));
    }
  }

  Future<void> _tryShowInitialLocationOnboarding(BuildContext context) async {
    if (_didCheckInitialLocationOnboarding) {
      return;
    }
    final userId = _resolveCurrentUserId();
    if (userId == null) {
      return;
    }
    _didCheckInitialLocationOnboarding = true;
    final isShown =
        await _persistence.isLocationOnboardingShown(userId: userId);
    if (isShown || !context.mounted) {
      return;
    }

    await _persistence.markLocationOnboardingShown(userId: userId);
    if (!context.mounted) {
      return;
    }
    final shouldRequestPermission =
        await _dialogs.showInitialLocationOnboardingDialog(context);
    if (!context.mounted) {
      return;
    }

    await prefsInstance.initialize();
    if (shouldRequestPermission) {
      await writeLocationAccessPrefs(
        label: 'While using the app',
        precise: true,
      );
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.deniedForever &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location access was denied permanently. You can enable it in Settings.',
            ),
          ),
        );
      }
      if (!context.mounted) {
        return;
      }
      await moveToCurrentLocation(context);
    } else {
      await writeLocationAccessPrefs(label: 'Never', precise: false);
      _maybeAssignRegionForCurrentGeoContext(force: true);
    }
  }

  Future<void> _restoreLastCreatorTaskCreatedAt() async {
    final userId = _resolveCurrentUserId();
    if (userId == null) {
      return;
    }
    final restored = await _persistence.readLastCreatorTaskCreatedAt(
      userId: userId,
    );
    if (restored == null) {
      return;
    }
    _lastCreatorTaskCreatedAtUtc = restored;
  }

  void _rememberLatestCreatorTaskCreatedAt(MapViewModel viewModel) {
    DateTime? latest;

    for (final task in viewModel.myTasks) {
      final parsed = DateTime.tryParse(task.createdAt)?.toUtc();
      if (parsed == null) {
        continue;
      }
      if (latest == null || parsed.isAfter(latest)) {
        latest = parsed;
      }
    }

    for (final task in viewModel.nearbyTasks) {
      final status = task.status.trim().toLowerCase();
      if (!status.startsWith('mine|')) {
        continue;
      }
      final parsed = DateTime.tryParse(task.createdAt)?.toUtc();
      if (parsed == null) {
        continue;
      }
      if (latest == null || parsed.isAfter(latest)) {
        latest = parsed;
      }
    }

    if (latest == null) {
      return;
    }

    final known = _lastCreatorTaskCreatedAtUtc;
    if (known != null &&
        (latest.isBefore(known) || latest.isAtSameMomentAs(known))) {
      return;
    }

    _lastCreatorTaskCreatedAtUtc = latest;
    final userId = _resolveCurrentUserId();
    if (userId == null) {
      return;
    }
    unawaited(
      _persistence.writeLastCreatorTaskCreatedAt(
        latest,
        userId: userId,
      ),
    );
  }

  /// В nearby с бэка часто `open`, а в myTasks — `mine|…`; иначе маркер моргает «чужой → свой».
  List<MapTaskEntity> _nearbyTasksWithMyStatuses(MapViewModel viewModel) {
    final nearby = viewModel.nearbyTasks;
    final my = viewModel.myTasks;
    if (my.isEmpty) {
      return nearby;
    }
    final byId = {for (final t in my) t.id: t};
    final merged = <MapTaskEntity>[
      for (final t in nearby) _applyMyTaskStatusIfSameId(t, byId[t.id]),
    ];

    // Keep creator task marker visible even when backend temporarily omits it
    // from /tasks/nearby (while /tasks/my already has it).
    for (final mine in my) {
      final status = mine.status.trim().toLowerCase();
      final isClosed = status == 'completed' || status == 'cancelled';
      final existsInNearby = merged.any((task) => task.id == mine.id);
      if (!isClosed && !existsInNearby) {
        merged.add(mine);
      }
    }

    return merged;
  }

  MapTaskEntity _applyMyTaskStatusIfSameId(
    MapTaskEntity nearby,
    MapTaskEntity? mine,
  ) {
    if (mine == null || mine.id != nearby.id) {
      return nearby;
    }
    return nearby.copyWith(status: mine.status);
  }

  String? _resolveProfileAvatarUrl() {
    return getIt<ProfileBloc>().state.maybeWhen(
              loaded: (vm) {
                final u = vm.profile.avatarUrl;
                return u.isEmpty ? null : u;
              },
              loading: (vm) {
                final u = vm.profile.avatarUrl;
                return u.isEmpty ? null : u;
              },
              orElse: () => null,
            ) ??
        getIt<AuthBloc>().state.maybeWhen(
              authenticated: (login) {
                final u = login.user.avatarUrl;
                return u.isEmpty ? null : u;
              },
              orElse: () => null,
            );
  }

  void onMapCreated(MapboxMap map) {
    mapboxMap = map;
    unawaited(_configureMapOrnaments(map));
    unawaited(
      map.location.updateSettings(
        LocationComponentSettings(enabled: false),
      ),
    );
    // Синхронизируем камеру с контроллером (в т.ч. после readSavedCenter):
    // раньше hasSavedCenter после restore блокировал первый реальный GPS.
    final initialZoom = _mapBloc.viewModel.zoom.clamp(1.5, 20.0).toDouble();
    unawaited(
      map.easeTo(
        CameraOptions(
          center:
              Point(coordinates: Position(currentLongitude, currentLatitude)),
          zoom: initialZoom,
        ),
        MapAnimationOptions(duration: 450),
      ),
    );

    // Чемпионы: сначала создаём менеджер аннотаций, иначе onLoaded мог вызвать
    // updateChampions раньше — там manager == null и пины тихо не создаются.
    unawaited(_initChampionLayer(map));

    _refreshNearbyTasks();
    _polling.startNearbyRefreshTimer(
      interval: const Duration(seconds: 15),
      onTick: _refreshNearbyTasks,
    );

    // Load champions for initial region
    unawaited(_loadChampionsForCurrentRegion());
    unawaited(
      _requestMarkerService.initialize(
        map,
        onSelectionChanged: _onRequestMarkerSelectionChanged,
      ),
    );

    unawaited(_initSelfMarker(map));
    unawaited(_watchForLateFirstGpsCameraSync());
    unawaited(_syncMarkerScaleToCamera(map));
  }

  Future<void> _configureMapOrnaments(MapboxMap map) async {
    await Future.wait<void>([
      map.scaleBar.updateSettings(ScaleBarSettings(enabled: false)),
      map.compass.updateSettings(CompassSettings(enabled: false)),
      map.logo.updateSettings(
        LogoSettings(
          position: OrnamentPosition.BOTTOM_LEFT,
          marginLeft: 12,
          marginBottom: 82,
        ),
      ),
      map.attribution.updateSettings(
        AttributionSettings(
          position: OrnamentPosition.BOTTOM_RIGHT,
          marginRight: 12,
          marginBottom: 82,
        ),
      ),
    ]);
  }

  void onStyleLoaded(StyleLoadedEventData _) {
    _queueStyleRepair('style_loaded');
  }

  void onStyleImageMissing(StyleImageMissingEventData event) {
    debugPrint('[MapController] style image missing: ${event.id}');
    final lastRepairAt = _lastStyleRepairAt;
    if (lastRepairAt != null &&
        DateTime.now().difference(lastRepairAt) < _styleRepairCooldown) {
      return;
    }
    _queueStyleRepair('style_image_missing:${event.id}');
  }

  void _queueStyleRepair(String reason) {
    _styleRepairDebounce?.cancel();
    _styleRepairDebounce = Timer(const Duration(milliseconds: 120), () {
      unawaited(_repairStyleImages(reason));
    });
  }

  Future<void> _repairStyleImages(String reason) async {
    if (_styleRepairInProgress) {
      return;
    }
    final map = mapboxMap;
    if (map == null) {
      return;
    }
    _styleRepairInProgress = true;
    _lastStyleRepairAt = DateTime.now();
    try {
      debugPrint('[MapController] repairing style images due to: $reason');

      await _initChampionLayer(map);

      await _requestMarkerService.initialize(
        map,
        onSelectionChanged: _onRequestMarkerSelectionChanged,
      );
      final vm = _mapBloc.viewModel;
      await _requestMarkerService.syncTasks(_nearbyTasksWithMyStatuses(vm));
      await _requestMarkerService.setSelectedTask(selectedNearbyTaskId);

      await _selfMarkerService.initialize(map);
      final lat = _deviceLatitude;
      final lon = _deviceLongitude;
      if (lat != null && lon != null) {
        await _selfMarkerService.updatePosition(
          lat,
          lon,
          avatarUrl: _resolveProfileAvatarUrl(),
        );
      }
    } catch (error) {
      debugPrint('[MapController] style repair failed: $error');
    } finally {
      _styleRepairInProgress = false;
    }
  }

  Future<void> _syncMarkerScaleToCamera(MapboxMap map) async {
    try {
      final cam = await map.getCameraState();
      _lastMarkerZoomStep = (cam.zoom * 40).round();
      final m = mapMarkerSizeMultiplier(cam.zoom);
      await _applyMarkerSizeMultiplier(m);
    } catch (_) {}
  }

  Future<void> _applyMarkerSizeMultiplier(double multiplier) async {
    try {
      await Future.wait<void>([
        _championService.applyMarkerSizeMultiplier(multiplier),
        _selfMarkerService.applyMarkerSizeMultiplier(multiplier),
        _requestMarkerService.applyMarkerSizeMultiplier(multiplier),
      ]);
    } catch (error) {
      if (_isIgnorableMarkerScaleError(error)) {
        return;
      }
      rethrow;
    }
  }

  bool _isIgnorableMarkerScaleError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('no manager or annotation found') ||
        message.contains('channel-error');
  }

  Future<void> _initChampionLayer(MapboxMap map) async {
    await _championService.initialize(
      map,
      onChampionTap: _onChampionTap,
    );
    final vm = _mapBloc.viewModel;
    final championsForViewport = _championsForCurrentZoom(vm.champions);
    await _championService.updateChampions(
      championsForViewport,
      vm.assignedRegion,
      fallbackLatitude: currentLatitude,
      fallbackLongitude: currentLongitude,
    );
  }

  Future<void> _initSelfMarker(MapboxMap map) async {
    await _selfMarkerService.initialize(map);
    await _selfMarkerService.startLocationUpdates(
      _resolveProfileAvatarUrl,
      onPosition: _onDeviceLocationUpdated,
    );
  }

  /// GPS может прийти после создания карты — пробуем подвинуть камеру в течение ~2 с.
  Future<void> _watchForLateFirstGpsCameraSync() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final lat = _deviceLatitude;
      final lon = _deviceLongitude;
      if (lat != null && lon != null) {
        await _maybeMoveCameraToFirstDeviceFix(lat, lon);
        return;
      }
      if (mapboxMap == null) {
        return;
      }
    }
  }

  Future<void> _maybeMoveCameraToFirstDeviceFix(double lat, double lon) async {
    if (_didCameraFollowFirstDeviceFix) {
      return;
    }
    final map = mapboxMap;
    if (map == null) {
      return;
    }
    _didCameraFollowFirstDeviceFix = true;
    currentLatitude = lat;
    currentLongitude = lon;
    _requestSetState(() {});

    await map.easeTo(
      CameraOptions(
        center: Point(coordinates: Position(lon, lat)),
        zoom: 14.5,
      ),
      MapAnimationOptions(duration: 550),
    );

    await _persistence.writeSavedCenter(lat, lon);
  }

  void _onDeviceLocationUpdated(double lat, double lon) {
    _deviceLatitude = lat;
    _deviceLongitude = lon;
    unawaited(_maybeMoveCameraToFirstDeviceFix(lat, lon));
    _refreshNearbyTasks();
    if (!_didAssignRegionWithDeviceLocation) {
      _didAssignRegionWithDeviceLocation = true;
      _maybeAssignRegionForCurrentGeoContext(force: true);
    }
  }

  // Geo-context should follow visible map area (camera center), not only
  // device GPS, otherwise nearby/champions can look "stuck" in another zone.
  double get _latitudeForGeoContext => currentLatitude;
  double get _longitudeForGeoContext => currentLongitude;

  void onCameraChanged(CameraChangedEventData eventData) {
    currentLatitude = eventData.cameraState.center.coordinates.lat.toDouble();
    currentLongitude = eventData.cameraState.center.coordinates.lng.toDouble();
    final zoom = eventData.cameraState.zoom;
    _lastCameraZoom = zoom;
    final step = (zoom * 40).round();
    if (_lastMarkerZoomStep == step) {
      return;
    }
    _lastMarkerZoomStep = step;
    final m = mapMarkerSizeMultiplier(zoom);
    unawaited(_applyMarkerSizeMultiplier(m));
    _scheduleCameraGeoRefresh();
  }

  List<MapChampionEntity> _championsForCurrentZoom(
    List<MapChampionEntity> champions,
  ) {
    if (champions.length <= 1) {
      return champions;
    }

    final hasApiCoordinates = champions.any(
      (champion) => champion.centerLat != null && champion.centerLon != null,
    );
    if (hasApiCoordinates) {
      return _stableApiChampions(champions);
    }

    if (_championService.isH3RuntimeUnavailable) {
      final stableResolution = _resolveFallbackChampionResolution(champions);
      final tier = champions
          .where((champion) => champion.resolution == stableResolution)
          .toList(growable: false);
      if (tier.isNotEmpty) {
        return tier;
      }
    }

    const upTo5 = 14.4;
    const downTo4 = 13.6;
    const upTo4 = 11.4;
    const downTo2 = 10.6;

    var targetResolution = _stickyChampionResolution;
    final zoom = _lastCameraZoom;

    if (targetResolution == null) {
      if (zoom >= 14.0) {
        targetResolution = 5;
      } else if (zoom >= 11.0) {
        targetResolution = 4;
      } else {
        targetResolution = 2;
      }
    } else if (targetResolution == 5) {
      if (zoom < downTo4) {
        targetResolution = 4;
      }
    } else if (targetResolution == 4) {
      if (zoom >= upTo5) {
        targetResolution = 5;
      } else if (zoom < downTo2) {
        targetResolution = 2;
      }
    } else {
      if (zoom >= upTo4) {
        targetResolution = 4;
      }
    }
    _stickyChampionResolution = targetResolution;

    final preferredOrder = switch (targetResolution) {
      5 => const [5, 4, 2],
      4 => const [4, 5, 2],
      _ => const [2, 4, 5],
    };

    for (final resolution in preferredOrder) {
      final tier = champions
          .where((champion) => champion.resolution == resolution)
          .toList(growable: false);
      if (tier.isNotEmpty) {
        return tier;
      }
    }

    return champions;
  }

  List<MapChampionEntity> _stableApiChampions(
    List<MapChampionEntity> champions,
  ) {
    final stable = champions.toList(growable: false)
      ..sort((a, b) {
        if (a.resolution != b.resolution) {
          return b.resolution.compareTo(a.resolution);
        }
        if (a.score != b.score) {
          return b.score.compareTo(a.score);
        }
        return a.h3Index.compareTo(b.h3Index);
      });
    return stable;
  }

  int _resolveFallbackChampionResolution(List<MapChampionEntity> champions) {
    final current = _fallbackChampionResolution;
    if (current != null &&
        champions.any((champion) => champion.resolution == current)) {
      return current;
    }

    for (final resolution in const [5, 4, 2]) {
      if (champions.any((champion) => champion.resolution == resolution)) {
        _fallbackChampionResolution = resolution;
        return resolution;
      }
    }

    _fallbackChampionResolution = champions.first.resolution;
    return _fallbackChampionResolution!;
  }

  void _scheduleCameraGeoRefresh() {
    _cameraGeoRefreshDebounce?.cancel();
    _cameraGeoRefreshDebounce = Timer(_cameraGeoRefreshDebounceDuration, () {
      _refreshNearbyTasks();
      _maybeAssignRegionForCurrentGeoContext();
    });
  }

  void _maybeAssignRegionForCurrentGeoContext({bool force = false}) {
    final lat = _latitudeForGeoContext;
    final lon = _longitudeForGeoContext;
    final locationOptIn = _isLocationOptInEnabled();

    if (!locationOptIn) {
      if (!force && _lastLocationOptInSent == false) {
        return;
      }

      _lastLocationOptInSent = false;
      _mapBloc.add(
        const MapEvent.assignRegion(
          MapRegionAssignmentRequest(
            latitude: 0,
            longitude: 0,
            locationOptIn: false,
            participateDistrict: false,
          ),
        ),
      );
      return;
    }

    if (!force &&
        _lastRegionAssignLat != null &&
        _lastRegionAssignLon != null) {
      final distanceMeters = geo.Geolocator.distanceBetween(
        _lastRegionAssignLat!,
        _lastRegionAssignLon!,
        lat,
        lon,
      );
      if (distanceMeters < _regionReassignDistanceMeters) {
        return;
      }
    }

    _lastRegionAssignLat = lat;
    _lastRegionAssignLon = lon;
    _lastLocationOptInSent = true;
    _mapBloc.add(
      MapEvent.assignRegion(
        MapRegionAssignmentRequest(
          latitude: lat,
          longitude: lon,
          locationOptIn: true,
        ),
      ),
    );
  }

  bool _isLocationOptInEnabled() {
    try {
      final label = prefsInstance.get<String>(KeyStore.locationAccessLabel);
      return (label ?? '').trim() != 'Never';
    } catch (_) {
      // If prefs are unavailable, keep map behavior permissive by default.
      return true;
    }
  }

  void openCreateRequest(BuildContext context) {
    final viewModel = _mapBloc.viewModel;
    if (!viewModel.hasMyTasksLoaded) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checking request availability...'),
          ),
        );
      }
      return;
    }

    final lockMessage = MapFlowEvaluator.buildCreateTaskLockMessage(
      viewModel.myTasks,
      nearbyTasks: viewModel.nearbyTasks,
      nowUtc: DateTime.now().toUtc(),
    );
    if (lockMessage != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lockMessage),
          ),
        );
      }
      return;
    }

    context.push(
      RoutePaths.mapCreateRequest,
      extra: <String, dynamic>{
        'latitude': currentLatitude,
        'longitude': currentLongitude,
      },
    );
  }

  Future<void> zoomBy(double delta) async {
    final map = mapboxMap;
    if (map == null) {
      return;
    }

    final cameraState = await map.getCameraState();
    final nextZoom = (cameraState.zoom + delta).clamp(1.5, 20.0).toDouble();
    await map.easeTo(
      CameraOptions(zoom: nextZoom),
      MapAnimationOptions(duration: 250),
    );
  }

  Future<void> moveToCurrentLocation(BuildContext context) async {
    final map = mapboxMap;
    if (map == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Map is not ready yet.')),
        );
      }
      return;
    }

    try {
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is denied.')),
          );
        }
        return;
      }

      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && defaultTargetPlatform != TargetPlatform.android) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

      final position = await MapGeo.getBestCurrentPosition();

      if (position == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                serviceEnabled
                    ? 'Unable to determine current location.'
                    : 'Turn on location (GPS) in system settings, then try again.',
              ),
            ),
          );
        }
        return;
      }

      final lat = position.latitude;
      final lon = position.longitude;

      _deviceLatitude = lat;
      _deviceLongitude = lon;
      currentLatitude = lat;
      currentLongitude = lon;
      await _persistence.writeSavedCenter(lat, lon);

      if (!_didAssignRegionWithDeviceLocation) {
        _didAssignRegionWithDeviceLocation = true;
        _maybeAssignRegionForCurrentGeoContext(force: true);
      }

      await map.easeTo(
        CameraOptions(
          center: Point(coordinates: Position(lon, lat)),
          zoom: 14.5,
        ),
        MapAnimationOptions(duration: 500),
      );

      unawaited(
        _selfMarkerService.updatePosition(
          lat,
          lon,
          avatarUrl: _resolveProfileAvatarUrl(),
        ),
      );

      _refreshNearbyTasks();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to get current location.')),
        );
      }
    }
  }

  void handleAcceptApplication(
    MapTaskApplicationEntity application, {
    required void Function(VoidCallback fn) runSetState,
  }) {
    final status = application.status.trim().toLowerCase();
    if (status != 'pending') {
      runSetState(() {
        selectedApplicationId = application.id;
      });
      return;
    }

    runSetState(() {
      selectedApplicationId = application.id;
      locallyRejectedApplicationIds.remove(application.id);
      for (final app in _mapBloc.viewModel.taskApplications) {
        if (app.id == application.id) {
          continue;
        }
        final status = app.status.trim().toLowerCase();
        if (status == 'pending' || status.contains('await')) {
          locallyRejectedApplicationIds.add(app.id);
        }
      }
    });

    _mapBloc.add(
      MapEvent.acceptTaskApplication(
        MapTaskApplicationIdRequest(
          taskId: application.taskId,
          applicationId: application.id,
        ),
      ),
    );
  }

  void handleRejectApplication(
    MapTaskApplicationEntity application, {
    required void Function(VoidCallback fn) runSetState,
  }) {
    final status = application.status.trim().toLowerCase();
    if (status != 'pending') {
      runSetState(() {
        selectedApplicationId = application.id;
      });
      return;
    }

    runSetState(() {
      locallyRejectedApplicationIds.add(application.id);
      if (selectedApplicationId == application.id) {
        selectedApplicationId = null;
      }
    });

    _mapBloc.add(
      MapEvent.rejectTaskApplication(
        MapTaskApplicationIdRequest(
          taskId: application.taskId,
          applicationId: application.id,
        ),
      ),
    );
  }

  void handleExecutorCancel(
    BuildContext context,
    MapViewModel viewModel, {
    required void Function(VoidCallback fn) runSetState,
  }) {
    final taskId = viewModel.applyToTaskResult.taskId;
    final applicationId = viewModel.applyToTaskResult.applicationId;
    if (taskId.isEmpty || applicationId.isEmpty) {
      return;
    }

    final appliedStatus =
        viewModel.applyToTaskResult.status.trim().toLowerCase();
    final verifyStatus = viewModel.verifyCodeResult.status.trim().toLowerCase();
    final isCodeVerified =
        (viewModel.verifyCodeResult.applicationId == applicationId &&
                verifyStatus == 'code_verified') ||
            appliedStatus == 'code_verified' ||
            executorTaskStatus.trim().toLowerCase() == 'code_verified';

    // Backend blocks withdraw after code verification; do not hide UI silently.
    if (isCodeVerified) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You cannot withdraw after code verification. Waiting for creator confirmation.',
            ),
          ),
        );
      }
      return;
    }

    unawaited(
      _dialogs.showExecutorCancelConfirmDialog(
        context: context,
        onConfirm: () {
          _mapBloc.add(
            MapEvent.withdrawTaskApplication(
              MapTaskApplicationIdRequest(
                taskId: taskId,
                applicationId: applicationId,
              ),
            ),
          );
        },
      ),
    );
  }

  void dismissExecutorFlowUi({
    required void Function(VoidCallback fn) runSetState,
  }) {
    if (executorFlowDismissed) {
      return;
    }
    runSetState(() {
      executorFlowDismissed = true;
    });
  }

  Future<void> _restoreSavedMapCenter() async {
    final savedCenter = await _persistence.readSavedCenter();
    if (savedCenter == null) {
      return;
    }

    currentLatitude = savedCenter.lat;
    currentLongitude = savedCenter.lon;

    final map = mapboxMap;
    if (map != null) {
      await map.easeTo(
        CameraOptions(
          center:
              Point(coordinates: Position(savedCenter.lon, savedCenter.lat)),
          zoom: 14.5,
        ),
        MapAnimationOptions(duration: 450),
      );
      _refreshNearbyTasks();
    }
  }

  Future<void> _restoreActiveExecutorApplication() async {
    final userId = _resolveCurrentUserId();
    if (userId == null) {
      return;
    }
    final target = await _persistence.readActiveExecutorApplication(
      userId: userId,
    );
    if (target == null) {
      return;
    }
    _mapBloc.add(
      MapEvent.hydrateExecutorApplication(
        MapTaskApplicationIdRequest(
          taskId: target.taskId,
          applicationId: target.applicationId,
        ),
      ),
    );
    _lastKnownExecutorTaskId = target.taskId;
    _lastKnownExecutorApplicationId = target.applicationId;
    // Do not immediately show "awaiting approval" from stale local state.
    // We wait for the next appliedTasks sync to confirm that this application
    // is still active on backend.
    executorFlowDismissed = true;
    executorTaskStatus = '';
  }

  void _tryRestoreActiveExecutorApplicationIfNeeded(MapViewModel viewModel) {
    if (viewModel.applyToTaskResult.applicationId.trim().isNotEmpty) {
      return;
    }
    final userId = _resolveCurrentUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final sameUser = _lastExecutorRestoreAttemptUserId == userId;
    if (sameUser &&
        _lastExecutorRestoreAttemptAt != null &&
        now.difference(_lastExecutorRestoreAttemptAt!) <
            const Duration(seconds: 3)) {
      return;
    }
    _lastExecutorRestoreAttemptUserId = userId;
    _lastExecutorRestoreAttemptAt = now;
    unawaited(_restoreActiveExecutorApplication());
  }

  void _rememberExecutorApplication(MapViewModel viewModel) {
    final taskId = viewModel.applyToTaskResult.taskId.trim();
    final applicationId = viewModel.applyToTaskResult.applicationId.trim();
    if (taskId.isEmpty || applicationId.isEmpty) {
      return;
    }
    _lastKnownExecutorTaskId = taskId;
    _lastKnownExecutorApplicationId = applicationId;
  }

  void _tryRehydrateExecutorFromLastKnown(MapViewModel viewModel) {
    if (viewModel.applyToTaskResult.applicationId.trim().isNotEmpty) {
      return;
    }

    final taskId = _lastKnownExecutorTaskId?.trim() ?? '';
    final applicationId = _lastKnownExecutorApplicationId?.trim() ?? '';
    if (taskId.isEmpty || applicationId.isEmpty) {
      return;
    }

    bool isTerminalStatus(String rawStatus) {
      final normalized = rawStatus.trim().toLowerCase();
      if (normalized.isEmpty) {
        return false;
      }
      return normalized.contains('rejected') ||
          normalized.contains('declined') ||
          normalized.contains('withdrawn') ||
          normalized.contains('cancelled') ||
          normalized.contains('completed') ||
          normalized.contains('confirmed');
    }

    final applied = viewModel.appliedTasks.cast<MapTaskEntity?>().firstWhere(
          (task) => task?.id == taskId,
          orElse: () => null,
        );
    if (applied == null) {
      return;
    }
    if (isTerminalStatus(applied.applicationStatus) ||
        isTerminalStatus(applied.status)) {
      return;
    }

    _mapBloc.add(
      MapEvent.hydrateExecutorApplication(
        MapTaskApplicationIdRequest(
          taskId: taskId,
          applicationId: applicationId,
        ),
      ),
    );
  }

  Future<void> _persistActiveExecutorApplication(
    String taskId,
    String applicationId,
  ) async {
    final userId = _resolveCurrentUserId();
    if (userId == null) {
      return;
    }
    await _persistence.writeActiveExecutorApplication(
      ActiveExecutorApplication(taskId: taskId, applicationId: applicationId),
      userId: userId,
    );
  }

  Future<void> _clearActiveExecutorApplication() async {
    final userId = _resolveCurrentUserId();
    if (userId == null) {
      return;
    }
    await _persistence.clearActiveExecutorApplication(userId: userId);
  }

  void _refreshNearbyTasks() {
    _mapBloc.add(
      MapEvent.getNearbyTasks(
        MapNearbyTasksRequest(
          lat: _latitudeForGeoContext,
          lon: _longitudeForGeoContext,
          radiusM: 2000,
          limit: 50,
        ),
      ),
    );
  }

  void _reconcileSelectedNearbyTask(List<MapTaskEntity> nearbyTasks) {
    final selectedTaskId = selectedNearbyTaskId;
    if (selectedTaskId == null) {
      return;
    }

    for (final task in nearbyTasks) {
      if (task.id == selectedTaskId) {
        return;
      }
    }

    selectedNearbyTaskId = null;
    unawaited(_requestMarkerService.setSelectedTask(null));
  }

  void _refreshTaskApplications(MapViewModel viewModel) {
    _polling.refreshTaskApplicationsIfNeeded(
      myTasks: viewModel.myTasks,
      refreshInterval: const Duration(seconds: 10),
      onNoActiveTask: () {
        selectedApplicationId = null;
        locallyRejectedApplicationIds.clear();
      },
      onRefresh: (taskId) {
        _mapBloc.add(
          MapEvent.getTaskApplications(MapTaskIdRequest(taskId: taskId)),
        );
      },
    );
  }

  Future<void> _tryShowCreatorConfirmDialog(
    BuildContext context,
    MapViewModel viewModel,
  ) async {
    await _dialogs.tryShowCreatorConfirmDialog(
      context: context,
      selectedApplicationId: selectedApplicationId,
      applications: viewModel.taskApplications,
      onConfirm: (selectedApplication) {
        _mapBloc.add(
          MapEvent.confirmTaskApplication(
            MapTaskApplicationIdRequest(
              taskId: selectedApplication.taskId,
              applicationId: selectedApplication.id,
            ),
          ),
        );
      },
    );
  }

  Future<void> _tryHandleCreatorAutoClosedTask(
    BuildContext context,
    MapViewModel viewModel,
  ) async {
    final expired = _findAutoClosedWithoutResponses(viewModel.myTasks);
    if (expired == null) {
      return;
    }
    if (_lastHandledAutoClosedTaskId == expired.id) {
      return;
    }
    _lastHandledAutoClosedTaskId = expired.id;

    await _dialogs.showCreatorNoResponsesDialog(context);
    if (!context.mounted) {
      return;
    }
    context.push(RoutePaths.mapRequestClosed);
  }

  MapTaskEntity? _findAutoClosedWithoutResponses(List<MapTaskEntity> myTasks) {
    final now = DateTime.now().toUtc();
    for (final task in myTasks) {
      final status = task.status.trim().toLowerCase();
      if (status != 'cancelled' && status != 'completed') {
        continue;
      }
      if (task.workersFilled > 0) {
        continue;
      }
      final shutdownAt = DateTime.tryParse(task.autoShutdownAt)?.toUtc();
      if (shutdownAt == null || shutdownAt.isAfter(now)) {
        continue;
      }
      return task;
    }
    return null;
  }

  Future<void> _tryShowExecutorRejectedDialog(
    BuildContext context,
    MapViewModel viewModel,
  ) async {
    if (_executorRejectedDialogShownThisSession) {
      return;
    }
    final rejectedTaskId = viewModel.applyToTaskResult.taskId.trim();
    final rejectedApplicationId =
        viewModel.applyToTaskResult.applicationId.trim();
    // If executor explicitly cancelled their own application, show only the
    // "Request canceled" dialog and never the creator rejection dialog.
    if (rejectedApplicationId.isNotEmpty &&
        locallyCanceledExecutorApplicationIds.contains(rejectedApplicationId)) {
      return;
    }
    final shown = await _dialogs.tryShowExecutorRejectedDialog(
      context: context,
      applicationId: rejectedApplicationId,
      executorCompletionShown: executorCompletionShown,
      executorTaskStatus: executorTaskStatus,
      executorCreatorName: executorCreatorName,
      executorCreatorAvatarUrl: executorCreatorAvatarUrl,
    );
    if (shown) {
      _executorRejectedDialogShownThisSession = true;
      if (rejectedTaskId.isNotEmpty) {
        _locallyBlockedNearbyTaskIds.add(rejectedTaskId);
      }
      unawaited(_clearActiveExecutorApplication());
      executorFlowDismissed = true;
      _mapBloc.add(
        const MapEvent.hydrateExecutorApplication(
          MapTaskApplicationIdRequest(taskId: '', applicationId: ''),
        ),
      );
      _refreshNearbyTasks();
    }
  }

  Future<void> _tryCheckExecutorCompletion(
    BuildContext context,
    MapViewModel viewModel, {
    required void Function(VoidCallback fn) runSetState,
    required bool mounted,
    required Future<void> Function() onNavigateExecutorCompleted,
  }) async {
    if (executorCompletionShown) {
      return;
    }

    final taskId = viewModel.applyToTaskResult.taskId;
    final applicationId = viewModel.applyToTaskResult.applicationId;
    if (taskId.isEmpty || applicationId.isEmpty) {
      consecutiveMissingAppliedTaskChecks = 0;
      if (executorTaskStatus.isNotEmpty && mounted) {
        runSetState(() {
          executorFlowDismissed = false;
          executorTaskStatus = '';
          executorCreatorName = '';
          executorCreatorAvatarUrl = '';
        });
      } else if (executorTaskStatus.isNotEmpty) {
        executorFlowDismissed = false;
        executorTaskStatus = '';
        executorCreatorName = '';
        executorCreatorAvatarUrl = '';
      }
      return;
    }

    if (locallyCanceledExecutorApplicationIds.contains(applicationId)) {
      consecutiveMissingAppliedTaskChecks = 0;
      return;
    }

    final now = DateTime.now();
    if (lastExecutorCompletionCheckAt != null &&
        now.difference(lastExecutorCompletionCheckAt!) <
            const Duration(seconds: 3)) {
      return;
    }
    lastExecutorCompletionCheckAt = now;

    _mapBloc.add(const MapEvent.getAppliedTasks());

    String? matchedTaskStatus;
    String? matchedCreatorName;
    String? matchedCreatorAvatarUrl;
    for (final task in viewModel.appliedTasks) {
      if (task.id == taskId) {
        matchedTaskStatus = task.applicationStatus.trim().isNotEmpty
            ? task.applicationStatus
            : task.status;
        matchedCreatorName = task.creatorUsername;
        matchedCreatorAvatarUrl = task.creatorAvatarUrl;
        break;
      }
    }

    bool isTerminalExecutorStatus(String rawStatus) {
      final normalized = rawStatus.trim().toLowerCase();
      if (normalized.isEmpty) {
        return false;
      }
      return normalized.contains('rejected') ||
          normalized.contains('declined') ||
          normalized.contains('withdrawn') ||
          normalized.contains('completed') ||
          normalized.contains('cancelled') ||
          normalized.contains('confirmed');
    }

    // Fallback for stale local taskId after account switch/recovery:
    // if we track an active application but cannot find it by taskId,
    // and backend has exactly one active applied task, bind flow to it.
    if (matchedTaskStatus == null && viewModel.appliedTasks.isNotEmpty) {
      final activeApplied = viewModel.appliedTasks.where((task) {
        final appStatus = task.applicationStatus.trim().isNotEmpty
            ? task.applicationStatus
            : task.status;
        return !isTerminalExecutorStatus(appStatus);
      }).toList(growable: false);
      if (activeApplied.length == 1) {
        final fallbackTask = activeApplied.first;
        matchedTaskStatus = fallbackTask.applicationStatus.trim().isNotEmpty
            ? fallbackTask.applicationStatus
            : fallbackTask.status;
        matchedCreatorName = fallbackTask.creatorUsername;
        matchedCreatorAvatarUrl = fallbackTask.creatorAvatarUrl;
        if (applicationId.trim().isNotEmpty && fallbackTask.id != taskId) {
          _mapBloc.add(
            MapEvent.hydrateExecutorApplication(
              MapTaskApplicationIdRequest(
                taskId: fallbackTask.id,
                applicationId: applicationId,
              ),
            ),
          );
        }
      }
    }

    String normalizeStatus(String rawStatus) {
      return rawStatus
          .trim()
          .toLowerCase()
          .replaceAll('-', '_')
          .replaceAll(' ', '_');
    }

    bool isPendingLikeStatus(String rawStatus) {
      final normalized = normalizeStatus(rawStatus);
      return normalized.isEmpty ||
          normalized == 'pending' ||
          normalized.contains('await');
    }

    final shouldUseDirectStatus = matchedTaskStatus == null ||
        isPendingLikeStatus(matchedTaskStatus) ||
        isPendingLikeStatus(executorTaskStatus);
    if (shouldUseDirectStatus) {
      final directStatus = await _fetchExecutorApplicationStatusDirect(
        taskId: taskId,
        applicationId: applicationId,
      );
      if (directStatus != null && directStatus.trim().isNotEmpty) {
        matchedTaskStatus = directStatus;
      }
    }

    if (matchedTaskStatus != null) {
      consecutiveMissingAppliedTaskChecks = 0;
    }

    bool isRejectedLikeStatus(String rawStatus) {
      final normalized = normalizeStatus(rawStatus);
      if (normalized.isEmpty) {
        return false;
      }
      return normalized.contains('rejected') ||
          normalized.contains('declined') ||
          normalized.contains('withdrawn');
    }

    if (matchedTaskStatus == 'completed') {
      unawaited(_clearActiveExecutorApplication());
      _lastKnownExecutorTaskId = null;
      _lastKnownExecutorApplicationId = null;
      if (mounted) {
        runSetState(() {
          executorCompletionShown = true;
          executorFlowDismissed = false;
          executorTaskStatus = matchedTaskStatus!;
          executorCreatorName = (matchedCreatorName ?? '').trim();
          executorCreatorAvatarUrl = (matchedCreatorAvatarUrl ?? '').trim();
        });
      } else {
        executorCompletionShown = true;
        executorFlowDismissed = false;
        executorTaskStatus = matchedTaskStatus!;
        executorCreatorName = (matchedCreatorName ?? '').trim();
        executorCreatorAvatarUrl = (matchedCreatorAvatarUrl ?? '').trim();
      }
      unawaited(onNavigateExecutorCompleted());
      return;
    }

    if (matchedTaskStatus != null &&
        matchedTaskStatus != executorTaskStatus &&
        mounted &&
        !executorCompletionShown) {
      final isRejected = isRejectedLikeStatus(matchedTaskStatus);
      if (isRejected) {
        unawaited(_clearActiveExecutorApplication());
        _lastKnownExecutorTaskId = null;
        _lastKnownExecutorApplicationId = null;
      }
      runSetState(() {
        executorFlowDismissed = false;
        executorTaskStatus = matchedTaskStatus!;
        executorCreatorName = (matchedCreatorName ?? '').trim();
        executorCreatorAvatarUrl = (matchedCreatorAvatarUrl ?? '').trim();
      });
      return;
    }

    if (matchedTaskStatus == null &&
        viewModel.hasAppliedTasksLoaded &&
        mounted &&
        !executorCompletionShown) {
      // Do not infer rejection from temporary/missing applied data.
      // Wait for explicit backend status to avoid false "rejected" for
      // already accepted executors.
      return;
    }
  }

  Future<String?> _fetchExecutorApplicationStatusDirect({
    required String taskId,
    required String applicationId,
  }) async {
    final normalizedTaskId = taskId.trim();
    final normalizedApplicationId = applicationId.trim();
    if (normalizedTaskId.isEmpty || normalizedApplicationId.isEmpty) {
      return null;
    }
    try {
      final client = getIt<RestClient>(instanceName: 'DioClient');
      final response = await client.get(
        EndPoints.mapWithdrawTaskApplication(
          normalizedTaskId,
          normalizedApplicationId,
        ),
      );
      return response.fold(
        (_) => null,
        (result) {
          final raw = result.data;
          if (raw is! Map) {
            return null;
          }
          final status = (raw['status'] ?? '').toString().trim();
          return status.isEmpty ? null : status;
        },
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadChampionsForCurrentRegion() async {
    // First, ensure we have an assigned region
    final assignedRegion = _mapBloc.viewModel.assignedRegion;
    final hasAnyRegionIndex = assignedRegion.h3Res5.isNotEmpty ||
        assignedRegion.h3Res4.isNotEmpty ||
        assignedRegion.h3Res2.isNotEmpty;
    if (!hasAnyRegionIndex) {
      _maybeAssignRegionForCurrentGeoContext(force: true);
      return;
    }

    final region = assignedRegion;

    _lastChampionsRegionKey = _regionKey(region);
    _mapBloc.add(const MapEvent.getRegionalChampions());
  }

  void _ensureChampionsLoaded(MapViewModel viewModel) {
    final region = viewModel.assignedRegion;
    final hasAnyRegionIndex = region.h3Res5.isNotEmpty ||
        region.h3Res4.isNotEmpty ||
        region.h3Res2.isNotEmpty;
    if (!hasAnyRegionIndex) {
      return;
    }

    final regionKey = _regionKey(region);
    if (viewModel.champions.isNotEmpty) {
      _lastChampionsRegionKey = regionKey;
      _lastEmptyChampionsFetchAt = null;
      return;
    }

    // Уже запрашивали этого региона и API вернул [] — не ддосить onLoaded, но
    // дать шанс воркеру/БД (повтор раз в 20 с).
    if (_lastChampionsRegionKey == regionKey) {
      final t = _lastEmptyChampionsFetchAt;
      if (t != null &&
          DateTime.now().difference(t) < const Duration(seconds: 20)) {
        return;
      }
    }

    _lastChampionsRegionKey = regionKey;
    _lastEmptyChampionsFetchAt = DateTime.now();
    _mapBloc.add(const MapEvent.getRegionalChampions());
  }

  String _regionKey(MapRegionAssignmentEntity region) {
    return '${region.h3Res5}|${region.h3Res4}|${region.h3Res2}';
  }

  void _onChampionTap(MapChampionEntity champion) {
    _onChampionTapCallback(champion, _mapBloc.viewModel.champions);
  }

  void _onRequestMarkerSelectionChanged(String? selectedTaskId) {
    _lastMarkerSelectionAt = DateTime.now();
    _requestSetState(() {
      selectedNearbyTaskId = selectedTaskId;
    });
  }

  void _handleTaskApplicationActionResult(
    BuildContext context,
    MapViewModel viewModel, {
    required void Function(VoidCallback fn) runSetState,
  }) {
    final action = viewModel.taskApplicationActionResult;
    final hasCreatorActiveTask =
        MapFlowEvaluator.findCreatorActiveTask(viewModel.myTasks) != null;
    if (action == 'withdrawn') {
      final applicationId = viewModel.applyToTaskResult.applicationId;
      unawaited(_clearActiveExecutorApplication());
      _lastKnownExecutorTaskId = null;
      _lastKnownExecutorApplicationId = null;
      runSetState(() {
        executorFlowDismissed = false;
        executorTaskStatus = 'rejected';
        executorCreatorName = '';
        executorCreatorAvatarUrl = '';
        if (applicationId.isNotEmpty) {
          locallyCanceledExecutorApplicationIds.add(applicationId);
        }
      });
      unawaited(_dialogs.showExecutorCanceledDialog(context));
      return;
    }

    if (action == 'accepted' || action == 'rejected') {
      // accepted/rejected is creator-side moderation action for applications.
      // Never mutate executor local flow from this branch unless this account
      // is currently acting as creator for an active request.
      if (!hasCreatorActiveTask) {
        return;
      }
      final taskId = _polling.lastApplicationsTaskId;
      final canRefreshApplications = taskId != null &&
          taskId.isNotEmpty &&
          viewModel.myTasks.any((task) => task.id == taskId);
      if (canRefreshApplications) {
        _mapBloc.add(
          MapEvent.getTaskApplications(MapTaskIdRequest(taskId: taskId)),
        );
      }
      if (context.mounted) {
        _showApplicationActionToast(context, action: action);
      }

      // Keep applied tasks in sync for mixed-role accounts.
      _mapBloc.add(const MapEvent.getAppliedTasks());
      // Backend auto-reject is async; refresh once more shortly after moderation.
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        _mapBloc.add(const MapEvent.getAppliedTasks());
      });
      runSetState(() {});
    }
  }

  void _showApplicationActionToast(
    BuildContext context, {
    required String action,
  }) {
    final isAccepted = action == 'accepted';
    final accent =
        isAccepted ? const Color(0xFF34D399) : const Color(0xFFF59E0B);
    final icon = isAccepted ? Icons.check_circle_outline : Icons.info_outline;
    final message =
        isAccepted ? 'Application accepted' : 'Application rejected';

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 94),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1F232B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.62)),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
