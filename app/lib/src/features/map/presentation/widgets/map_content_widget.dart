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
    final myRequest = MapFlowEvaluator.findCreatorActiveTask(viewModel.myTasks);

    final nearbyTasks = viewModel.nearbyTasks.toList(growable: false);
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
                      'MAPBOX_ACCESS_TOKEN РЅРµ Р·Р°РґР°РЅ',
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
                                filter:
                                    ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Container(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 16, 14, 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6D6D6D)
                                        .withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFF656565)),
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
