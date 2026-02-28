import 'dart:async';

import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_application_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:app/src/features/map/domain/requests/map_nearby_tasks_request.dart';
import 'package:app/src/features/map/domain/requests/map_task_application_id_request.dart';
import 'package:app/src/features/map/domain/requests/map_task_id_request.dart';
import 'package:app/src/features/map/domain/requests/map_verify_code_request.dart';
import 'package:app/src/features/map/presentation/bloc/map_bloc.dart';
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

  late final MapBloc _mapBloc;
  MapboxMap? _mapboxMap;
  double _currentLatitude = 50.4501;
  double _currentLongitude = 30.5234;
  bool _isRequestExpanded = false;

  @override
  void initState() {
    super.initState();
    _mapBloc = getIt<MapBloc>();
    _mapBloc.add(const MapEvent.loadMap());

    if (_mapboxAccessToken.isNotEmpty) {
      MapboxOptions.setAccessToken(_mapboxAccessToken);
    }
  }

  @override
  void dispose() {
    // Don't close MapBloc - it's managed by GetIt
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message), backgroundColor: Colors.red),
              );
            },
            loaded: (viewModel) {
              // Task cancelled?
              if (viewModel.cancelTaskResult.isNotEmpty) {
                context.push(RoutePaths.mapRequestCanceled);
              }
              // Task completed?
              if (viewModel.confirmCompletionResult.taskId.isNotEmpty) {
                if (viewModel.confirmCompletionResult.taskStatus == 'completed') {
                  context.push(RoutePaths.mapRequestCompleted);
                } else if (viewModel.confirmCompletionResult.reward > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reward: ${viewModel.confirmCompletionResult.reward}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
              // Applied to task?
              if (viewModel.applyToTaskResult.applicationId.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Applied! Status: ${viewModel.applyToTaskResult.status}'),
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
                onToggleExpanded: () => setState(() => _isRequestExpanded = !_isRequestExpanded),
                onMapCreated: _onMapCreated,
                onCameraChanged: _onCameraChanged,
              ),
              loadingError: (_) => const SizedBox.shrink(), // Handled by listener
              loaded: (vm) => _MapContent(
                viewModel: vm,
                mapboxMap: _mapboxMap,
                isRequestExpanded: _isRequestExpanded,
                isLoading: false,
                onToggleExpanded: () => setState(() => _isRequestExpanded = !_isRequestExpanded),
                onMapCreated: _onMapCreated,
                onCameraChanged: _onCameraChanged,
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

    // Load nearby tasks
    _mapBloc.add(MapEvent.getNearbyTasks(
      MapNearbyTasksRequest(
        lat: _currentLatitude,
        lon: _currentLongitude,
        radiusM: 2000,
        limit: 50,
      ),
    ));
  }

  void _onCameraChanged(CameraChangedEventData eventData) {
    _currentLatitude = eventData.cameraState.center.coordinates.lat.toDouble();
    _currentLongitude = eventData.cameraState.center.coordinates.lng.toDouble();
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
  });

  final MapViewModel viewModel;
  final MapboxMap? mapboxMap;
  final bool isRequestExpanded;
  final bool isLoading;
  final VoidCallback onToggleExpanded;
  final void Function(MapboxMap) onMapCreated;
  final void Function(CameraChangedEventData) onCameraChanged;

  @override
  Widget build(BuildContext context) {
    final mapBloc = getIt<MapBloc>();
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
                    center: Point(coordinates: Position(viewModel.centerLongitude, viewModel.centerLatitude)),
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GLOBAL RANKINGS UPDATE',
                  style: TextStyles.bodyMain.copyWith(
                    color: Colors.white54,
                    letterSpacing: 0.35,
                  ),
                ),
                const SizedBox(height: 6),
                if (viewModel.champions.isNotEmpty)
                  Text(
                    'Champions: ${viewModel.champions.length}',
                    style: TextStyles.titleBig.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  const Text(
                    'Loading...',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Regional champions update worldwide...',
                  style: TextStyles.bodyMain.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 122,
          left: 18,
          right: 18,
          child: _NearbyTasksPanel(
            tasks: viewModel.nearbyTasks,
            onApply: (taskId) => mapBloc.add(MapEvent.applyToTask(MapTaskIdRequest(taskId: taskId))),
          ),
        ),
        if (viewModel.taskApplications.isNotEmpty)
          Positioned(
            top: 220,
            left: 14,
            right: 14,
            child: _RequestsOverlay(
              applications: viewModel.taskApplications,
            ),
          ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 82,
          child: CustomButton(
            text: 'Create a request for help',
            onTap: () {
              context.push(
                RoutePaths.mapCreateRequest,
                extra: <String, dynamic>{
                  'latitude': viewModel.centerLatitude,
                  'longitude': viewModel.centerLongitude,
                },
              );
            },
            borderRadius: 12,
            backgroundColor: viewModel.isBusy || viewModel.isCreatingTask
                ? Colors.black.withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: 0.78),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            textStyle: TextStyles.bodyLarge.copyWith(
              color: viewModel.isBusy || viewModel.isCreatingTask ? Colors.white54 : Colors.white,
            ),
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}
