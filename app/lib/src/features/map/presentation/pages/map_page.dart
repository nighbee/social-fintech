import 'dart:async';
import 'dart:ui';

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/storage/app_storage/storage_service.dart';
import 'package:app/src/core/service/storage/key_store.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/code_input_field.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/features/map/domain/entities/map_task_application_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:app/src/features/map/domain/requests/map_nearby_tasks_request.dart';
import 'package:app/src/features/map/domain/requests/map_task_application_id_request.dart';
import 'package:app/src/features/map/domain/requests/map_task_id_request.dart';
import 'package:app/src/features/map/domain/requests/map_verify_code_request.dart';
import 'package:app/src/features/map/presentation/bloc/map_bloc.dart';
import 'package:app/src/features/ranking/presentation/widgets/ranking_countdown_widget.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

part '../widgets/map_requests_overlay_widget.dart';
part '../widgets/map_nearby_tasks_panel_widget.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const String _mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );
  static const Duration _nearbyRefreshInterval = Duration(seconds: 15);
  static const Duration _applicationsRefreshInterval = Duration(seconds: 10);

  late final MapBloc _mapBloc;
  MapboxMap? _mapboxMap;
  Timer? _nearbyRefreshTimer;
  DateTime? _lastApplicationsRefreshAt;
  String? _lastApplicationsTaskId;
  String? _selectedApplicationId;
  final Set<String> _locallyRejectedApplicationIds = <String>{};
  String? _lastConfirmPromptApplicationId;
  bool _isConfirmDialogOpen = false;
  String? _handledCancelResult;
  String? _handledApplyApplicationId;
  String? _handledConfirmResultTaskId;
  DateTime? _lastExecutorCompletionCheckAt;
  bool _isCheckingExecutorCompletion = false;
  bool _executorCompletionShown = false;
  String _executorTaskStatus = '';
  String _executorCreatorName = '';
  String? _handledRejectedApplicationId;
  bool _isRejectedDialogOpen = false;
  final Set<String> _locallyCanceledExecutorApplicationIds = <String>{};
  double _currentLatitude = 50.4501;
  double _currentLongitude = 30.5234;
  bool _isRequestExpanded = false;
  bool _hasSavedCenter = false;

  @override
  void initState() {
    super.initState();
    _mapBloc = getIt<MapBloc>();
    _mapBloc.add(const MapEvent.loadMap());
    unawaited(_restoreSavedMapCenter());

    if (_mapboxAccessToken.isNotEmpty) {
      MapboxOptions.setAccessToken(_mapboxAccessToken);
    }
  }

  @override
  void dispose() {
    _nearbyRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.map),
      body: BlocListener<MapBloc, MapState>(
        bloc: _mapBloc,
        listener: (context, state) {
          state.maybeWhen(
            loadingError: (message) {
              final lower = message.toLowerCase();
              if (lower.contains('code')) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message), backgroundColor: Colors.red),
              );
            },
            loaded: (viewModel) {
              _tryRefreshTaskApplications(viewModel);
              _tryShowCreatorConfirmDialog(context, viewModel);
              _tryCheckExecutorCompletion(context, viewModel);
              _tryShowExecutorRejectedDialog(context, viewModel);
              // Task cancelled?
              if (viewModel.cancelTaskResult.isNotEmpty &&
                  viewModel.cancelTaskResult != _handledCancelResult) {
                _handledCancelResult = viewModel.cancelTaskResult;
                context.push(RoutePaths.mapRequestCanceled);
              }
              // Task completed?
              if (viewModel.confirmCompletionResult.taskId.isNotEmpty &&
                  viewModel.confirmCompletionResult.taskId !=
                      _handledConfirmResultTaskId) {
                _handledConfirmResultTaskId =
                    viewModel.confirmCompletionResult.taskId;
                if (viewModel.confirmCompletionResult.taskStatus ==
                    'completed') {
                  context.push(RoutePaths.mapRequestCompleted);
                } else if (viewModel.confirmCompletionResult.reward > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Reward: ${viewModel.confirmCompletionResult.reward}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
              // Applied to task?
              if (viewModel.applyToTaskResult.applicationId.isNotEmpty &&
                  viewModel.applyToTaskResult.applicationId !=
                      _handledApplyApplicationId) {
                _handledApplyApplicationId =
                    viewModel.applyToTaskResult.applicationId;
                _executorTaskStatus = '';
                _executorCreatorName = '';
                _handledRejectedApplicationId = null;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Applied! Status: ${viewModel.applyToTaskResult.status}'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            orElse: () {},
          );
        },
        child: BlocBuilder<MapBloc, MapState>(
          bloc: _mapBloc,
          builder: (context, state) {
            return state.when(
              initial: () => const _MapLoading(),
              loading: (vm) => _MapContent(
                viewModel: vm,
                mapboxMap: _mapboxMap,
                isRequestExpanded: _isRequestExpanded,
                isLoading: true,
                onToggleExpanded: () =>
                    setState(() => _isRequestExpanded = !_isRequestExpanded),
                onMapCreated: _onMapCreated,
                onCameraChanged: _onCameraChanged,
                onOpenCreateRequest: () => _openCreateRequest(context),
                onOpenVerifyCode: (taskId, applicationId) =>
                    _openVerifyCodePage(
                  context,
                  taskId: taskId,
                  applicationId: applicationId,
                ),
                onZoomIn: () => _zoomBy(1),
                onZoomOut: () => _zoomBy(-1),
                onCurrentLocation: () => _moveToCurrentLocation(context),
                selectedApplicationId: _selectedApplicationId,
                locallyRejectedApplicationIds: _locallyRejectedApplicationIds,
                onAcceptApplication: _handleAcceptApplication,
                onRejectApplication: _handleRejectApplication,
                onExecutorCancel: () => _handleExecutorCancel(context),
                executorCompletionShown: _executorCompletionShown,
                executorTaskStatus: _executorTaskStatus,
                executorCreatorName: _executorCreatorName,
                locallyCanceledExecutorApplicationIds:
                    _locallyCanceledExecutorApplicationIds,
              ),
              loadingError: (_) =>
                  const SizedBox.shrink(), // Handled by listener
              loaded: (vm) => _MapContent(
                viewModel: vm,
                mapboxMap: _mapboxMap,
                isRequestExpanded: _isRequestExpanded,
                isLoading: false,
                onToggleExpanded: () =>
                    setState(() => _isRequestExpanded = !_isRequestExpanded),
                onMapCreated: _onMapCreated,
                onCameraChanged: _onCameraChanged,
                onOpenCreateRequest: () => _openCreateRequest(context),
                onOpenVerifyCode: (taskId, applicationId) =>
                    _openVerifyCodePage(
                  context,
                  taskId: taskId,
                  applicationId: applicationId,
                ),
                onZoomIn: () => _zoomBy(1),
                onZoomOut: () => _zoomBy(-1),
                onCurrentLocation: () => _moveToCurrentLocation(context),
                selectedApplicationId: _selectedApplicationId,
                locallyRejectedApplicationIds: _locallyRejectedApplicationIds,
                onAcceptApplication: _handleAcceptApplication,
                onRejectApplication: _handleRejectApplication,
                onExecutorCancel: () => _handleExecutorCancel(context),
                executorCompletionShown: _executorCompletionShown,
                executorTaskStatus: _executorTaskStatus,
                executorCreatorName: _executorCreatorName,
                locallyCanceledExecutorApplicationIds:
                    _locallyCanceledExecutorApplicationIds,
              ),
            );
          },
        ),
      ),
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    unawaited(
      mapboxMap.location.updateSettings(
        LocationComponentSettings(enabled: true),
      ),
    );
    if (_hasSavedCenter) {
      unawaited(
        mapboxMap.easeTo(
          CameraOptions(
            center: Point(
                coordinates: Position(_currentLongitude, _currentLatitude)),
            zoom: 14.5,
          ),
          MapAnimationOptions(duration: 450),
        ),
      );
    }

    _refreshNearbyTasks();
    _startNearbyRefreshTimer();
  }

  Future<void> _restoreSavedMapCenter() async {
    await prefsInstance.initialize();
    final savedLat = prefsInstance.get<double>(KeyStore.mapLastCenterLat);
    final savedLon = prefsInstance.get<double>(KeyStore.mapLastCenterLon);
    if (savedLat == null || savedLon == null) {
      return;
    }

    _currentLatitude = savedLat;
    _currentLongitude = savedLon;
    _hasSavedCenter = true;

    final map = _mapboxMap;
    if (map != null) {
      await map.easeTo(
        CameraOptions(
          center: Point(coordinates: Position(savedLon, savedLat)),
          zoom: 14.5,
        ),
        MapAnimationOptions(duration: 450),
      );
      _refreshNearbyTasks();
    }
  }

  Future<void> _persistMapCenter(double lat, double lon) async {
    await prefsInstance.initialize();
    await prefsInstance.set<double>(KeyStore.mapLastCenterLat, lat);
    await prefsInstance.set<double>(KeyStore.mapLastCenterLon, lon);
  }

  void _onCameraChanged(CameraChangedEventData eventData) {
    _currentLatitude = eventData.cameraState.center.coordinates.lat.toDouble();
    _currentLongitude = eventData.cameraState.center.coordinates.lng.toDouble();
  }

  void _openCreateRequest(BuildContext context) {
    context.push(
      RoutePaths.mapCreateRequest,
      extra: <String, dynamic>{
        'latitude': _currentLatitude,
        'longitude': _currentLongitude,
      },
    );
  }

  void _startNearbyRefreshTimer() {
    _nearbyRefreshTimer?.cancel();
    _nearbyRefreshTimer = Timer.periodic(_nearbyRefreshInterval, (_) {
      _refreshNearbyTasks();
    });
  }

  void _refreshNearbyTasks() {
    _mapBloc.add(
      MapEvent.getNearbyTasks(
        MapNearbyTasksRequest(
          lat: _currentLatitude,
          lon: _currentLongitude,
          radiusM: 2000,
          limit: 50,
        ),
      ),
    );
  }

  void _tryRefreshTaskApplications(MapViewModel viewModel) {
    MapTaskEntity? myTask;
    for (final task in viewModel.nearbyTasks) {
      if (task.status.startsWith('mine')) {
        myTask = task;
        break;
      }
    }

    if (myTask == null || myTask.id.isEmpty) {
      _lastApplicationsTaskId = null;
      _lastApplicationsRefreshAt = null;
      _selectedApplicationId = null;
      _locallyRejectedApplicationIds.clear();
      return;
    }

    final now = DateTime.now();
    final taskChanged = _lastApplicationsTaskId != myTask.id;
    final canRefreshByTime = _lastApplicationsRefreshAt == null ||
        now.difference(_lastApplicationsRefreshAt!) >=
            _applicationsRefreshInterval;

    if (!taskChanged && !canRefreshByTime) {
      return;
    }

    _lastApplicationsTaskId = myTask.id;
    _lastApplicationsRefreshAt = now;

    _mapBloc.add(
      MapEvent.getTaskApplications(
        MapTaskIdRequest(taskId: myTask.id),
      ),
    );
  }

  void _tryShowCreatorConfirmDialog(
    BuildContext context,
    MapViewModel viewModel,
  ) {
    if (_isConfirmDialogOpen || _selectedApplicationId == null) {
      return;
    }

    MapTaskApplicationEntity? selectedApplication;
    for (final app in viewModel.taskApplications) {
      if (app.id == _selectedApplicationId) {
        selectedApplication = app;
        break;
      }
    }

    if (selectedApplication == null ||
        selectedApplication.status != 'code_verified') {
      return;
    }

    if (_lastConfirmPromptApplicationId == selectedApplication.id) {
      return;
    }

    _lastConfirmPromptApplicationId = selectedApplication.id;
    _isConfirmDialogOpen = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final helperName = _compactApplicant(selectedApplication!.applicantId);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 34, 16, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6D6D6D).withOpacity(0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF656565)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, -3),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 25,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Did $helperName help you complete the task?',
                          textAlign: TextAlign.center,
                          style: TextStyles.bodyMain.copyWith(
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: CustomButton(
                                text: 'Yes',
                                onTap: () {
                                  _mapBloc.add(
                                    MapEvent.confirmTaskApplication(
                                      MapTaskApplicationIdRequest(
                                        taskId: selectedApplication!.taskId,
                                        applicationId: selectedApplication.id,
                                      ),
                                    ),
                                  );
                                  Navigator.of(dialogContext).pop();
                                },
                                borderRadius: 6,
                                backgroundColor: const Color(0xFFE5E5E5),
                                textStyle: TextStyles.bodyMain.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CustomButton(
                                text: 'No',
                                onTap: () => Navigator.of(dialogContext).pop(),
                                borderRadius: 6,
                                backgroundColor: Colors.transparent,
                                border: Border.all(color: Colors.white38),
                                textStyle: TextStyles.bodyMain.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -15,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A3341),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _isConfirmDialogOpen = false;
    });
  }
  Future<void> _zoomBy(double delta) async {
    final map = _mapboxMap;
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

  Future<void> _moveToCurrentLocation(BuildContext context) async {
    final map = _mapboxMap;
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

      _currentLatitude = lat;
      _currentLongitude = lon;
      _hasSavedCenter = true;
      await _persistMapCenter(lat, lon);

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

  Future<void> _openVerifyCodePage(
    BuildContext context, {
    required String taskId,
    required String applicationId,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _VerifyCodePage(
          mapBloc: _mapBloc,
          taskId: taskId,
          applicationId: applicationId,
        ),
      ),
    );
  }

  void _handleAcceptApplication(MapTaskApplicationEntity application) {
    setState(() {
      _selectedApplicationId = application.id;
      _locallyRejectedApplicationIds.remove(application.id);
    });
  }

  void _handleRejectApplication(MapTaskApplicationEntity application) {
    setState(() {
      _locallyRejectedApplicationIds.add(application.id);
      if (_selectedApplicationId == application.id) {
        _selectedApplicationId = null;
      }
    });
  }

  void _handleExecutorCancel(BuildContext context) {
    final applicationId = _mapBloc.viewModel.applyToTaskResult.applicationId;
    if (applicationId.isEmpty) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 30),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D6D6D).withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF656565)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Are you sure you want to cancel this request?',
                      textAlign: TextAlign.center,
                      style: TextStyles.bodyMain.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Confirm',
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              setState(() {
                                _executorTaskStatus = 'rejected';
                                _executorCreatorName = '';
                                _handledRejectedApplicationId = applicationId;
                                _locallyCanceledExecutorApplicationIds
                                    .add(applicationId);
                              });
                              _showExecutorCanceledDialog(context);
                            },
                            borderRadius: 6,
                            backgroundColor: const Color(0xFFE5E5E5),
                            textStyle: TextStyles.bodyMain.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CustomButton(
                            text: 'Cancel',
                            onTap: () => Navigator.of(dialogContext).pop(),
                            borderRadius: 6,
                            backgroundColor: Colors.transparent,
                            border: Border.all(color: Colors.white38),
                            textStyle: TextStyles.bodyMain.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ],
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

  void _showExecutorCanceledDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 30),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D6D6D).withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF656565)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Request canceled',
                      textAlign: TextAlign.center,
                      style: TextStyles.bodyLarge.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your request has been canceled.',
                      textAlign: TextAlign.center,
                      style: TextStyles.bodyMain.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    CustomButton(
                      text: 'Ok',
                      onTap: () => Navigator.of(dialogContext).pop(),
                      borderRadius: 6,
                      backgroundColor: const Color(0xFFE5E5E5),
                      textStyle: TextStyles.bodyMain.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
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

  String _compactApplicant(String applicantId) {
    if (applicantId.trim().isEmpty) {
      return 'User';
    }
    final trimmed = applicantId.trim();
    if (trimmed.length <= 18) {
      return trimmed;
    }
    return trimmed.substring(0, 18);
  }

  void _tryShowExecutorRejectedDialog(
    BuildContext context,
    MapViewModel viewModel,
  ) {
    if (_isRejectedDialogOpen || _executorCompletionShown) {
      return;
    }

    final applicationId = viewModel.applyToTaskResult.applicationId;
    if (applicationId.isEmpty) {
      return;
    }

    if (_executorTaskStatus != 'rejected') {
      return;
    }

    if (_handledRejectedApplicationId == applicationId) {
      return;
    }

    _handledRejectedApplicationId = applicationId;
    _isRejectedDialogOpen = true;

    final creatorName = _executorCreatorName.trim().isEmpty
        ? 'Creator'
        : _executorCreatorName.trim();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 30),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D6D6D).withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF656565)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$creatorName rejected your request.',
                      textAlign: TextAlign.center,
                      style: TextStyles.bodyMain.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    CustomButton(
                      text: 'Ok',
                      onTap: () => Navigator.of(dialogContext).pop(),
                      borderRadius: 6,
                      backgroundColor: const Color(0xFFE5E5E5),
                      textStyle: TextStyles.bodyMain.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      _isRejectedDialogOpen = false;
    });
  }

  Future<void> _tryCheckExecutorCompletion(
    BuildContext context,
    MapViewModel viewModel,
  ) async {
    if (_executorCompletionShown || _isCheckingExecutorCompletion) {
      return;
    }

    final taskId = viewModel.applyToTaskResult.taskId;
    final applicationId = viewModel.applyToTaskResult.applicationId;
    if (taskId.isEmpty || applicationId.isEmpty) {
      if (_executorTaskStatus.isNotEmpty && mounted) {
        setState(() {
          _executorTaskStatus = '';
          _executorCreatorName = '';
        });
      } else if (_executorTaskStatus.isNotEmpty) {
        _executorTaskStatus = '';
        _executorCreatorName = '';
      }
      return;
    }
    if (_locallyCanceledExecutorApplicationIds.contains(applicationId)) {
      return;
    }

    final now = DateTime.now();
    if (_lastExecutorCompletionCheckAt != null &&
        now.difference(_lastExecutorCompletionCheckAt!) <
            const Duration(seconds: 8)) {
      return;
    }
    _lastExecutorCompletionCheckAt = now;

    _isCheckingExecutorCompletion = true;
    try {
      final restClient = getIt<RestClient>(instanceName: 'DioClient');
      final result = await restClient.get(EndPoints.mapTasksApplied);

      result.fold(
        (_) {},
        (response) {
          final raw = response.data;
          if (raw is! Map) {
            return;
          }

          final tasksRaw = raw['tasks'];
          if (tasksRaw is! List) {
            return;
          }

          String? matchedTaskStatus;
          String? matchedCreatorName;
          for (final item in tasksRaw) {
            if (item is! Map) {
              continue;
            }
            final json =
                Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
            final id = (json['id'] ?? '').toString();
            final status = (json['status'] ?? '').toString();
            if (id == taskId) {
              matchedTaskStatus = status;
              final creatorNameRaw = (json['creator_name'] ??
                      json['creatorName'] ??
                      json['creator'] ??
                      '')
                  .toString()
                  .trim();
              matchedCreatorName = creatorNameRaw;
            }
            if (id == taskId && status == 'completed') {
              if (mounted) {
                setState(() {
                  _executorCompletionShown = true;
                  _executorTaskStatus = status;
                  if ((matchedCreatorName ?? '').isNotEmpty) {
                    _executorCreatorName = matchedCreatorName!;
                  }
                });
              } else {
                _executorCompletionShown = true;
                _executorTaskStatus = status;
                if ((matchedCreatorName ?? '').isNotEmpty) {
                  _executorCreatorName = matchedCreatorName!;
                }
              }
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _ExecutorCompletedPage(),
                  ),
                );
              }
              break;
            }
          }

          if (matchedTaskStatus != null &&
              matchedTaskStatus != _executorTaskStatus &&
              mounted &&
              !_executorCompletionShown) {
            setState(() {
              _executorTaskStatus = matchedTaskStatus!;
              if ((matchedCreatorName ?? '').isNotEmpty) {
                _executorCreatorName = matchedCreatorName!;
              }
            });
          }
          if (matchedTaskStatus == null &&
              mounted &&
              !_executorCompletionShown) {
            setState(() {
              _executorTaskStatus = 'rejected';
              _executorCreatorName = '';
            });
          }
        },
      );
    } finally {
      _isCheckingExecutorCompletion = false;
    }
  }
}

// Class Widgets (BrightBund standard)

class _MapLoading extends StatelessWidget {
  const _MapLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _MapContent extends StatelessWidget {
  const _MapContent({
    required this.viewModel,
    required this.mapboxMap,
    required this.isRequestExpanded,
    required this.isLoading,
    required this.onToggleExpanded,
    required this.onMapCreated,
    required this.onCameraChanged,
    required this.onOpenCreateRequest,
    required this.onOpenVerifyCode,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onCurrentLocation,
    required this.selectedApplicationId,
    required this.locallyRejectedApplicationIds,
    required this.onAcceptApplication,
    required this.onRejectApplication,
    required this.onExecutorCancel,
    required this.executorCompletionShown,
    required this.executorTaskStatus,
    required this.executorCreatorName,
    required this.locallyCanceledExecutorApplicationIds,
  });

  final MapViewModel viewModel;
  final MapboxMap? mapboxMap;
  final bool isRequestExpanded;
  final bool isLoading;
  final VoidCallback onToggleExpanded;
  final void Function(MapboxMap) onMapCreated;
  final void Function(CameraChangedEventData) onCameraChanged;
  final VoidCallback onOpenCreateRequest;
  final void Function(String taskId, String applicationId) onOpenVerifyCode;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onCurrentLocation;
  final String? selectedApplicationId;
  final Set<String> locallyRejectedApplicationIds;
  final ValueChanged<MapTaskApplicationEntity> onAcceptApplication;
  final ValueChanged<MapTaskApplicationEntity> onRejectApplication;
  final VoidCallback onExecutorCancel;
  final bool executorCompletionShown;
  final String executorTaskStatus;
  final String executorCreatorName;
  final Set<String> locallyCanceledExecutorApplicationIds;

  @override
  Widget build(BuildContext context) {
    final mapBloc = getIt<MapBloc>();
    MapTaskEntity? myRequest;
    for (final task in viewModel.nearbyTasks) {
      if (task.status.startsWith('mine')) {
        myRequest = task;
        break;
      }
    }

    final nearbyTasks = viewModel.nearbyTasks
        .where((task) => !task.status.startsWith('mine'))
        .toList(growable: false);
    final visibleApplications = viewModel.taskApplications
        .where((app) => !locallyRejectedApplicationIds.contains(app.id))
        .toList(growable: false);
    final applyResult = viewModel.applyToTaskResult;
    final verifyResult = viewModel.verifyCodeResult;
    final hasAppliedTask =
        applyResult.taskId.isNotEmpty && applyResult.applicationId.isNotEmpty;
    final isLocallyCanceledByExecutor =
        locallyCanceledExecutorApplicationIds
            .contains(applyResult.applicationId);
    MapTaskEntity? appliedTask;
    if (hasAppliedTask) {
      for (final task in nearbyTasks) {
        if (task.id == applyResult.taskId) {
          appliedTask = task;
          break;
        }
      }
    }
    final normalizedExecutorStatus = executorTaskStatus.trim().toLowerCase();
    final hasActiveApplicationLifecycle = hasAppliedTask &&
        !isLocallyCanceledByExecutor &&
        normalizedExecutorStatus != 'rejected' &&
        normalizedExecutorStatus != 'completed';
    const acceptedStatuses = <String>{
      'accepted',
      'assigned',
      'arrived',
      'in_progress',
      'code_required',
      'code_verified',
    };
    final normalizedApplyStatus = applyResult.status.trim().toLowerCase();
    final canEnterCodeByStatus =
        acceptedStatuses.contains(normalizedExecutorStatus) ||
            normalizedApplyStatus == 'pending';
    final isCodeVerified =
        verifyResult.applicationId == applyResult.applicationId &&
            verifyResult.status == 'code_verified';
    final isAwaitingCodeEntry = !executorCompletionShown &&
        myRequest == null &&
        hasActiveApplicationLifecycle &&
        canEnterCodeByStatus &&
        !isCodeVerified;
    final isWaitingCreatorConfirm = !executorCompletionShown &&
        myRequest == null &&
        hasActiveApplicationLifecycle &&
        isCodeVerified;
    final hasExecutorFlowActive =
        isAwaitingCodeEntry || isWaitingCreatorConfirm;
    final shouldShowExecutorTopStrip = hasExecutorFlowActive;

    const mapboxAccessToken = String.fromEnvironment(
      'MAPBOX_ACCESS_TOKEN',
      defaultValue: '',
    );

    return Stack(
      children: [
        Positioned.fill(
          child: mapboxAccessToken.isEmpty
              ? Container(
                  color: const Color(0xFF181C22),
                  child: Center(
                    child: Text(
                      'MAPBOX_ACCESS_TOKEN не задан',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              : MapWidget(
                  key: const ValueKey('mapbox-map-widget'),
                  cameraOptions: CameraOptions(
                    center: Point(
                        coordinates: Position(viewModel.centerLongitude,
                            viewModel.centerLatitude)),
                    zoom: viewModel.zoom,
                  ),
                  onMapCreated: onMapCreated,
                  onCameraChangeListener: onCameraChanged,
                ),
        ),
        Positioned(
          top: 22,
          left: 18,
          right: 18,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D6D6D).withOpacity(0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF656565)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GLOBAL RANKINGS UPDATE',
                      style: TextStyles.bodySecondary.copyWith(
                        color: Colors.white54,
                        letterSpacing: 0.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const RankingCountdownWidget(),
                    const SizedBox(height: 4),
                    Text(
                      'Regional champions update worldwide...',
                      style:
                          TextStyles.bodyMain.copyWith(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (myRequest != null ||
            (!hasExecutorFlowActive && nearbyTasks.isNotEmpty))
          Positioned(
            left: 14,
            right: 14,
            bottom: 140,
            child: myRequest != null
                ? (() {
                    final myTask = myRequest!;
                    return _MyRequestPanel(
                      task: myTask,
                      isExpanded: isRequestExpanded,
                      onToggleExpanded: onToggleExpanded,
                      onCancel: () {
                        showDialog<void>(
                          context: context,
                          barrierDismissible: true,
                          builder: (dialogContext) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding:
                                const EdgeInsets.symmetric(horizontal: 22),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Container(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 16, 14, 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6D6D6D).withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: const Color(0xFF656565)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.15),
                                        blurRadius: 12,
                                        offset: const Offset(0, -3),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.4),
                                        blurRadius: 25,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Are you sure you want to cancel your request?',
                                        textAlign: TextAlign.center,
                                        style: TextStyles.bodyMain
                                            .copyWith(color: Colors.white70),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: CustomButton(
                                              text: 'Confirm',
                                              onTap: () {
                                                Navigator.of(dialogContext).pop();
                                                mapBloc.add(
                                                  MapEvent.cancelTask(
                                                    MapTaskIdRequest(taskId: myTask.id),
                                                  ),
                                                );
                                              },
                                              borderRadius: 6,
                                              backgroundColor:
                                                  const Color(0xFFE5E5E5),
                                              textStyle:
                                                  TextStyles.bodyMain.copyWith(
                                                color: Colors.black87,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 8),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: CustomButton(
                                              text: 'Cancel',
                                              onTap: () =>
                                                  Navigator.of(dialogContext).pop(),
                                              borderRadius: 6,
                                              backgroundColor: Colors.transparent,
                                              border:
                                                  Border.all(color: Colors.white38),
                                              textStyle: TextStyles.bodyMain
                                                  .copyWith(color: Colors.white70),
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  })()
                : _NearbyTasksPanel(
                    tasks: nearbyTasks,
                    onApply: (taskId) => mapBloc.add(
                        MapEvent.applyToTask(MapTaskIdRequest(taskId: taskId))),
                  ),
          ),
        Positioned(
          right: 18,
          top: 250,
          child: _MapControlsPanel(
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onCurrentLocation: onCurrentLocation,
          ),
        ),
        if (myRequest != null && visibleApplications.isNotEmpty)
          Positioned(
            top: 125,
            left: 14,
            right: 14,
            child: _RequestsOverlay(
              applications: visibleApplications,
              selectedApplicationId: selectedApplicationId,
              onAccept: onAcceptApplication,
              onReject: onRejectApplication,
            ),
          ),
        if (shouldShowExecutorTopStrip)
          Positioned(
            top: 125,
            left: 14,
            right: 14,
            child: _ExecutorRequestStrip(
              message:
                  '${executorCreatorName.trim().isEmpty ? 'Creator' : executorCreatorName.trim()} confirm help received',
              onClose: onExecutorCancel,
            ),
          ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 82,
          child: isAwaitingCodeEntry
              ? CustomButton(
                  text: 'Click here to enter the verification code',
                  onTap: () => onOpenVerifyCode(
                    viewModel.applyToTaskResult.taskId,
                    viewModel.applyToTaskResult.applicationId,
                  ),
                  borderRadius: 8,
                  backgroundColor: const Color(0xFFE5E5E5),
                  textStyle: TextStyles.bodyMain.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                )
              : isWaitingCreatorConfirm
                  ? CustomButton(
                      text: 'Waiting for creator confirmation',
                      onTap: () {},
                      isDisabled: true,
                      borderRadius: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.24),
                      textStyle: TextStyles.bodyMain.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    )
                  : CustomButton(
                      text: 'Create a request for help',
                      onTap: onOpenCreateRequest,
                      borderRadius: 12,
                      backgroundColor:
                          viewModel.isBusy || viewModel.isCreatingTask
                              ? Colors.black.withValues(alpha: 0.45)
                              : Colors.black.withValues(alpha: 0.78),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                      textStyle: TextStyles.bodyLarge.copyWith(
                        color: viewModel.isBusy || viewModel.isCreatingTask
                            ? Colors.white54
                            : Colors.white,
                      ),
                      icon:
                          const Icon(Icons.add, color: Colors.white, size: 18),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
        ),
      ],
    );
  }
}

class _VerifyCodePage extends StatefulWidget {
  const _VerifyCodePage({
    required this.mapBloc,
    required this.taskId,
    required this.applicationId,
  });

  final MapBloc mapBloc;
  final String taskId;
  final String applicationId;

  @override
  State<_VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<_VerifyCodePage> {
  String _code = '';
  bool _isSubmitting = false;
  bool _hasInvalidCodeError = false;

  bool get _isCodeComplete =>
      _code.length == 4 && !_code.contains(RegExp(r'[^A-Za-z0-9]'));

  void _submit() {
    if (!_isCodeComplete || _isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _hasInvalidCodeError = false;
    });

    widget.mapBloc.add(
      MapEvent.verifyTaskApplicationCode(
        MapTaskApplicationIdRequest(
          taskId: widget.taskId,
          applicationId: widget.applicationId,
        ),
        MapVerifyCodeRequest(code: _code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
      ),
      body: BlocListener<MapBloc, MapState>(
        bloc: widget.mapBloc,
        listener: (context, state) {
          state.maybeWhen(
            loadingError: (_) {
              if (!_isSubmitting) {
                return;
              }
              setState(() {
                _isSubmitting = false;
                _hasInvalidCodeError = true;
              });
            },
            loaded: (viewModel) {
              final verify = viewModel.verifyCodeResult;
              if (verify.applicationId == widget.applicationId &&
                  verify.status == 'code_verified') {
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
              if (_isSubmitting) {
                setState(() {
                  _isSubmitting = false;
                });
              }
            },
            orElse: () {},
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the code',
                style: TextStyles.titleXBig.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                'Enter the 4-character verification code you got from the creator.',
                style: TextStyles.bodyMain.copyWith(color: Colors.white38),
              ),
              const SizedBox(height: 30),
              Center(
                child: CodeInputField(
                  length: 4,
                  allowAlphanumeric: true,
                  isInvalid: _hasInvalidCodeError,
                  onChanged: (code) {
                    setState(() {
                      _code = code;
                      _hasInvalidCodeError = false;
                    });
                  },
                ),
              ),
              if (_hasInvalidCodeError) ...[
                const SizedBox(height: 8),
                Text(
                  'You entered the wrong verification code.',
                  style: TextStyles.bodyMain.copyWith(
                    color: const Color(0xFFEF4444),
                    fontSize: 12,
                  ),
                ),
              ],
              const Spacer(),
              CustomButton(
                text: _isSubmitting ? 'Verifying...' : 'Continue',
                onTap: _submit,
                borderRadius: 8,
                backgroundColor: _isCodeComplete
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.15),
                textStyle: TextStyles.bodyMain.copyWith(
                  color: _isCodeComplete ? Colors.black87 : Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapControlsPanel extends StatelessWidget {
  const _MapControlsPanel({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onCurrentLocation,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onCurrentLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MapZoomControlGroup(
          onTapPlus: onZoomIn,
          onTapMinus: onZoomOut,
        ),
        const SizedBox(height: 12),
        _MapControlButton(
          icon: Assets.icons.location.svg(
            width: 35,
            height: 35,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          onTap: onCurrentLocation,
        ),
      ],
    );
  }
}

class _MapZoomControlGroup extends StatelessWidget {
  const _MapZoomControlGroup({
    required this.onTapPlus,
    required this.onTapMinus,
  });

  final VoidCallback onTapPlus;
  final VoidCallback onTapMinus;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF6D6D6D).withOpacity(0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF656565)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapZoomHalfButton(
                onTap: onTapPlus,
                icon: Assets.icons.plusIcon.svg(
                  width: 28,
                  height: 28,
                  colorFilter: const ColorFilter.mode(
                    Color.fromARGB(255, 189, 188, 188),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFF656565)),
              _MapZoomHalfButton(
                onTap: onTapMinus,
                icon: Container(
                  width: 28,
                  height: 1,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 189, 188, 188),
                    borderRadius: BorderRadius.circular(2),
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

class _MapZoomHalfButton extends StatelessWidget {
  const _MapZoomHalfButton({
    required this.onTap,
    required this.icon,
  });

  final VoidCallback onTap;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(child: icon),
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.onTap,
  });

  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: const Color(0xFF6D6D6D).withOpacity(0.35),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF656565)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExecutorRequestStrip extends StatelessWidget {
  const _ExecutorRequestStrip({
    required this.message,
    required this.onClose,
  });

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF6D6D6D).withOpacity(0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF656565)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 11,
                backgroundColor: Color(0xFF2A3341),
                child: Icon(
                  Icons.person,
                  color: Colors.white70,
                  size: 14,
                ),
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyles.bodyMain.copyWith(
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Gap(8),
              const Icon(
                Icons.chat_bubble_outline,
                color: Colors.white70,
                size: 16,
              ),
              const Gap(10),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    color: Color(0xFFEF4444),
                    size: 18,
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

class _ExecutorCompletedPage extends StatelessWidget {
  const _ExecutorCompletedPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 30,
              bottom: 200,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.fromARGB(255, 16, 57, 21),
                  ),
                  height: 250,
                  width: 300,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: Column(
                children: [
                  const Spacer(),
                  Assets.icons.requestClosed.svg(width: 110, height: 110),
                  const SizedBox(height: 14),
                  Text(
                    'Congratulations!',
                    style: TextStyles.titleTag.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your assistance was confirmed.\nYou have received your reward.',
                    textAlign: TextAlign.center,
                    style: TextStyles.bodyMain.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  CustomButton(
                    text: 'Ok',
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: 8,
                    backgroundColor: const Color(0xFF121418),
                    border: Border.all(color: Colors.white24),
                    textStyle: TextStyles.bodyMain.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
