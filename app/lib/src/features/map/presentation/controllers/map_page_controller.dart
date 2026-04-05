import 'dart:async';

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
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
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
  String executorTaskStatus = '';
  String executorCreatorName = '';
  String? handledTaskApplicationActionResult;
  final Set<String> locallyCanceledExecutorApplicationIds = <String>{};
  int consecutiveMissingAppliedTaskChecks = 0;
  double currentLatitude = 50.4501;
  double currentLongitude = 30.5234;
  double? _deviceLatitude;
  double? _deviceLongitude;
  var _didAssignRegionWithDeviceLocation = false;
  var _didCameraFollowFirstDeviceFix = false;
  bool isRequestExpanded = false;
  bool hasSavedCenter = false;
  String? _lastChampionsRegionKey;
  DateTime? _lastEmptyChampionsFetchAt;
  String? _lastHandledAutoClosedTaskId;
  String? _lastSelfPinAvatarUrl;
  DateTime? _lastCreatorTaskCreatedAtUtc;
  String? selectedNearbyTaskId;
  DateTime? _lastMarkerSelectionAt;
  Future<void>? _teardownFuture;
  int? _lastMarkerZoomStep;
  double _lastCameraZoom = 14.5;
  Timer? _cameraGeoRefreshDebounce;
  double? _lastRegionAssignLat;
  double? _lastRegionAssignLon;

  static const double _regionReassignDistanceMeters = 450;
  static const Duration _cameraGeoRefreshDebounceDuration =
      Duration(milliseconds: 650);

  DateTime? get lastCreatorTaskCreatedAtUtc => _lastCreatorTaskCreatedAtUtc;

  void onInit() {
    _lastChampionsRegionKey = null;
    _lastEmptyChampionsFetchAt = null;
    _mapBloc.add(const MapEvent.loadMap());
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
    _polling.dispose();
    _lastMarkerZoomStep = null;
    await _championService.dispose();
    await _requestMarkerService.dispose();
    await _selfMarkerService.dispose();
    mapboxMap = null;
  }

  void toggleRequestExpanded() {
    isRequestExpanded = !isRequestExpanded;
  }

  void selectNearbyTask(String taskId) {
    selectedNearbyTaskId = selectedNearbyTaskId == taskId ? null : taskId;
    unawaited(_requestMarkerService.setSelectedTask(selectedNearbyTaskId));
  }

  void clearNearbyTaskSelection() {
    final lastMarkerTap = _lastMarkerSelectionAt;
    if (lastMarkerTap != null &&
        DateTime.now().difference(lastMarkerTap) <
            const Duration(milliseconds: 180)) {
      return;
    }
    selectedNearbyTaskId = null;
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
    _rememberLatestCreatorTaskCreatedAt(viewModel);

    final nearbyForMarkers = _nearbyTasksWithMyStatuses(viewModel);
    _reconcileSelectedNearbyTask(nearbyForMarkers);
    await _requestMarkerService.syncTasks(nearbyForMarkers);
    await _requestMarkerService.setSelectedTask(selectedNearbyTaskId);
    _ensureChampionsLoaded(viewModel);
    _refreshTaskApplications(viewModel);
    await _tryHandleCreatorAutoClosedTask(context, viewModel);
    await _tryShowCreatorConfirmDialog(context, viewModel);
    _tryCheckExecutorCompletion(
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
      if (viewModel.confirmCompletionResult.taskStatus == 'completed') {
        context.push(RoutePaths.mapRequestCompleted);
      } else if (viewModel.confirmCompletionResult.reward > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Reward: ${viewModel.confirmCompletionResult.reward}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    if (viewModel.applyToTaskResult.applicationId.isNotEmpty &&
        viewModel.applyToTaskResult.applicationId !=
            handledApplyApplicationId) {
      handledApplyApplicationId = viewModel.applyToTaskResult.applicationId;
      executorTaskStatus = viewModel.applyToTaskResult.status;
      executorCreatorName = '';
      consecutiveMissingAppliedTaskChecks = 0;
      _dialogs.resetRejectedHandledId();
      unawaited(
        _persistActiveExecutorApplication(
          viewModel.applyToTaskResult.taskId,
          viewModel.applyToTaskResult.applicationId,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Applied! Status: ${viewModel.applyToTaskResult.status}'),
          backgroundColor: Colors.green,
        ),
      );
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
      ),
    );

    final avatar = _resolveProfileAvatarUrl();
    if (avatar != _lastSelfPinAvatarUrl) {
      _lastSelfPinAvatarUrl = avatar;
      unawaited(_selfMarkerService.reloadAppearance(avatarUrl: avatar));
    }
  }

  Future<void> _restoreLastCreatorTaskCreatedAt() async {
    final restored = await _persistence.readLastCreatorTaskCreatedAt();
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
    unawaited(_persistence.writeLastCreatorTaskCreatedAt(latest));
  }

  /// В nearby с бэка часто `open`, а в myTasks — `mine|…`; иначе маркер моргает «чужой → свой».
  List<MapTaskEntity> _nearbyTasksWithMyStatuses(MapViewModel viewModel) {
    final nearby = viewModel.nearbyTasks;
    final my = viewModel.myTasks;
    if (my.isEmpty) {
      return nearby;
    }
    final byId = {for (final t in my) t.id: t};
    return [
      for (final t in nearby)
        _applyMyTaskStatusIfSameId(t, byId[t.id]),
    ];
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
    unawaited(
      map.location.updateSettings(
        LocationComponentSettings(enabled: false),
      ),
    );
    if (hasSavedCenter) {
      unawaited(
        map.easeTo(
          CameraOptions(
            center:
                Point(coordinates: Position(currentLongitude, currentLatitude)),
            zoom: 14.5,
          ),
          MapAnimationOptions(duration: 450),
        ),
      );
    }

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
    await _championService.updateChampions(
      vm.champions,
      vm.assignedRegion,
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
    if (hasSavedCenter) {
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

    hasSavedCenter = true;
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

    int targetResolution;
    if (_lastCameraZoom >= 14.0) {
      targetResolution = 5; // district details on close zoom
    } else if (_lastCameraZoom >= 11.0) {
      targetResolution = 4; // city level on medium zoom
    } else {
      targetResolution = 2; // country level on far zoom
    }

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

  void _scheduleCameraGeoRefresh() {
    _cameraGeoRefreshDebounce?.cancel();
    _cameraGeoRefreshDebounce =
        Timer(_cameraGeoRefreshDebounceDuration, () {
      _refreshNearbyTasks();
      _maybeAssignRegionForCurrentGeoContext();
    });
  }

  void _maybeAssignRegionForCurrentGeoContext({bool force = false}) {
    final lat = _latitudeForGeoContext;
    final lon = _longitudeForGeoContext;

    if (!force && _lastRegionAssignLat != null && _lastRegionAssignLon != null) {
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
    _mapBloc.add(
      MapEvent.assignRegion(
        MapRegionAssignmentRequest(latitude: lat, longitude: lon),
      ),
    );
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
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

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

      final position = await MapGeo.getBestCurrentPosition();

      if (position == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Unable to determine current location.')),
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
      hasSavedCenter = true;
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
    runSetState(() {
      selectedApplicationId = application.id;
      locallyRejectedApplicationIds.remove(application.id);
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

  void handleExecutorCancel(BuildContext context) {
    final taskId = _mapBloc.viewModel.applyToTaskResult.taskId;
    final applicationId = _mapBloc.viewModel.applyToTaskResult.applicationId;
    if (taskId.isEmpty || applicationId.isEmpty) {
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

  Future<void> _restoreSavedMapCenter() async {
    final savedCenter = await _persistence.readSavedCenter();
    if (savedCenter == null) {
      return;
    }

    currentLatitude = savedCenter.lat;
    currentLongitude = savedCenter.lon;
    hasSavedCenter = true;

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
    final target = await _persistence.readActiveExecutorApplication();
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
    executorTaskStatus = 'pending';
  }

  Future<void> _persistActiveExecutorApplication(
    String taskId,
    String applicationId,
  ) async {
    await _persistence.writeActiveExecutorApplication(
      ActiveExecutorApplication(taskId: taskId, applicationId: applicationId),
    );
  }

  Future<void> _clearActiveExecutorApplication() async {
    await _persistence.clearActiveExecutorApplication();
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
    await _dialogs.tryShowExecutorRejectedDialog(
      context: context,
      applicationId: viewModel.applyToTaskResult.applicationId,
      executorCompletionShown: executorCompletionShown,
      executorTaskStatus: executorTaskStatus,
      executorCreatorName: executorCreatorName,
    );
  }

  void _tryCheckExecutorCompletion(
    BuildContext context,
    MapViewModel viewModel, {
    required void Function(VoidCallback fn) runSetState,
    required bool mounted,
    required Future<void> Function() onNavigateExecutorCompleted,
  }) {
    if (executorCompletionShown) {
      return;
    }

    final taskId = viewModel.applyToTaskResult.taskId;
    final applicationId = viewModel.applyToTaskResult.applicationId;
    if (taskId.isEmpty || applicationId.isEmpty) {
      consecutiveMissingAppliedTaskChecks = 0;
      if (executorTaskStatus.isNotEmpty && mounted) {
        runSetState(() {
          executorTaskStatus = '';
          executorCreatorName = '';
        });
      } else if (executorTaskStatus.isNotEmpty) {
        executorTaskStatus = '';
        executorCreatorName = '';
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
            const Duration(seconds: 8)) {
      return;
    }
    lastExecutorCompletionCheckAt = now;

    _mapBloc.add(const MapEvent.getAppliedTasks());

    String? matchedTaskStatus;
    for (final task in viewModel.appliedTasks) {
      if (task.id == taskId) {
        matchedTaskStatus = task.status;
        break;
      }
    }

    if (matchedTaskStatus != null) {
      consecutiveMissingAppliedTaskChecks = 0;
    }

    if (matchedTaskStatus == 'completed') {
      unawaited(_clearActiveExecutorApplication());
      if (mounted) {
        runSetState(() {
          executorCompletionShown = true;
          executorTaskStatus = matchedTaskStatus!;
          executorCreatorName = '';
        });
      } else {
        executorCompletionShown = true;
        executorTaskStatus = matchedTaskStatus!;
        executorCreatorName = '';
      }
      unawaited(onNavigateExecutorCompleted());
      return;
    }

    if (matchedTaskStatus != null &&
        matchedTaskStatus != executorTaskStatus &&
        mounted &&
        !executorCompletionShown) {
      runSetState(() {
        executorTaskStatus = matchedTaskStatus!;
      });
      return;
    }

    if (matchedTaskStatus == null &&
        viewModel.hasAppliedTasksLoaded &&
        mounted &&
        !executorCompletionShown) {
      // Avoid false "rejected" when current state is stale right after apply.
      consecutiveMissingAppliedTaskChecks += 1;
      if (consecutiveMissingAppliedTaskChecks >= 2) {
        unawaited(_clearActiveExecutorApplication());
        runSetState(() {
          executorTaskStatus = 'rejected';
          executorCreatorName = '';
        });
      }
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
    if (action == 'withdrawn') {
      final applicationId = viewModel.applyToTaskResult.applicationId;
      unawaited(_clearActiveExecutorApplication());
      runSetState(() {
        executorTaskStatus = 'rejected';
        executorCreatorName = '';
        if (applicationId.isNotEmpty) {
          locallyCanceledExecutorApplicationIds.add(applicationId);
        }
      });
      unawaited(_dialogs.showExecutorCanceledDialog(context));
      return;
    }

    if (action == 'accepted' || action == 'rejected') {
      runSetState(() {
        executorTaskStatus = action;
        debugPrint(
            '[MapController] Task application $action - executorTaskStatus updated to: $action');
      });
      final taskId = _polling.lastApplicationsTaskId;
      if (taskId != null && taskId.isNotEmpty) {
        _mapBloc.add(
          MapEvent.getTaskApplications(MapTaskIdRequest(taskId: taskId)),
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Application $action'),
            backgroundColor:
                action == 'accepted' ? Colors.green : Colors.orange,
          ),
        );
      }

      // Refresh applied tasks to get the latest status and trigger UI update
      debugPrint('[MapController] Refreshing applied tasks after $action');
      _mapBloc.add(const MapEvent.getAppliedTasks());

      // Force an extra setState to ensure UI updates
      runSetState(() {
        debugPrint('[MapController] Forced setState for UI update');
      });
    }
  }
}
