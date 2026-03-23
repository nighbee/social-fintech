import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/code_input_field.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/features/map/domain/entities/map_task_application_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:app/src/features/map/domain/requests/map_task_application_id_request.dart';
import 'package:app/src/features/map/domain/requests/map_task_id_request.dart';
import 'package:app/src/features/map/domain/requests/map_verify_code_request.dart';
import 'package:app/src/features/map/presentation/bloc/map_bloc.dart';
import 'package:app/src/features/map/presentation/controllers/map_page_controller.dart';
import 'package:app/src/features/map/presentation/mixins/show_champion_leaderboard_bottom_sheet.dart';
import 'package:app/src/features/map/presentation/services/map_dialog_service.dart';
import 'package:app/src/features/map/presentation/services/map_persistence_service.dart';
import 'package:app/src/features/map/presentation/services/map_polling_service.dart';
import 'package:app/src/features/map/presentation/utils/map_flow_evaluator.dart';
import 'package:app/src/features/ranking/presentation/widgets/ranking_countdown_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

part '../widgets/map_requests_overlay_widget.dart';
part '../widgets/map_nearby_tasks_panel_widget.dart';
part '../widgets/map_loading_widget.dart';
part '../widgets/map_content_widget.dart';
part '../widgets/map_verify_code_page.dart';
part '../widgets/map_controls_panel_widget.dart';
part '../widgets/map_zoom_control_group_widget.dart';
part '../widgets/map_zoom_half_button_widget.dart';
part '../widgets/map_control_button_widget.dart';
part '../widgets/executor_request_strip_widget.dart';
part '../widgets/executor_completed_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage>
    with ShowChampionLeaderboardBottomSheet {
  static const String _mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );
  late final MapPageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MapPageController(
      mapBloc: getIt<MapBloc>(),
      persistence: const MapPersistenceService(),
      polling: MapPollingService(),
      dialogs: MapDialogService(),
      requestSetState: (fn) {
        if (mounted) {
          setState(fn);
        }
      },
      onChampionTap: (champion, champions) {
        if (!mounted) {
          return;
        }

        showChampionLeaderboardBottomSheet(
          context,
          selectedChampion: champion,
          champions: champions,
          onOpenProfile: (userId) {
            context.pushNamed(
              RouteNames.publicProfile,
              pathParameters: <String, String>{'userId': userId},
            );
          },
        );
      },
    );
    _controller.onInit();

    if (_mapboxAccessToken.isNotEmpty) {
      MapboxOptions.setAccessToken(_mapboxAccessToken);
    }
  }

  @override
  void dispose() {
    _controller.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.map),
      body: BlocListener<MapBloc, MapState>(
        bloc: _controller.mapBloc,
        listener: (context, state) {
          state.maybeWhen(
            loadingError: (message) =>
                unawaited(_controller.onLoadingError(context, message)),
            loaded: (viewModel) => unawaited(
              _controller.onLoaded(
                context,
                viewModel,
                runSetState: setState,
                mounted: mounted,
                onNavigateExecutorCompleted: () async {
                  if (context.mounted) {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _ExecutorCompletedPage(),
                      ),
                    );
                  }
                },
              ),
            ),
            orElse: () {},
          );
        },
        child: BlocBuilder<MapBloc, MapState>(
          bloc: _controller.mapBloc,
          builder: (context, state) {
            return state.when(
              initial: () => const _MapLoading(),
              loading: (vm) => _MapContent(
                viewModel: vm,
                mapboxMap: _controller.mapboxMap,
                isRequestExpanded: _controller.isRequestExpanded,
                isLoading: true,
                onToggleExpanded: () =>
                    setState(_controller.toggleRequestExpanded),
                onMapCreated: _controller.onMapCreated,
                onCameraChanged: (eventData) =>
                    setState(() => _controller.onCameraChanged(eventData)),
                onOpenCreateRequest: () =>
                    _controller.openCreateRequest(context),
                onOpenVerifyCode: (taskId, applicationId) =>
                    Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _VerifyCodePage(
                      mapBloc: _controller.mapBloc,
                      taskId: taskId,
                      applicationId: applicationId,
                    ),
                  ),
                ),
                onZoomIn: () => _controller.zoomBy(1),
                onZoomOut: () => _controller.zoomBy(-1),
                onCurrentLocation: () =>
                    _controller.moveToCurrentLocation(context),
                onTapMapBackground: () =>
                    setState(_controller.clearNearbyTaskSelection),
                selectedApplicationId: _controller.selectedApplicationId,
                locallyRejectedApplicationIds:
                    _controller.locallyRejectedApplicationIds,
                onAcceptApplication: (application) =>
                    _controller.handleAcceptApplication(application,
                        runSetState: setState),
                onRejectApplication: (application) =>
                    _controller.handleRejectApplication(application,
                        runSetState: setState),
                onExecutorCancel: () =>
                    _controller.handleExecutorCancel(context),
                executorCompletionShown: _controller.executorCompletionShown,
                executorTaskStatus: _controller.executorTaskStatus,
                executorCreatorName: _controller.executorCreatorName,
                locallyCanceledExecutorApplicationIds:
                    _controller.locallyCanceledExecutorApplicationIds,
                selectedNearbyTaskId: _controller.selectedNearbyTaskId,
                onSelectNearbyTask: (taskId) =>
                    setState(() => _controller.selectNearbyTask(taskId)),
              ),
              loadingError: (_) =>
                  const SizedBox.shrink(), // Handled by listener
              loaded: (vm) => _MapContent(
                viewModel: vm,
                mapboxMap: _controller.mapboxMap,
                isRequestExpanded: _controller.isRequestExpanded,
                isLoading: false,
                onToggleExpanded: () =>
                    setState(_controller.toggleRequestExpanded),
                onMapCreated: _controller.onMapCreated,
                onCameraChanged: (eventData) =>
                    setState(() => _controller.onCameraChanged(eventData)),
                onOpenCreateRequest: () =>
                    _controller.openCreateRequest(context),
                onOpenVerifyCode: (taskId, applicationId) =>
                    Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _VerifyCodePage(
                      mapBloc: _controller.mapBloc,
                      taskId: taskId,
                      applicationId: applicationId,
                    ),
                  ),
                ),
                onZoomIn: () => _controller.zoomBy(1),
                onZoomOut: () => _controller.zoomBy(-1),
                onCurrentLocation: () =>
                    _controller.moveToCurrentLocation(context),
                onTapMapBackground: () =>
                    setState(_controller.clearNearbyTaskSelection),
                selectedApplicationId: _controller.selectedApplicationId,
                locallyRejectedApplicationIds:
                    _controller.locallyRejectedApplicationIds,
                onAcceptApplication: (application) =>
                    _controller.handleAcceptApplication(application,
                        runSetState: setState),
                onRejectApplication: (application) =>
                    _controller.handleRejectApplication(application,
                        runSetState: setState),
                onExecutorCancel: () =>
                    _controller.handleExecutorCancel(context),
                executorCompletionShown: _controller.executorCompletionShown,
                executorTaskStatus: _controller.executorTaskStatus,
                executorCreatorName: _controller.executorCreatorName,
                locallyCanceledExecutorApplicationIds:
                    _controller.locallyCanceledExecutorApplicationIds,
                selectedNearbyTaskId: _controller.selectedNearbyTaskId,
                onSelectNearbyTask: (taskId) =>
                    setState(() => _controller.selectNearbyTask(taskId)),
              ),
            );
          },
        ),
      ),
    );
  }
}
