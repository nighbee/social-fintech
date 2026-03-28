import 'dart:async';
import 'dart:ui' as ui;

import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapRequestMarkerService {
  static const double _defaultIconSize = 1.0;
  static const double _selectedIconSize = 1.2;
  static const double _figmaTriangleW = 37.327468872070455;
  static const double _figmaTriangleH = 32.99999618530286;
  static const double _triangleBorderWidth = 2.0;

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
  bool? _selectionIndicatorShowsGlow;

  Uint8List? _normalMarkerImage;
  Uint8List? _selectedMarkerImage;
  Uint8List? _selectionIndicatorGlowImage;
  Uint8List? _selectionIndicatorPlainImage;
  Timer? _selectionGlowTimer;
  bool _showSelectionGlow = false;

  String? _selectedTaskId;
  void Function(String? selectedTaskId)? _onSelectionChanged;
  int _lifecycleToken = 0;
  static const int _managerInitAttempts = 3;

  Future<void> initialize(
    MapboxMap map, {
    required void Function(String? selectedTaskId) onSelectionChanged,
  }) async {
    final token = ++_lifecycleToken;
    await _disposeInternal();
    if (!_isTokenActive(token)) {
      return;
    }

    try {
      _mapboxMap = map;
      _onSelectionChanged = onSelectionChanged;
      _normalMarkerImage ??= await _createTriangleMarkerImage(isSelected: false);
      _selectedMarkerImage ??= await _createTriangleMarkerImage(isSelected: true);
      if (!_isTokenActive(token)) {
        return;
      }

      // Create selection-indicator manager first so it renders under task markers.
      final selectionManager =
          await _createManagerWithRetry(map, token: token);
      if (selectionManager == null || !_isTokenActive(token)) {
        return;
      }
      _selectionIndicatorManager = selectionManager;
      await selectionManager.setIconAllowOverlap(true);
      await selectionManager.setIconIgnorePlacement(true);

      final manager = await _createManagerWithRetry(map, token: token);
      if (manager == null || !_isTokenActive(token)) {
        return;
      }
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
    } on PlatformException catch (error) {
      if (error.code == 'channel-error') {
        await _disposeInternal();
        return;
      }
      rethrow;
    }
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
    _selectionGlowTimer?.cancel();
    _selectionGlowTimer = null;
    _showSelectionGlow = false;
    _selectedTaskId = null;
    await _updateSelectionIndicator();
    await _syncVisualsAndPositions();
  }

  Future<void> dispose() async {
    _lifecycleToken++;
    await _disposeInternal();
  }

  Future<void> _disposeInternal() async {
    _tapCancelable?.cancel();
    _tapCancelable = null;
    final manager = _annotationManager;
    _annotationManager = null;
    if (manager != null) {
      await _deleteAllSafely(manager);
    }
    final selectionManager = _selectionIndicatorManager;
    _selectionIndicatorManager = null;
    if (selectionManager != null) {
      await _deleteAllSafely(selectionManager);
    }
    _selectionIndicator = null;
    _selectionIndicatorShowsGlow = null;
    _selectionGlowTimer?.cancel();
    _selectionGlowTimer = null;
    _showSelectionGlow = false;
    _selectionIndicatorGlowImage = null;
    _selectionIndicatorPlainImage = null;
    _annotationsByTaskId.clear();
    _taskIdByAnnotationId.clear();
    _selectedByTaskId.clear();
    _tasksById.clear();
    _selectedTaskId = null;
    _onSelectionChanged = null;
    _mapboxMap = null;
  }

  bool _isTokenActive(int token) => token == _lifecycleToken;

  Future<PointAnnotationManager?> _createManagerWithRetry(
    MapboxMap map, {
    required int token,
  }) async {
    for (var attempt = 0; attempt < _managerInitAttempts; attempt++) {
      if (!_isTokenActive(token)) {
        return null;
      }
      try {
        return await map.annotations.createPointAnnotationManager();
      } on MissingPluginException {
        if (attempt == _managerInitAttempts - 1) {
          return null;
        }
      } on PlatformException catch (error) {
        if (error.code != 'channel-error' || attempt == _managerInitAttempts - 1) {
          rethrow;
        }
      }
      await Future<void>.delayed(Duration(milliseconds: 120 * (attempt + 1)));
    }
    return null;
  }

  Future<void> _deleteAllSafely(PointAnnotationManager manager) async {
    try {
      await manager.deleteAll();
    } on PlatformException catch (error) {
      if (error.code == 'channel-error') {
        return;
      }
      rethrow;
    }
  }

  Future<void> _handleTap(String taskId) async {
    _selectionGlowTimer?.cancel();
    _selectedTaskId = taskId;
    _showSelectionGlow = true;
    await _updateSelectionIndicator();
    _onSelectionChanged?.call(taskId);
    await _syncVisualsAndPositions();
    _selectionGlowTimer = Timer(const Duration(seconds: 3), () async {
      if (_selectedTaskId == null) {
        return;
      }
      _showSelectionGlow = false;
      await _updateSelectionIndicator();
    });
  }

  Future<void> _updateSelectionIndicator() async {
    final manager = _selectionIndicatorManager;
    if (manager == null) {
      return;
    }

    final selectedTaskId = _selectedTaskId;
    if (selectedTaskId == null) {
      final existing = _selectionIndicator;
      if (existing != null) {
        await manager.delete(existing);
        _selectionIndicator = null;
        _selectionIndicatorShowsGlow = null;
      }
      return;
    }

    final task = _tasksById[selectedTaskId];
    if (task == null) {
      return;
    }

    _selectionIndicatorGlowImage ??=
        await _createSelectionIndicatorImage(showGlow: true);
    _selectionIndicatorPlainImage ??=
        await _createSelectionIndicatorImage(showGlow: false);
    final indicatorImage = _showSelectionGlow
        ? _selectionIndicatorGlowImage!
        : _selectionIndicatorPlainImage!;

    final geometry = Point(
      coordinates: Position(task.longitude, task.latitude),
    );

    final existing = _selectionIndicator;
    if (existing == null) {
      _selectionIndicator = await manager.create(
        PointAnnotationOptions(
          geometry: geometry,
          iconAnchor: IconAnchor.BOTTOM,
          image: indicatorImage,
          iconSize: 1.0,
        ),
      );
      _selectionIndicatorShowsGlow = _showSelectionGlow;
    } else {
      if (_selectionIndicatorShowsGlow != _showSelectionGlow) {
        await manager.delete(existing);
        _selectionIndicator = await manager.create(
          PointAnnotationOptions(
            geometry: geometry,
            iconAnchor: IconAnchor.BOTTOM,
            image: indicatorImage,
            iconSize: 1.0,
          ),
        );
      } else {
        existing.geometry = geometry;
        await manager.update(existing);
      }
      _selectionIndicatorShowsGlow = _showSelectionGlow;
    }

    // Force map to redraw
    await _mapboxMap?.triggerRepaint();
  }

  Future<Uint8List> _createSelectionIndicatorImage({
    required bool showGlow,
  }) async {
    const width = 220.0;
    const height = 240.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Center position for the entire marker (circle + triangle)
    const markerCenter = ui.Offset(width / 2, 140);
    const circleCenter = ui.Offset(width / 2, 140);
    const circleRadius = 24.0;

    if (showGlow) {
      // Circular glow under marker; large and non-rectangular.
      final glowPaint = Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xA6000000),
            Color(0x52000000),
            Color(0x00000000),
          ],
          stops: [0.0, 0.58, 1.0],
        ).createShader(
          Rect.fromCircle(center: markerCenter, radius: 112),
        );
      canvas.drawCircle(markerCenter, 112, glowPaint);
    }

    // Draw black border on circle
    final blackBorderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1);
    canvas.drawCircle(circleCenter, circleRadius, blackBorderPaint);

    // Draw one stable avatar placeholder (no network image swapping).
    final avatarBgPaint = Paint()..color = const Color(0xFF5C6B81);
    canvas.drawCircle(circleCenter, circleRadius - 2.5, avatarBgPaint);

    final personPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      ui.Offset(circleCenter.dx, circleCenter.dy - 6),
      6.2,
      personPaint,
    );
    final bodyPath = Path()
      ..moveTo(circleCenter.dx - 11, circleCenter.dy + 11)
      ..quadraticBezierTo(
        circleCenter.dx,
        circleCenter.dy - 1,
        circleCenter.dx + 11,
        circleCenter.dy + 11,
      )
      ..lineTo(circleCenter.dx + 11, circleCenter.dy + 15)
      ..lineTo(circleCenter.dx - 11, circleCenter.dy + 15)
      ..close();
    canvas.drawPath(bodyPath, personPaint);

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
    const pad = 4.0;
    final scale = isSelected ? 1.12 : 1.0;
    final tw = _figmaTriangleW * scale;
    final th = _figmaTriangleH * scale;
    final width = tw + pad * 2 + _triangleBorderWidth * 2;
    final height = th + pad * 2 + _triangleBorderWidth * 2;

    final cx = width / 2;
    final bottomY = height - pad - _triangleBorderWidth;
    final topY = bottomY - th;
    final path = Path()
      ..moveTo(cx, bottomY)
      ..lineTo(cx - tw / 2, topY)
      ..lineTo(cx + tw / 2, topY)
      ..close();

    final triangleBounds = Rect.fromLTRB(
      cx - tw / 2,
      topY,
      cx + tw / 2,
      bottomY,
    );
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFEEEEEE),
          Color(0xFFA3A3A3),
        ],
      ).createShader(triangleBounds);

    canvas.drawPath(path, fillPaint);

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      triangleBounds,
      Paint()..color = const Color(0x33000000),
    );
    canvas.restore();

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _triangleBorderWidth
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF333333);

    canvas.drawPath(path, strokePaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      width.ceil(),
      height.ceil(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
