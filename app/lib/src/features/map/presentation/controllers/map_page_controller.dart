import 'dart:async';

import 'package:app/src/core/router/router.dart';
import 'package:app/src/features/map/domain/entities/map_region_assignment_entity.dart';
import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_application_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:app/src/features/map/domain/requests/map_champions_request.dart';
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
        _requestSetState = requestSetState,
        _onChampionTapCallback = onChampionTap;

  final MapBloc _mapBloc;
  final MapPersistenceService _persistence;
  final MapPollingService _polling;
  final MapDialogService _dialogs;
  final MapChampionService _championService;
  final MapRequestMarkerService _requestMarkerService;
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
  bool isRequestExpanded = false;
  bool hasSavedCenter = false;
  String? _lastChampionsRegionKey;
  String? selectedNearbyTaskId;
  DateTime? _lastMarkerSelectionAt;

  void onInit() {
    _mapBloc.add(const MapEvent.loadMap());
    unawaited(_restoreSavedMapCenter());
    unawaited(_restoreActiveExecutorApplication());
    _mapBloc.add(const MapEvent.getMyTasks());
    _mapBloc.add(const MapEvent.getAppliedTasks());
  }

  void onDispose() {
    _polling.dispose();
    unawaited(_championService.dispose());
    unawaited(_requestMarkerService.dispose());
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
    _reconcileSelectedNearbyTask(viewModel.nearbyTasks);
    await _requestMarkerService.syncTasks(viewModel.nearbyTasks);
    await _requestMarkerService.setSelectedTask(selectedNearbyTaskId);
    _ensureChampionsLoaded(viewModel);
    _refreshTaskApplications(viewModel);
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

    // Update champion markers when champions are loaded
    if (viewModel.champions.isNotEmpty) {
      unawaited(
        _championService.updateChampions(
          viewModel.champions,
          viewModel.assignedRegion,
        ),
      );
    }
  }

  void onMapCreated(MapboxMap map) {
    mapboxMap = map;
    unawaited(
      map.location.updateSettings(
        LocationComponentSettings(enabled: true),
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

    // Initialize champion service
    unawaited(
      _championService.initialize(
        map,
        onChampionTap: _onChampionTap,
      ),
    );

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
  }

  void onCameraChanged(CameraChangedEventData eventData) {
    currentLatitude = eventData.cameraState.center.coordinates.lat.toDouble();
    currentLongitude = eventData.cameraState.center.coordinates.lng.toDouble();
  }

  void openCreateRequest(BuildContext context) {
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

      geo.Position? position;
      try {
        position = await geo.Geolocator.getCurrentPosition(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        position = await geo.Geolocator.getLastKnownPosition();
      }

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

      currentLatitude = lat;
      currentLongitude = lon;
      hasSavedCenter = true;
      await _persistence.writeSavedCenter(lat, lon);

      await map.easeTo(
        CameraOptions(
          center: Point(coordinates: Position(lon, lat)),
          zoom: 14.5,
        ),
        MapAnimationOptions(duration: 500),
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
          lat: currentLatitude,
          lon: currentLongitude,
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
      _mapBloc.add(
        MapEvent.assignRegion(
          MapRegionAssignmentRequest(
            latitude: currentLatitude,
            longitude: currentLongitude,
          ),
        ),
      );
      return;
    }

    // Get H3 indices from the assigned region
    final region = assignedRegion;
    final h3Indices = <String>[];

    // Add available H3 indices at different resolutions
    if (region.h3Res5.isNotEmpty) {
      h3Indices.add(region.h3Res5);
    }
    if (region.h3Res4.isNotEmpty) {
      h3Indices.add(region.h3Res4);
    }
    if (region.h3Res2.isNotEmpty) {
      h3Indices.add(region.h3Res2);
    }

    if (h3Indices.isEmpty) {
      return;
    }

    // Load champions for these H3 indices
    _lastChampionsRegionKey = _regionKey(region);
    _mapBloc.add(
      MapEvent.getChampions(
        MapChampionsRequest(
          h3Indices: h3Indices,
          resolution: 5, // Use resolution 5 for detailed champions
        ),
      ),
    );
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
      return;
    }

    if (_lastChampionsRegionKey == regionKey) {
      return;
    }

    final h3Indices = <String>[];
    if (region.h3Res5.isNotEmpty) {
      h3Indices.add(region.h3Res5);
    }
    if (region.h3Res4.isNotEmpty) {
      h3Indices.add(region.h3Res4);
    }
    if (region.h3Res2.isNotEmpty) {
      h3Indices.add(region.h3Res2);
    }
    if (h3Indices.isEmpty) {
      return;
    }

    _lastChampionsRegionKey = regionKey;
    _mapBloc.add(
      MapEvent.getChampions(
        MapChampionsRequest(
          h3Indices: h3Indices,
          resolution: 5,
        ),
      ),
    );
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
