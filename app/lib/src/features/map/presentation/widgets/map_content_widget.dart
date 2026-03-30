part of 'package:app/src/features/map/presentation/pages/map_page.dart';

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
    required this.onTapMapBackground,
    required this.selectedApplicationId,
    required this.locallyRejectedApplicationIds,
    required this.onAcceptApplication,
    required this.onRejectApplication,
    required this.onExecutorCancel,
    required this.executorCompletionShown,
    required this.executorTaskStatus,
    required this.executorCreatorName,
    required this.locallyCanceledExecutorApplicationIds,
    required this.selectedNearbyTaskId,
    required this.onSelectNearbyTask,
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
  final VoidCallback onTapMapBackground;
  final String? selectedApplicationId;
  final Set<String> locallyRejectedApplicationIds;
  final ValueChanged<MapTaskApplicationEntity> onAcceptApplication;
  final ValueChanged<MapTaskApplicationEntity> onRejectApplication;
  final VoidCallback onExecutorCancel;
  final bool executorCompletionShown;
  final String executorTaskStatus;
  final String executorCreatorName;
  final Set<String> locallyCanceledExecutorApplicationIds;
  final String? selectedNearbyTaskId;
  final ValueChanged<String> onSelectNearbyTask;

  @override
  Widget build(BuildContext context) {
    final mapBloc = getIt<MapBloc>();
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final safeTop = mediaQuery.padding.top;
    final safeBottom = mediaQuery.padding.bottom;
    final horizontalInset = screenHeight < 720 ? 12.0 : 14.0;
    const requestPanelHorizontalInset = 15.0;
    final topBannerInset = 15.0;
    final topBannerTop = safeTop + 12;
    final overlayTop = topBannerTop + 104;
    final controlsTop = screenHeight < 720 ? overlayTop + 88 : overlayTop + 126;
    final ctaHorizontalInset = 15.0;
    final floatingActionBottom = safeBottom + 18;
    final floatingPanelBottom = floatingActionBottom + 74;
    final myRequest = MapFlowEvaluator.findCreatorActiveTask(viewModel.myTasks);

    final lockedMessage = MapFlowEvaluator.buildCreateTaskLockMessage(
      viewModel.myTasks,
      nearbyTasks: viewModel.nearbyTasks,
      nowUtc: DateTime.now().toUtc(),
    );

    final nearbyTasks = viewModel.nearbyTasks.toList(growable: false);
    final selectedNearbyTask = selectedNearbyTaskId == null
        ? null
        : nearbyTasks.cast<MapTaskEntity?>().firstWhere(
              (task) => task?.id == selectedNearbyTaskId,
              orElse: () => null,
            );
    final visibleApplications = MapFlowEvaluator.buildVisibleApplications(
      viewModel.taskApplications,
      locallyRejectedApplicationIds,
    );
    final applyResult = viewModel.applyToTaskResult;
    final verifyResult = viewModel.verifyCodeResult;
    final hasAppliedTask =
        applyResult.taskId.isNotEmpty && applyResult.applicationId.isNotEmpty;
    final isLocallyCanceledByExecutor = locallyCanceledExecutorApplicationIds
        .contains(applyResult.applicationId);
    MapTaskEntity? appliedTask;
    if (hasAppliedTask) {
      for (final task in viewModel.appliedTasks) {
        if (task.id == applyResult.taskId) {
          appliedTask = task;
          break;
        }
      }
    }
    String normalizeStatus(String status) {
      return status
          .trim()
          .toLowerCase()
          .replaceAll('-', '_')
          .replaceAll(' ', '_');
    }

    bool isApprovedStatus(String status) {
      final normalized = normalizeStatus(status);
      if (normalized.isEmpty) {
        return false;
      }
      const exactApproved = <String>{
        'accepted',
        'assigned',
        'arrived',
        'in_progress',
        'code_required',
        'code_verified',
      };
      if (exactApproved.contains(normalized)) {
        return true;
      }
      return normalized.contains('accepted') ||
          normalized.contains('assigned') ||
          normalized.contains('arrived') ||
          normalized.contains('in_progress') ||
          normalized.contains('code_required') ||
          normalized.contains('code_verified');
    }

    final normalizedExecutorStatus = normalizeStatus(executorTaskStatus);
    final hasActiveApplicationLifecycle = hasAppliedTask &&
        !isLocallyCanceledByExecutor &&
        normalizedExecutorStatus != 'rejected' &&
        normalizedExecutorStatus != 'completed';
    final normalizedApplyStatus = normalizeStatus(applyResult.status);
    final normalizedAppliedTaskStatus =
        normalizeStatus(appliedTask?.status ?? '');
    final canEnterCodeByStatus = isApprovedStatus(normalizedExecutorStatus) ||
        isApprovedStatus(normalizedApplyStatus) ||
        isApprovedStatus(normalizedAppliedTaskStatus);
    final isCodeVerified =
        verifyResult.applicationId == applyResult.applicationId &&
            verifyResult.status == 'code_verified';
    final isAwaitingCodeEntry = !executorCompletionShown &&
        hasActiveApplicationLifecycle &&
        canEnterCodeByStatus &&
        !isCodeVerified;
    final isWaitingCreatorConfirm = !executorCompletionShown &&
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
                      'MAPBOX_ACCESS_TOKEN is not set',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              : MapWidget(
                  key: const ValueKey('mapbox-map-widget'),
                  styleUri: MapUiPalette.mapStyleUri,
                  cameraOptions: CameraOptions(
                    center: Point(
                        coordinates: Position(viewModel.centerLongitude,
                            viewModel.centerLatitude)),
                    zoom: viewModel.zoom,
                  ),
                  onMapCreated: onMapCreated,
                  onCameraChangeListener: onCameraChanged,
                  onTapListener: (_) {
                    debugPrint('[MapContent] map background tap');
                    onTapMapBackground();
                  },
                ),
        ),
        Positioned(
          top: topBannerTop,
          left: topBannerInset,
          right: topBannerInset,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SizedBox(
                width: 400,
                height: 107,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const RadialGradient(
                          center: Alignment.center,
                          radius: 0.95,
                          colors: [
                            MapUiPalette.bannerGradientInner,
                            MapUiPalette.bannerGradientOuter,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: MapUiPalette.panelBorder.withValues(alpha: 0.55),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: MapUiPalette.bannerShadow,
                            blurRadius: 5,
                            spreadRadius: 1,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'GLOBAL RANKING CYCLE',
                            style: TextStyles.bodySecondary.copyWith(
                              color: MapUiPalette.subtleText,
                              letterSpacing: 0.35,
                            ),
                          ),
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: RankingCountdownWidget(),
                          ),
                          Text(
                            'Regional champions update worldwide...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyles.bodySecondary.copyWith(
                              color: MapUiPalette.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (myRequest != null ||
            (!hasExecutorFlowActive && selectedNearbyTask != null))
          Positioned(
            left: requestPanelHorizontalInset,
            right: requestPanelHorizontalInset,
            bottom: floatingPanelBottom,
            child: myRequest != null
                ? (() {
                    final myTask = myRequest;
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
                                filter:
                                    ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Container(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 16, 14, 12),
                                  decoration: BoxDecoration(
                                    color: MapUiPalette.panelBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: MapUiPalette.panelBorder),
                                    boxShadow: [
                                      BoxShadow(
                                        color: MapUiPalette.panelTopGlow,
                                        blurRadius: 12,
                                        offset: const Offset(0, -3),
                                      ),
                                      BoxShadow(
                                        color: MapUiPalette.panelDropShadow,
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
                                                Navigator.of(dialogContext)
                                                    .pop();
                                                mapBloc.add(
                                                  MapEvent.cancelTask(
                                                    MapTaskIdRequest(
                                                        taskId: myTask.id),
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: CustomButton(
                                              text: 'Cancel',
                                              onTap: () =>
                                                  Navigator.of(dialogContext)
                                                      .pop(),
                                              borderRadius: 6,
                                              backgroundColor:
                                                  Colors.transparent,
                                              border: Border.all(
                                                  color: Colors.white38),
                                              textStyle: TextStyles.bodyMain
                                                  .copyWith(
                                                      color: Colors.white70),
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                    tasks: <MapTaskEntity>[selectedNearbyTask!],
                    onApply: (taskId) => mapBloc.add(
                        MapEvent.applyToTask(MapTaskIdRequest(taskId: taskId))),
                  ),
          ),
        Positioned(
          right: topBannerInset,
          top: controlsTop,
          child: _MapControlsPanel(
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onCurrentLocation: onCurrentLocation,
          ),
        ),
        if (myRequest != null && visibleApplications.isNotEmpty)
          Positioned(
            top: overlayTop,
            left: horizontalInset,
            right: horizontalInset,
            child: _RequestsOverlay(
              applications: visibleApplications,
              selectedApplicationId: selectedApplicationId,
              onAccept: onAcceptApplication,
              onReject: onRejectApplication,
            ),
          ),
        if (shouldShowExecutorTopStrip)
          Positioned(
            top: overlayTop,
            left: horizontalInset,
            right: horizontalInset,
            child: _ExecutorRequestStrip(
              message:
                  '${executorCreatorName.trim().isEmpty ? 'Creator' : executorCreatorName.trim()} confirm help received',
              onClose: onExecutorCancel,
            ),
          ),
        Positioned(
          left: ctaHorizontalInset,
          right: ctaHorizontalInset,
          bottom: floatingActionBottom,
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
                  : _CreateRequestCta(
                      myRequest: myRequest,
                      hasMyTasksLoaded: viewModel.hasMyTasksLoaded,
                      isBusy: viewModel.isBusy,
                      isCreatingTask: viewModel.isCreatingTask,
                      lockedMessage: lockedMessage,
                      onOpenCreateRequest: onOpenCreateRequest,
                    ),
        ),
      ],
    );
  }
}

/// Кнопка создания запроса: неактивна при активной своей задаче (макет Figma).
class _CreateRequestCta extends StatelessWidget {
  const _CreateRequestCta({
    required this.myRequest,
    required this.hasMyTasksLoaded,
    required this.isBusy,
    required this.isCreatingTask,
    required this.lockedMessage,
    required this.onOpenCreateRequest,
  });

  final MapTaskEntity? myRequest;
  final bool hasMyTasksLoaded;
  final bool isBusy;
  final bool isCreatingTask;
  final String? lockedMessage;
  final VoidCallback onOpenCreateRequest;

  @override
  Widget build(BuildContext context) {
    final locked = !hasMyTasksLoaded || lockedMessage != null;
    final disabled = isBusy || isCreatingTask || locked;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 50,
          child: CustomButton(
            text: 'Create a request for help',
            onTap: disabled ? () {} : onOpenCreateRequest,
            isDisabled: disabled,
            borderRadius: 6,
            backgroundColor: disabled
                ? MapUiPalette.ctaDisabledBackground
                : MapUiPalette.ctaBackground,
            border: Border.all(color: MapUiPalette.ctaBorder),
            textStyle: TextStyles.bodyLarge.copyWith(
              color: disabled ? Colors.white54 : Colors.white,
            ),
            prefixIcon: Icon(
              Icons.add,
              color: disabled ? Colors.white54 : Colors.white,
              size: 18,
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          ),
        ),
        if (!hasMyTasksLoaded) ...[
          const SizedBox(height: 8),
          Text(
            'Checking request availability...',
            textAlign: TextAlign.center,
            style: TextStyles.bodyMain.copyWith(
              color: MapUiPalette.mutedText,
              fontSize: 12,
            ),
          ),
        ] else if (lockedMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            lockedMessage!,
            textAlign: TextAlign.center,
            style: TextStyles.bodyMain.copyWith(
              color: MapUiPalette.mutedText,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _NearbyTaskMarkersLayer extends StatefulWidget {
  const _NearbyTaskMarkersLayer({
    required this.mapboxMap,
    required this.tasks,
    required this.selectedTaskId,
    required this.onTapTask,
  });

  final MapboxMap mapboxMap;
  final List<MapTaskEntity> tasks;
  final String? selectedTaskId;
  final ValueChanged<String> onTapTask;

  @override
  State<_NearbyTaskMarkersLayer> createState() =>
      _NearbyTaskMarkersLayerState();
}

class _NearbyTaskMarkersLayerState extends State<_NearbyTaskMarkersLayer> {
  PointAnnotationManager? _annotationManager;
  Cancelable? _tapCancelable;
  final Map<String, PointAnnotation> _annotationsByTaskId =
      <String, PointAnnotation>{};
  final Map<String, String> _taskIdByAnnotationId = <String, String>{};
  final Map<String, String> _visualKeyByTaskId = <String, String>{};
  final Map<String, String> _positionKeyByTaskId = <String, String>{};
  Uint8List? _normalMarkerImage;
  Uint8List? _selectedMarkerImage;
  Uint8List? _highlightedMarkerImage;
  Uint8List? _selectedHighlightedMarkerImage;
  String? _highlightedTaskId;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeAnnotations());
  }

  @override
  void didUpdateWidget(covariant _NearbyTaskMarkersLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapboxMap != widget.mapboxMap) {
      unawaited(_recreateAnnotations());
      return;
    }

    if (oldWidget.tasks != widget.tasks ||
        oldWidget.selectedTaskId != widget.selectedTaskId) {
      unawaited(_syncAnnotations());
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _highlightTimer = null;
    _tapCancelable?.cancel();
    _tapCancelable = null;
    final manager = _annotationManager;
    _annotationManager = null;
    if (manager != null) {
      unawaited(manager.deleteAll());
    }
    super.dispose();
  }

  Future<void> _recreateAnnotations() async {
    _tapCancelable?.cancel();
    _tapCancelable = null;
    final oldManager = _annotationManager;
    _annotationManager = null;
    if (oldManager != null) {
      await oldManager.deleteAll();
    }
    _annotationsByTaskId.clear();
    _taskIdByAnnotationId.clear();
    _visualKeyByTaskId.clear();
    _positionKeyByTaskId.clear();
    await _initializeAnnotations();
  }

  Future<void> _initializeAnnotations() async {
    _normalMarkerImage ??=
        await _createTaskMarkerImage(isSelected: false, isHighlighted: false);
    _selectedMarkerImage ??=
        await _createTaskMarkerImage(isSelected: true, isHighlighted: false);
    _highlightedMarkerImage ??=
        await _createTaskMarkerImage(isSelected: false, isHighlighted: true);
    _selectedHighlightedMarkerImage ??=
        await _createTaskMarkerImage(isSelected: true, isHighlighted: true);

    final manager =
        await widget.mapboxMap.annotations.createPointAnnotationManager();
    if (!mounted) {
      await manager.deleteAll();
      return;
    }
    _annotationManager = manager;
    await manager.setIconAllowOverlap(true);
    await manager.setIconIgnorePlacement(true);

    _tapCancelable = manager.tapEvents(
      onTap: (annotation) {
        final taskId = _taskIdByAnnotationId[annotation.id];
        if (taskId == null) {
          return;
        }
        _handleMarkerTap(taskId);
      },
    );
    await _syncAnnotations();
  }

  void _handleMarkerTap(String taskId) {
    final wasSelected = widget.selectedTaskId == taskId;

    // Always show highlight for immediate visual feedback
    _highlightTimer?.cancel();
    _highlightedTaskId = taskId;

    // Update the selection state
    widget.onTapTask(taskId);

    // Sync annotations to show immediate visual feedback
    unawaited(_syncAnnotations());

    // If the marker was already selected, the tap will deselect it
    // In this case, we want to clear the highlight quickly
    if (wasSelected) {
      _highlightTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted || _highlightedTaskId != taskId) {
          return;
        }
        _highlightedTaskId = null;
        unawaited(_syncAnnotations());
      });
    } else {
      // For newly selected markers, keep highlight longer
      _highlightTimer = Timer(const Duration(milliseconds: 2500), () {
        if (!mounted || _highlightedTaskId != taskId) {
          return;
        }
        _highlightedTaskId = null;
        unawaited(_syncAnnotations());
      });
    }
  }

  Future<void> _syncAnnotations() async {
    final manager = _annotationManager;
    if (manager == null || !mounted) {
      return;
    }

    final nextTaskIds = widget.tasks.map((task) => task.id).toSet();
    final existingTaskIds = _annotationsByTaskId.keys.toList(growable: false);
    for (final taskId in existingTaskIds) {
      if (!nextTaskIds.contains(taskId)) {
        final annotation = _annotationsByTaskId.remove(taskId);
        if (annotation != null) {
          await manager.delete(annotation);
          _taskIdByAnnotationId.remove(annotation.id);
        }
        _visualKeyByTaskId.remove(taskId);
        _positionKeyByTaskId.remove(taskId);
      }
    }

    for (final task in widget.tasks) {
      final isSelected = task.id == widget.selectedTaskId;
      final isHighlighted = task.id == _highlightedTaskId;
      final visualKey = '$isSelected-$isHighlighted';
      final positionKey = '${task.latitude}-${task.longitude}';
      final markerImage = _resolveMarkerImage(
        isSelected: isSelected,
        isHighlighted: isHighlighted,
      );

      final existing = _annotationsByTaskId[task.id];
      if (existing == null) {
        final created = await manager.create(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(task.longitude, task.latitude),
            ),
            iconAnchor: IconAnchor.BOTTOM,
            image: markerImage,
            iconSize: 1.0,
          ),
        );
        _annotationsByTaskId[task.id] = created;
        _taskIdByAnnotationId[created.id] = task.id;
        _visualKeyByTaskId[task.id] = visualKey;
        _positionKeyByTaskId[task.id] = positionKey;
        continue;
      }

      final hasVisualChanged = _visualKeyByTaskId[task.id] != visualKey;
      final hasPositionChanged = _positionKeyByTaskId[task.id] != positionKey;
      if (!hasVisualChanged && !hasPositionChanged) {
        continue;
      }

      if (hasVisualChanged) {
        existing.image = markerImage;
      }
      if (hasPositionChanged) {
        existing.geometry = Point(
          coordinates: Position(task.longitude, task.latitude),
        );
      }
      await manager.update(existing);
      _visualKeyByTaskId[task.id] = visualKey;
      _positionKeyByTaskId[task.id] = positionKey;
    }
  }

  Uint8List _resolveMarkerImage({
    required bool isSelected,
    required bool isHighlighted,
  }) {
    if (isSelected && isHighlighted) {
      return _selectedHighlightedMarkerImage!;
    }
    if (isHighlighted) {
      return _highlightedMarkerImage!;
    }
    if (isSelected) {
      return _selectedMarkerImage!;
    }
    return _normalMarkerImage!;
  }

  Future<Uint8List> _createTaskMarkerImage({
    required bool isSelected,
    required bool isHighlighted,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const width = 220.0;
    const height = 230.0;
    const triangleSize = ui.Size(40, 30);
    const triangleCenter = ui.Offset(width / 2, 200);

    if (isHighlighted) {
      final glowPaint = Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0x99000000),
            Color(0x55000000),
            Color(0x00000000),
          ],
          stops: [0.0, 0.52, 1.0],
        ).createShader(
          Rect.fromCircle(center: triangleCenter, radius: 120),
        );
      canvas.drawCircle(triangleCenter, 120, glowPaint);
    }

    // Show user icon when selected OR highlighted (for immediate visual feedback)
    if (isSelected || isHighlighted) {
      const bubbleCenter = ui.Offset(width / 2, 150);
      final bubblePaint = Paint()..color = const Color(0xFF2E3D50);
      canvas.drawCircle(bubbleCenter, 24, bubblePaint);
      final bubbleStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xB3FFFFFF);
      canvas.drawCircle(bubbleCenter, 24, bubbleStroke);

      final personPaint = Paint()..color = Colors.white;
      canvas.drawCircle(const ui.Offset(width / 2, 142), 7.0, personPaint);
      final bodyPath = Path()
        ..moveTo(width / 2 - 12, 162)
        ..quadraticBezierTo(width / 2, 148, width / 2 + 12, 162)
        ..lineTo(width / 2 + 12, 168)
        ..lineTo(width / 2 - 12, 168)
        ..close();
      canvas.drawPath(bodyPath, personPaint);
    }

    canvas.save();
    canvas.translate(
      triangleCenter.dx - triangleSize.width / 2,
      triangleCenter.dy - triangleSize.height / 2,
    );
    _RequestTrianglePainter(isSelected: isSelected).paint(canvas, triangleSize);
    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _RequestTrianglePainter extends CustomPainter {
  const _RequestTrianglePainter({required this.isSelected});

  final bool isSelected;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(1, 1)
      ..lineTo(size.width - 1, 1)
      ..close();

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final fillPaint = Paint()
      ..shader = (isSelected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFECECEC),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF0F0F0),
                    Color(0xFFDADADA),
                  ],
                ))
          .createShader(rect);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = isSelected ? const Color(0xFF7E7E7E) : const Color(0xFF8F8F8F);

    if (isSelected) {
      final glowPaint = Paint()
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4)
        ..color = const Color(0x66FFFFFF);
      canvas.drawPath(path, glowPaint);
    }

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _RequestTrianglePainter oldDelegate) {
    return oldDelegate.isSelected != isSelected;
  }
}
