import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapRequestMarkerService {
  static const double _defaultIconSize = 1.0;
  static const double _selectedIconSize = 1.45;

  PointAnnotationManager? _annotationManager;
  PointAnnotationManager? _selectionIndicatorManager;
  MapboxMap? _mapboxMap;
  Cancelable? _tapCancelable;
  final Map<String, PointAnnotation> _annotationsByTaskId =
      <String, PointAnnotation>{};
  final Map<String, String> _taskIdByAnnotationId = <String, String>{};
  final Map<String, bool> _selectedByTaskId = <String, bool>{};
  final Map<String, MapTaskEntity> _tasksById = <String, MapTaskEntity>{};
  PointAnnotation? _selectionIndicator;

  Uint8List? _normalMarkerImage;
  Uint8List? _selectedMarkerImage;

  String? _selectedTaskId;
  void Function(String? selectedTaskId)? _onSelectionChanged;

  Future<void> initialize(
    MapboxMap map, {
    required void Function(String? selectedTaskId) onSelectionChanged,
  }) async {
    await dispose();
    _mapboxMap = map;
    _onSelectionChanged = onSelectionChanged;
    _normalMarkerImage ??= await _createTriangleMarkerImage(isSelected: false);
    _selectedMarkerImage ??= await _createTriangleMarkerImage(isSelected: true);

    final manager = await map.annotations.createPointAnnotationManager();
    _annotationManager = manager;
    await manager.setIconAllowOverlap(true);
    await manager.setIconIgnorePlacement(true);
    _tapCancelable = manager.tapEvents(
      onTap: (annotation) async {
        final taskId = _taskIdByAnnotationId[annotation.id];
        if (taskId == null) {
          return;
        }
        await _handleTap(taskId);
      },
    );

    // Create separate manager for selection indicator
    final selectionManager = await map.annotations.createPointAnnotationManager();
    _selectionIndicatorManager = selectionManager;
    await selectionManager.setIconAllowOverlap(true);
    await selectionManager.setIconIgnorePlacement(true);
  }

  Future<void> syncTasks(List<MapTaskEntity> tasks) async {
    final manager = _annotationManager;
    if (manager == null) {
      return;
    }

    final nextById = <String, MapTaskEntity>{for (final t in tasks) t.id: t};
    final toRemove = _tasksById.keys
        .where((taskId) => !nextById.containsKey(taskId))
        .toList(growable: false);

    for (final taskId in toRemove) {
      final annotation = _annotationsByTaskId.remove(taskId);
      if (annotation != null) {
        await manager.delete(annotation);
        _taskIdByAnnotationId.remove(annotation.id);
      }
      _selectedByTaskId.remove(taskId);
      _tasksById.remove(taskId);
    }

    _tasksById
      ..clear()
      ..addAll(nextById);

    if (_selectedTaskId != null && !_tasksById.containsKey(_selectedTaskId)) {
      _selectedTaskId = null;
      await _updateSelectionIndicator();
      _onSelectionChanged?.call(null);
    }

    await _syncVisualsAndPositions();
    await _updateSelectionIndicator();
  }

  Future<void> setSelectedTask(String? taskId) async {
    if (_selectedTaskId == taskId) {
      return;
    }
    _selectedTaskId = taskId;
    await _updateSelectionIndicator();
    await _syncVisualsAndPositions();
  }

  Future<void> clearSelection() async {
    _selectedTaskId = null;
    await _updateSelectionIndicator();
    await _syncVisualsAndPositions();
  }

  Future<void> dispose() async {
    _tapCancelable?.cancel();
    _tapCancelable = null;
    final manager = _annotationManager;
    _annotationManager = null;
    if (manager != null) {
      await manager.deleteAll();
    }
    final selectionManager = _selectionIndicatorManager;
    _selectionIndicatorManager = null;
    if (selectionManager != null) {
      await selectionManager.deleteAll();
    }
    _selectionIndicator = null;
    _annotationsByTaskId.clear();
    _taskIdByAnnotationId.clear();
    _selectedByTaskId.clear();
    _tasksById.clear();
    _selectedTaskId = null;
    _onSelectionChanged = null;
    _mapboxMap = null;
  }

  Future<void> _handleTap(String taskId) async {
    _selectedTaskId = taskId;
    await _updateSelectionIndicator();
    _onSelectionChanged?.call(taskId);
    await _syncVisualsAndPositions();
  }

  Future<void> _updateSelectionIndicator() async {
    final manager = _selectionIndicatorManager;
    if (manager == null) {
      return;
    }

    // Remove old indicator
    final oldIndicator = _selectionIndicator;
    if (oldIndicator != null) {
      await manager.delete(oldIndicator);
      _selectionIndicator = null;
    }

    // Add new indicator if task is selected
    final selectedTaskId = _selectedTaskId;
    if (selectedTaskId == null) {
      return;
    }

    final task = _tasksById[selectedTaskId];
    if (task == null) {
      return;
    }

    final indicatorImage = await _createSelectionIndicatorImage();
    final indicator = await manager.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(task.longitude, task.latitude),
        ),
        iconAnchor: IconAnchor.BOTTOM,
        image: indicatorImage,
        iconSize: 1.0,
      ),
    );
    _selectionIndicator = indicator;

    // Force map to redraw
    await _mapboxMap?.triggerRepaint();
  }

  Future<Uint8List> _createSelectionIndicatorImage() async {
    const width = 120.0;
    const height = 160.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    ui.Image? networkImage;
    try {
      // Use a random network image for the selection indicator
      final imageUrl = 'https://i.pravatar.cc/150?img=${DateTime.now().millisecond % 70}';

      final imageProvider = NetworkImage(imageUrl);

      // Load the image from network
      final imageStream = imageProvider.resolve(ImageConfiguration.empty);
      final completer = Completer<ui.Image>();

      ImageStreamListener? listener;
      listener = ImageStreamListener((ImageInfo info, bool synchronousCall) {
        completer.complete(info.image);
        imageStream.removeListener(listener!);
      });

      imageStream.addListener(listener);

      networkImage = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Image load timeout');
        },
      );
    } catch (_) {
      // Network image failed, will use fallback
    }

    // Position: circle should be above the triangle
    const circleCenter = ui.Offset(width / 2, 50);
    const circleRadius = 28.0;

    // Draw black border
    final blackBorderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1);
    canvas.drawCircle(circleCenter, circleRadius, blackBorderPaint);

    // Draw white circle background
    final whiteCirclePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(circleCenter, circleRadius - 1, whiteCirclePaint);

    // Draw network image inside circle if loaded
    if (networkImage != null) {
      // Clip to circle
      canvas.clipRRect(
        RRect.fromRectAndRadius(
          Rect.fromCircle(center: circleCenter, radius: circleRadius - 2),
          Radius.circular(circleRadius - 2),
        ),
      );

      // Draw image centered in circle
      final imageSize = ui.Size(circleRadius * 2 - 8, circleRadius * 2 - 8);
      final imageRect = Rect.fromCenter(
        center: circleCenter,
        width: imageSize.width,
        height: imageSize.height,
      );

      paintImage(
        canvas: canvas,
        image: networkImage,
        rect: imageRect,
        scale: 1.0,
        alignment: Alignment.center,
        fit: BoxFit.cover,
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _syncVisualsAndPositions() async {
    final manager = _annotationManager;
    if (manager == null) {
      return;
    }

    for (final task in _tasksById.values) {
      final isSelected = task.id == _selectedTaskId;
      final markerImage =
          isSelected ? _selectedMarkerImage! : _normalMarkerImage!;
      final geometry =
          Point(coordinates: Position(task.longitude, task.latitude));
      final existing = _annotationsByTaskId[task.id];

      if (existing == null) {
        final created = await manager.create(
          PointAnnotationOptions(
            geometry: geometry,
            iconAnchor: IconAnchor.BOTTOM,
            image: markerImage,
            iconSize: isSelected ? _selectedIconSize : _defaultIconSize,
          ),
        );
        _annotationsByTaskId[task.id] = created;
        _taskIdByAnnotationId[created.id] = task.id;
        _selectedByTaskId[task.id] = isSelected;
        continue;
      }

      if (_selectedByTaskId[task.id] != isSelected) {
        await manager.delete(existing);
        _taskIdByAnnotationId.remove(existing.id);
        final recreated = await manager.create(
          PointAnnotationOptions(
            geometry: geometry,
            iconAnchor: IconAnchor.BOTTOM,
            image: markerImage,
            iconSize: isSelected ? _selectedIconSize : _defaultIconSize,
          ),
        );
        _annotationsByTaskId[task.id] = recreated;
        _taskIdByAnnotationId[recreated.id] = task.id;
        _selectedByTaskId[task.id] = isSelected;
        continue;
      }

      if (existing.geometry.coordinates.lat != task.latitude ||
          existing.geometry.coordinates.lng != task.longitude) {
        existing.geometry = geometry;
        await manager.update(existing);
      }
    }
  }

  Future<Uint8List> _createTriangleMarkerImage({
    required bool isSelected,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const width = 90.0;
    const height = 90.0;
    final triangleSize =
        isSelected ? const ui.Size(44, 34) : const ui.Size(30, 23);
    const triangleCenter = ui.Offset(width / 2, 62);

    if (isSelected) {
      const circleCenter = ui.Offset(width / 2, 26);
      final circleFill = Paint()..color = const Color(0xFF2E3D50);
      final circleStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xCCFFFFFF);
      canvas.drawCircle(circleCenter, 12, circleFill);
      canvas.drawCircle(circleCenter, 12, circleStroke);
    }

    final path = Path()
      ..moveTo(triangleCenter.dx, triangleCenter.dy + triangleSize.height / 2)
      ..lineTo(
        triangleCenter.dx - triangleSize.width / 2 + 1,
        triangleCenter.dy - triangleSize.height / 2 + 1,
      )
      ..lineTo(
        triangleCenter.dx + triangleSize.width / 2 - 1,
        triangleCenter.dy - triangleSize.height / 2 + 1,
      )
      ..close();

    final triangleRect = Rect.fromCenter(
      center: triangleCenter,
      width: triangleSize.width,
      height: triangleSize.height,
    );
    final fillPaint = Paint()
      ..shader = (isSelected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFFECECEC)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF0F0F0), Color(0xFFDADADA)],
                ))
          .createShader(triangleRect);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 1.5 : 1.2
      ..color = isSelected ? const Color(0xFF7E7E7E) : const Color(0xFF8F8F8F);

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
