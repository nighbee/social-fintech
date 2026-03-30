import 'dart:async';
import 'dart:ui' as ui;

import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapRequestMarkerService {
  static const double _defaultIconSize = 1.18;
  static const double _selectedIconSize = 1.32;
  /// Figma: обычный таск (наведён / чужой).
  static const double _figmaTriW = 37.327468872070455 * 1.08;
  static const double _figmaTriH = 32.99999618530286 * 1.08;
  static const double _creatorSizeBoost = 1.18;
  static const double _selectionIndicatorBaseIconSize = 1.0;

  double _markerSizeMultiplier = 1.0;

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

  Uint8List? _imgOther;
  Uint8List? _imgOtherSel;
  Uint8List? _imgCreator;
  Uint8List? _imgCreatorSel;
  final Map<String, int> _variantByTaskId = <String, int>{};
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
      _imgOther ??= await _createTriangleMarkerImage(
        isCreator: false,
        isSelected: false,
      );
      _imgOtherSel ??= await _createTriangleMarkerImage(
        isCreator: false,
        isSelected: true,
      );
      _imgCreator ??= await _createTriangleMarkerImage(
        isCreator: true,
        isSelected: false,
      );
      _imgCreatorSel ??= await _createTriangleMarkerImage(
        isCreator: true,
        isSelected: true,
      );
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

  double _taskIconSize(bool isSelected) =>
      (isSelected ? _selectedIconSize : _defaultIconSize) * _markerSizeMultiplier;

  Future<void> applyMarkerSizeMultiplier(double multiplier) async {
    if ((multiplier - _markerSizeMultiplier).abs() < 0.008) {
      return;
    }
    _markerSizeMultiplier = multiplier;
    final manager = _annotationManager;
    if (manager != null) {
      for (final entry in _annotationsByTaskId.entries) {
        final ann = entry.value;
        final sel = _selectedByTaskId[entry.key] ?? false;
        ann.iconSize = _taskIconSize(sel);
        try {
          await manager.update(ann);
        } on PlatformException catch (error) {
          if (error.code != 'channel-error') {
            rethrow;
          }
        }
      }
    }
    final ind = _selectionIndicator;
    final indManager = _selectionIndicatorManager;
    if (ind != null && indManager != null) {
      ind.iconSize = _selectionIndicatorBaseIconSize * _markerSizeMultiplier;
      try {
        await indManager.update(ind);
      } on PlatformException catch (error) {
        if (error.code != 'channel-error') {
          rethrow;
        }
      }
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
      _variantByTaskId.remove(taskId);
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
    _imgOther = null;
    _imgOtherSel = null;
    _imgCreator = null;
    _imgCreatorSel = null;
    _variantByTaskId.clear();
    _markerSizeMultiplier = 1.0;
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
    final task = _tasksById[taskId];
    // Кольцо с «аватаром» только у своего запроса (mine|…), не у чужих треугольников.
    _showSelectionGlow = task != null && _taskIsCreator(task);
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
    if (!_taskIsCreator(task)) {
      final existing = _selectionIndicator;
      if (existing != null) {
        await manager.delete(existing);
        _selectionIndicator = null;
        _selectionIndicatorShowsGlow = null;
      }
      return;
    }

    _selectionIndicatorGlowImage ??=
        await _createSelectionIndicatorImage(showGlow: true);
    _selectionIndicatorPlainImage ??=
        await _createSelectionIndicatorImage(showGlow: false);
    final indicatorImage = _showSelectionGlow
        ? _selectionIndicatorGlowImage!
        : _selectionIndicatorPlainImage!;

    final pos = _displayCoords(task);
    final geometry = Point(
      coordinates: Position(pos.lon, pos.lat),
    );

    final existing = _selectionIndicator;
    if (existing == null) {
      _selectionIndicator = await manager.create(
        PointAnnotationOptions(
          geometry: geometry,
          iconAnchor: IconAnchor.BOTTOM,
          image: indicatorImage,
          iconSize: _selectionIndicatorBaseIconSize * _markerSizeMultiplier,
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
            iconSize: _selectionIndicatorBaseIconSize * _markerSizeMultiplier,
          ),
        );
      } else {
        existing
          ..geometry = geometry
          ..iconSize = _selectionIndicatorBaseIconSize * _markerSizeMultiplier;
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

    // Снимок: между await другой syncTasks может перезаписать _tasksById — иначе ConcurrentModificationError.
    final tasksSnapshot = _tasksById.values.toList(growable: false);
    for (final task in tasksSnapshot) {
      if (!_tasksById.containsKey(task.id)) {
        continue;
      }
      final variant = _markerVariantIndex(task);
      final markerImage = _bytesForVariant(variant);
      final isSelected = task.id == _selectedTaskId;
      final pos = _displayCoords(task);
      final geometry = Point(coordinates: Position(pos.lon, pos.lat));
      final existing = _annotationsByTaskId[task.id];

      if (existing == null) {
        final created = await manager.create(
          PointAnnotationOptions(
            geometry: geometry,
            iconAnchor: IconAnchor.BOTTOM,
            image: markerImage,
            iconSize: _taskIconSize(isSelected),
          ),
        );
        _annotationsByTaskId[task.id] = created;
        _taskIdByAnnotationId[created.id] = task.id;
        _selectedByTaskId[task.id] = isSelected;
        _variantByTaskId[task.id] = variant;
        continue;
      }

      final variantChanged = _variantByTaskId[task.id] != variant;
      if (variantChanged || _selectedByTaskId[task.id] != isSelected) {
        await manager.delete(existing);
        _taskIdByAnnotationId.remove(existing.id);
        final recreated = await manager.create(
          PointAnnotationOptions(
            geometry: geometry,
            iconAnchor: IconAnchor.BOTTOM,
            image: markerImage,
            iconSize: _taskIconSize(isSelected),
          ),
        );
        _annotationsByTaskId[task.id] = recreated;
        _taskIdByAnnotationId[recreated.id] = task.id;
        _selectedByTaskId[task.id] = isSelected;
        _variantByTaskId[task.id] = variant;
        continue;
      }

      var needsUpdate = false;
      if (existing.geometry.coordinates.lat != pos.lat ||
          existing.geometry.coordinates.lng != pos.lon) {
        existing.geometry = geometry;
        needsUpdate = true;
      }
      final targetSize = _taskIconSize(isSelected);
      if (((existing.iconSize ?? 0) - targetSize).abs() > 0.001) {
        existing.iconSize = targetSize;
        needsUpdate = true;
      }
      if (needsUpdate) {
        await manager.update(existing);
      }
    }
  }

  bool _taskIsCreator(MapTaskEntity task) {
    final s = task.status.trim().toLowerCase();
    return s.startsWith('mine|');
  }

  /// 0 other, 1 other selected, 2 creator, 3 creator selected
  int _markerVariantIndex(MapTaskEntity task) {
    final c = _taskIsCreator(task);
    final sel = task.id == _selectedTaskId;
    if (!c && !sel) {
      return 0;
    }
    if (!c && sel) {
      return 1;
    }
    if (c && !sel) {
      return 2;
    }
    return 3;
  }

  /// Сдвиг пина «мой запрос» от точки создания — не прямо под аватаром self-pin (макет Figma).
  ({double lat, double lon}) _displayCoords(MapTaskEntity task) {
    if (!_taskIsCreator(task)) {
      return (lat: task.latitude, lon: task.longitude);
    }
    const dLat = 0.00028;
    const dLon = 0.00014;
    return (lat: task.latitude + dLat, lon: task.longitude + dLon);
  }

  Uint8List _bytesForVariant(int v) {
    switch (v) {
      case 1:
        return _imgOtherSel!;
      case 2:
        return _imgCreator!;
      case 3:
        return _imgCreatorSel!;
      case 0:
      default:
        return _imgOther!;
    }
  }

  /// Треугольник вниз (180°), скругление ~3px за счёт strokeJoin, обводка 2px, вертикальный градиент.
  Future<Uint8List> _createTriangleMarkerImage({
    required bool isCreator,
    required bool isSelected,
  }) async {
    var bw = _figmaTriW * (isCreator ? _creatorSizeBoost : 1.0);
    var bh = _figmaTriH * (isCreator ? _creatorSizeBoost : 1.0);
    const pad = 8.0;
    final w = bw + pad * 2;
    final h = bh + pad * 2;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final bounds = Rect.fromLTWH(pad, pad, bw, bh);

    final path = Path()
      ..moveTo(bounds.left + bw / 2, bounds.bottom)
      ..lineTo(bounds.left, bounds.top)
      ..lineTo(bounds.right, bounds.top)
      ..close();

    final gradientColors = isCreator
        ? const <Color>[
            Color(0xFFE8EAED),
            Color(0xFF6A8EC4),
            Color(0xFF3D5F8A),
          ]
        : const <Color>[
            // Нейтральное «серебро» без синевы (чужие заявки).
            Color(0xFFF3F4F6),
            Color(0xFFD9DEE5),
            Color(0xFFB4BCC6),
          ];

    final fill = Paint()
      ..shader = ui.Gradient.linear(
        Offset(bounds.left, bounds.top),
        Offset(bounds.left, bounds.bottom),
        gradientColors,
        const [0.0, 0.55, 1.0],
      );
    canvas.drawPath(path, fill);

    // Обводка (Figma ~2px). Для чужих задач - серебряная, без "неон" свечения.
    final border = Paint()
      ..color = isCreator
          ? (isSelected ? const Color(0xFFFFFFFF) : const Color(0xFFF5F5F5))
          : (isSelected
              ? const Color(0xFFD0D6DE)
              : const Color(0xFFB0B8C4))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, border);

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.ceil(), h.ceil());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
