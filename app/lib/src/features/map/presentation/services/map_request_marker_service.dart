import 'dart:async';
import 'dart:ui' as ui;

import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapRequestMarkerService {
  static const double _defaultIconSize = 1.28;
  static const double _selectedIconSize = 1.44;
  /// Figma: обычный таск (наведён / чужой).
  static const double _figmaTriW = 37.327468872070455;
  static const double _figmaTriH = 32.99999618530286;
  static const double _creatorSizeBoost = 1.14;
  static const double _selectionIndicatorBaseIconSize = 1.0;
  static const double _coordEpsilon = 0.00001;

  double _markerSizeMultiplier = 1.0;

  PointAnnotationManager? _annotationManager;
  PointAnnotationManager? _selectionIndicatorManager;
  Cancelable? _tapCancelable;
  final Map<String, PointAnnotation> _annotationsByTaskId =
      <String, PointAnnotation>{};
  final Map<String, String> _taskIdByAnnotationId = <String, String>{};
  final Map<String, bool> _selectedByTaskId = <String, bool>{};
  final Map<String, MapTaskEntity> _tasksById = <String, MapTaskEntity>{};
  PointAnnotation? _selectionIndicator;

  Uint8List? _imgOther;
  Uint8List? _imgOtherSel;
  Uint8List? _imgCreator;
  Uint8List? _imgCreatorSel;
  final Map<String, int> _variantByTaskId = <String, int>{};

  String? _selectedTaskId;
  void Function(String? selectedTaskId)? _onSelectionChanged;
  int _lifecycleToken = 0;
  static const int _managerInitAttempts = 3;

  bool _isRecoverableAnnotationError(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toLowerCase();
    return code == 'channel-error' ||
        message.contains('unable to establish connection on channel') ||
      message.contains('no manager found with id') ||
      message.contains('no manager found') ||
        message.contains('no manager or annotation found') ||
        message.contains('annotation id') ||
        message.contains('dev.flutter.pigeon.mapbox_maps_flutter');
  }

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
      final entriesSnapshot = _annotationsByTaskId.entries.toList(growable: false);
      for (final entry in entriesSnapshot) {
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
        try {
          await manager.delete(annotation);
        } on PlatformException catch (error) {
          if (!_isRecoverableAnnotationError(error)) {
            rethrow;
          }
        }
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
    _annotationsByTaskId.clear();
    _taskIdByAnnotationId.clear();
    _selectedByTaskId.clear();
    _tasksById.clear();
    _selectedTaskId = null;
    _onSelectionChanged = null;
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

    // Figma alignment: do not show extra tap-selection avatar/icon overlay.
    final existing = _selectionIndicator;
    if (existing != null) {
      try {
        await manager.delete(existing);
      } on PlatformException catch (error) {
        if (!_isRecoverableAnnotationError(error)) {
          rethrow;
        }
      }
      _selectionIndicator = null;
    }
    return;

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
        late final PointAnnotation created;
        try {
          created = await manager.create(
            PointAnnotationOptions(
              geometry: geometry,
              iconAnchor: IconAnchor.BOTTOM,
              image: markerImage,
              iconSize: _taskIconSize(isSelected),
            ),
          );
        } on PlatformException catch (error) {
          if (_isRecoverableAnnotationError(error)) {
            continue;
          }
          rethrow;
        }
        _annotationsByTaskId[task.id] = created;
        _taskIdByAnnotationId[created.id] = task.id;
        _selectedByTaskId[task.id] = isSelected;
        _variantByTaskId[task.id] = variant;
        continue;
      }

      final variantChanged = _variantByTaskId[task.id] != variant;
      if (variantChanged || _selectedByTaskId[task.id] != isSelected) {
        try {
          await manager.delete(existing);
        } on PlatformException catch (error) {
          if (!_isRecoverableAnnotationError(error)) {
            rethrow;
          }
        }
        _taskIdByAnnotationId.remove(existing.id);
        late final PointAnnotation recreated;
        try {
          recreated = await manager.create(
            PointAnnotationOptions(
              geometry: geometry,
              iconAnchor: IconAnchor.BOTTOM,
              image: markerImage,
              iconSize: _taskIconSize(isSelected),
            ),
          );
        } on PlatformException catch (error) {
          if (_isRecoverableAnnotationError(error)) {
            _annotationsByTaskId.remove(task.id);
            _selectedByTaskId.remove(task.id);
            _variantByTaskId.remove(task.id);
            continue;
          }
          rethrow;
        }
        _annotationsByTaskId[task.id] = recreated;
        _taskIdByAnnotationId[recreated.id] = task.id;
        _selectedByTaskId[task.id] = isSelected;
        _variantByTaskId[task.id] = variant;
        continue;
      }

      var needsUpdate = false;
      if (_coordsDiffer(
        existingLat: existing.geometry.coordinates.lat.toDouble(),
        existingLon: existing.geometry.coordinates.lng.toDouble(),
        nextLat: pos.lat,
        nextLon: pos.lon,
      )) {
        existing.geometry = geometry;
        needsUpdate = true;
      }
      final targetSize = _taskIconSize(isSelected);
      if (((existing.iconSize ?? 0) - targetSize).abs() > 0.001) {
        existing.iconSize = targetSize;
        needsUpdate = true;
      }
      if (needsUpdate) {
        try {
          await manager.update(existing);
        } on PlatformException catch (error) {
          if (_isRecoverableAnnotationError(error)) {
            _annotationsByTaskId.remove(task.id);
            _taskIdByAnnotationId.remove(existing.id);
            _selectedByTaskId.remove(task.id);
            _variantByTaskId.remove(task.id);
            continue;
          }
          rethrow;
        }
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

  bool _coordsDiffer({
    required double existingLat,
    required double existingLon,
    required double nextLat,
    required double nextLon,
  }) {
    return (existingLat - nextLat).abs() > _coordEpsilon ||
        (existingLon - nextLon).abs() > _coordEpsilon;
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
            Color(0xFFEAF1FF),
            Color(0xFF6C93CE),
            Color(0xFF3A5886),
          ]
        : const <Color>[
            Color(0xFFEEEEEE),
            Color(0xFFA3A3A3),
            Color(0x33000000),
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
          ? (isSelected ? const Color(0xFFFFFFFF) : const Color(0xFFD9E4F8))
          : (isSelected ? const Color(0xFFFFFFFF) : const Color(0xFFECECEC))
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
