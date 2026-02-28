import 'dart:async';

import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/features/map/data/sources/local/i_map_local.dart';
import 'package:app/src/features/map/data/sources/local/map_task_mock_models.dart';
import 'package:app/src/features/map/domain/entities/map_task_application_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:app/src/features/map/domain/repositories/i_map_repository.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

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

  static final CameraOptions _initialCamera = CameraOptions(
    center: Point(coordinates: Position(30.5234, 50.4501)),
    zoom: 11.8,
  );

  Duration _remaining = const Duration(hours: 48, minutes: 12, seconds: 5);
  Timer? _timer;
  int _ticks = 0;
  late final IMapLocal _mapLocal;
  late final IMapRepository _mapRepository;

  MapActiveTaskMock? _activeTask;
  List<MapTaskMockHelper> _helpers = <MapTaskMockHelper>[];
  String? _arrivedHelperName;
  DateTime? _cooldownUntil;
  bool _isRequestExpanded = false;
  List<MapTaskEntity> _nearbyTasks = const <MapTaskEntity>[];
  String? _nearbyTasksError;
  List<MapTaskApplicationEntity> _taskApplications =
      const <MapTaskApplicationEntity>[];
  String? _taskApplicationsError;

  @override
  void initState() {
    super.initState();
    _mapLocal = getIt<IMapLocal>(instanceName: 'MapLocalImpl');
    _mapRepository = getIt<IMapRepository>(instanceName: 'MapRepositoryImpl');
    _loadTaskState();
    _loadNearbyTasks();
    _loadTaskApplications();
    if (_mapboxAccessToken.isNotEmpty) {
      MapboxOptions.setAccessToken(_mapboxAccessToken);
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _loadTaskState();
        _ticks++;
        if (_ticks % 15 == 0) {
          _loadNearbyTasks();
          _loadTaskApplications();
        }
        if (_remaining.inSeconds > 0) {
          _remaining -= const Duration(seconds: 1);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadTaskState() {
    _activeTask = _mapLocal.getActiveTask();
    _helpers = _mapLocal.getTaskHelpers();
    _arrivedHelperName = _mapLocal.getArrivedHelperName();
    _cooldownUntil = _mapLocal.getTaskCooldownUntil();
  }

  bool get _isCooldownActive {
    if (_cooldownUntil == null) {
      return false;
    }
    return _cooldownUntil!.isAfter(DateTime.now());
  }

  bool get _canCreateRequest => _activeTask == null && !_isCooldownActive;

  int get _cooldownDaysLeft {
    if (_cooldownUntil == null) {
      return 0;
    }
    final duration = _cooldownUntil!.difference(DateTime.now());
    if (duration.isNegative) {
      return 0;
    }
    return duration.inDays + 1;
  }

  Future<void> _openCreateRequest() async {
    _loadTaskState();
    if (!_canCreateRequest) {
      setState(() {});
      return;
    }
    await context.push(RoutePaths.mapCreateRequest);
    if (!mounted) {
      return;
    }
    setState(_loadTaskState);
    _loadNearbyTasks();
    _loadTaskApplications();
  }

  Future<void> _loadNearbyTasks() async {
    final result = await _mapRepository.getNearbyTasks(
      lat: _initialCamera.center!.coordinates.lat.toDouble(),
      lon: _initialCamera.center!.coordinates.lng.toDouble(),
      radiusM: 2000,
      limit: 50,
    );

    if (!mounted) {
      return;
    }

    result.fold(
      (error) {
        setState(() {
          _nearbyTasksError = error.message;
          _nearbyTasks = const <MapTaskEntity>[];
        });
      },
      (tasks) {
        setState(() {
          _nearbyTasksError = null;
          _nearbyTasks = tasks;
        });
      },
    );
  }

  Future<void> _loadTaskApplications() async {
    final activeTask = _activeTask;
    if (activeTask == null || activeTask.taskId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _taskApplications = const <MapTaskApplicationEntity>[];
        _taskApplicationsError = null;
      });
      return;
    }

    final result = await _mapRepository.getTaskApplications(activeTask.taskId);
    if (!mounted) return;

    result.fold(
      (error) {
        setState(() {
          _taskApplicationsError = error.message;
          _taskApplications = const <MapTaskApplicationEntity>[];
        });
      },
      (applications) {
        setState(() {
          _taskApplicationsError = null;
          _taskApplications = applications;
        });
      },
    );
  }

  Future<void> _applyToTask(String taskId) async {
    final result = await _mapRepository.applyToTask(taskId);
    if (!mounted) return;

    result.fold(
      (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Colors.red,
          ),
        );
      },
      (entity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Applied successfully. Status: ${entity.status}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadNearbyTasks();
      },
    );
  }

  void _acceptHelper(MapTaskMockHelper helper) {
    _mapLocal.removeTaskHelperById(helper.id);
    _mapLocal.setArrivedHelperName(helper.name);
    setState(_loadTaskState);
    _loadTaskApplications();
  }

  void _rejectHelper(MapTaskMockHelper helper) {
    _mapLocal.removeTaskHelperById(helper.id);
    setState(_loadTaskState);
    _loadTaskApplications();
  }

  Future<void> _confirmCancelRequest() async {
    final activeTask = _activeTask;
    if (activeTask == null) {
      return;
    }

    final shouldCancel = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF121418),
          title: Text(
            'Are you sure you want to cancel your request?',
            style: TextStyles.bodyLarge.copyWith(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true) {
      return;
    }

    final result = await _mapRepository.cancelTask(activeTask.taskId);
    if (!mounted) return;

    result.fold(
      (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Colors.red,
          ),
        );
      },
      (_) {
        _mapLocal.clearActiveTask();
        _mapLocal.saveTaskHelpers(const <MapTaskMockHelper>[]);
        _mapLocal.setArrivedHelperName(null);
        _mapLocal.setTaskCooldownUntil(
          activeTask.createdAt.add(const Duration(days: 7)),
        );

        setState(() {
          _isRequestExpanded = false;
          _loadTaskState();
        });
        context.push(RoutePaths.mapRequestCanceled);
      },
    );
  }

  Future<void> _confirmCompleteRequest() async {
    final activeTask = _activeTask;
    if (activeTask == null) {
      return;
    }

    final confirmableApplication = _taskApplications.firstWhere(
      (app) => app.status == 'code_verified',
      orElse: () => const MapTaskApplicationEntity(
        id: '',
        taskId: '',
        applicantId: '',
        status: '',
        createdAt: '',
      ),
    );

    if (confirmableApplication.id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No code-verified application available to confirm.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final shouldComplete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF121418),
          title: Text(
            'Are you sure your request is complete?',
            style: TextStyles.bodyLarge.copyWith(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldComplete != true) {
      return;
    }

    final result = await _mapRepository.confirmTaskApplication(
      activeTask.taskId,
      confirmableApplication.id,
    );
    if (!mounted) return;

    result.fold(
      (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Colors.red,
          ),
        );
      },
      (entity) {
        _loadTaskApplications();
        _loadNearbyTasks();

        if (entity.taskStatus == 'completed') {
          _mapLocal.clearActiveTask();
          _mapLocal.saveTaskHelpers(const <MapTaskMockHelper>[]);
          _mapLocal.setArrivedHelperName(null);

          setState(() {
            _isRequestExpanded = false;
            _loadTaskState();
          });
          context.push(RoutePaths.mapRequestCompleted);
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Completion confirmed. Reward: ${entity.reward}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }

  String _format(Duration value) {
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    _loadTaskState();
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.map),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _mapboxAccessToken.isEmpty
                  ? Container(
                      color: const Color(0xFF181C22),
                      child: const Center(
                        child: Text(
                          'MAPBOX_ACCESS_TOKEN не задан',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  : MapWidget(
                      key: const ValueKey('mapbox-map-widget'),
                      cameraOptions: _initialCamera,
                    ),
            ),
            Positioned(
              top: 22,
              left: 18,
              right: 18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.34),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'GLOBAL RANKINGS UPDATE',
                        style: TextStyles.bodyMain.copyWith(
                          color: Colors.white54,
                          letterSpacing: 0.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _format(_remaining),
                        style: TextStyles.titleBig.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Regional champions update worldwide...',
                        style: TextStyles.bodyMain.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 122,
              left: 18,
              right: 18,
              child: _NearbyTasksPanel(
                tasks: _nearbyTasks,
                error: _nearbyTasksError,
                onApply: _applyToTask,
              ),
            ),
            if (_activeTask != null && (_helpers.isNotEmpty || _arrivedHelperName != null))
              Positioned(
                top: 220,
                left: 14,
                right: 14,
                child: _RequestsOverlay(
                  applications: _taskApplications,
                  applicationsError: _taskApplicationsError,
                  helpers: _helpers,
                  arrivedHelperName: _arrivedHelperName,
                  onAccept: _acceptHelper,
                  onReject: _rejectHelper,
                  onClearArrived: () {
                    _mapLocal.setArrivedHelperName(null);
                    setState(_loadTaskState);
                  },
                ),
              ),
            if (_activeTask != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 138,
                child: _MyRequestCard(
                  task: _activeTask!,
                  isExpanded: _isRequestExpanded,
                  canComplete: _arrivedHelperName != null,
                  onToggleExpanded: () {
                    setState(() => _isRequestExpanded = !_isRequestExpanded);
                  },
                  onCancelRequest: _confirmCancelRequest,
                  onCompleteRequest: _confirmCompleteRequest,
                ),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 82,
              child: CustomButton(
                text: 'Create a request for help',
                onTap: _openCreateRequest,
                borderRadius: 12,
                backgroundColor: _canCreateRequest
                    ? Colors.black.withOpacity(0.78)
                    : Colors.black.withOpacity(0.45),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                textStyle: TextStyles.bodyLarge.copyWith(
                  color: _canCreateRequest ? Colors.white : Colors.white54,
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            if (!_canCreateRequest)
              Positioned(
                left: 14,
                right: 14,
                bottom: 62,
                child: Text(
                  _activeTask != null
                      ? 'You already have an active request. Cancel it to create a new one.'
                      : 'You will be able to create a new request in $_cooldownDaysLeft days.',
                  textAlign: TextAlign.center,
                  style: TextStyles.bodyMain.copyWith(color: Colors.white54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RequestsOverlay extends StatelessWidget {
  const _RequestsOverlay({
    required this.applications,
    required this.applicationsError,
    required this.helpers,
    required this.arrivedHelperName,
    required this.onAccept,
    required this.onReject,
    required this.onClearArrived,
  });

  final List<MapTaskApplicationEntity> applications;
  final String? applicationsError;
  final List<MapTaskMockHelper> helpers;
  final String? arrivedHelperName;
  final ValueChanged<MapTaskMockHelper> onAccept;
  final ValueChanged<MapTaskMockHelper> onReject;
  final VoidCallback onClearArrived;

  @override
  Widget build(BuildContext context) {
    final backendRows = applications
        .map(
          (app) => MapTaskMockHelper(
            id: app.id,
            name: app.applicantId,
          ),
        )
        .toList();
    final rows = backendRows.isNotEmpty ? backendRows : helpers;

    return Column(
      children: [
        if (applicationsError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.58),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text(
              applicationsError!,
              style: TextStyles.bodyMain.copyWith(color: Colors.white70),
            ),
          ),
        if (rows.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.58),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              children: rows
                  .map(
                    (helper) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
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
                              '${helper.name} wants to help you',
                              style: TextStyles.bodyMain.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => onReject(helper),
                            child: const Icon(
                              Icons.close,
                              color: Color(0xFFD63434),
                              size: 16,
                            ),
                          ),
                          const Gap(10),
                          InkWell(
                            onTap: () => onAccept(helper),
                            child: const Icon(
                              Icons.check,
                              color: Color(0xFF2DDB7B),
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (rows.isEmpty && applicationsError == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.58),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text(
              'No applications yet',
              style: TextStyles.bodyMain.copyWith(color: Colors.white70),
            ),
          ),
        if (arrivedHelperName != null) ...[
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.58),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user, color: Color(0xFF5EC8FF), size: 15),
                const Gap(8),
                Expanded(
                  child: Text(
                    '$arrivedHelperName has arrived',
                    style: TextStyles.bodyMain.copyWith(color: Colors.white70),
                  ),
                ),
                InkWell(
                  onTap: onClearArrived,
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFFD63434),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _NearbyTasksPanel extends StatelessWidget {
  const _NearbyTasksPanel({
    required this.tasks,
    required this.error,
    required this.onApply,
  });

  final List<MapTaskEntity> tasks;
  final String? error;
  final ValueChanged<String> onApply;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.58),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          error!,
          style: TextStyles.bodyMain.copyWith(color: Colors.white70),
        ),
      );
    }

    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleTasks = tasks.length > 2 ? tasks.take(2).toList() : tasks;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.58),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: visibleTasks
            .map(
              (task) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: Colors.white70, size: 15),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyles.bodyMain.copyWith(color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${task.reward.toStringAsFixed(0)}',
                      style: TextStyles.bodyMain.copyWith(color: Colors.white54),
                    ),
                    const Gap(8),
                    InkWell(
                      onTap: () => onApply(task.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'I can help',
                          style: TextStyles.bodyMain.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MyRequestCard extends StatelessWidget {
  const _MyRequestCard({
    required this.task,
    required this.isExpanded,
    required this.canComplete,
    required this.onToggleExpanded,
    required this.onCancelRequest,
    required this.onCompleteRequest,
  });

  final MapActiveTaskMock task;
  final bool isExpanded;
  final bool canComplete;
  final VoidCallback onToggleExpanded;
  final VoidCallback onCancelRequest;
  final VoidCallback onCompleteRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyles.bodyLarge.copyWith(color: Colors.white),
                ),
              ),
              Text(
                'Code:${task.code}',
                style: TextStyles.bodyMain.copyWith(color: Colors.white54),
              ),
            ],
          ),
          const Gap(8),
          if (!isExpanded)
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: onToggleExpanded,
                child: Text(
                  'view my request',
                  style: TextStyles.bodyMain.copyWith(
                    color: Colors.white70,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          if (isExpanded) ...[
            Text(
              task.description,
              style: TextStyles.bodyMain.copyWith(color: Colors.white70),
            ),
            const Gap(8),
            Text(
              'Required: ${task.heroesCount} heroes - Reward: ${task.reward}',
              style: TextStyles.bodyMain.copyWith(color: Colors.white60),
            ),
            const Gap(12),
            CustomButton(
              text: 'Cancel my request',
              onTap: onCancelRequest,
              borderRadius: 8,
              backgroundColor: Colors.transparent,
              border: Border.all(color: const Color(0x99E84A4A)),
              textStyle: TextStyles.bodyMain.copyWith(
                color: const Color(0xFFE84A4A),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            if (canComplete) ...[
              const Gap(8),
              CustomButton(
                text: 'Complete request',
                onTap: onCompleteRequest,
                borderRadius: 8,
                backgroundColor: Colors.transparent,
                border: Border.all(color: Colors.white38),
                textStyle: TextStyles.bodyMain.copyWith(
                  color: Colors.white,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
