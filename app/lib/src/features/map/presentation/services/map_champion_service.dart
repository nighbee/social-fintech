import 'dart:ui';

import 'package:app/src/features/auth/domain/entities/user_entity.dart';
import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_region_assignment_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Service for managing champion markers on the map
class MapChampionService {
  MapChampionService();
  static const int _managerInitAttempts = 3;

  PointAnnotationManager? _annotationManager;
  final Map<String, PointAnnotation> _annotations = {};
  final Map<String, String> _annotationIdsToH3Index = {};
  final Map<String, MapChampionEntity> _championsByIndex = {};
  final Map<String, UserEntity> _usersById = {};
  Cancelable? _tapCancelable;
  void Function(MapChampionEntity champion)? _onChampionTap;
  int _lifecycleToken = 0;

  /// Initialize the annotation manager
  Future<void> initialize(
    MapboxMap mapboxMap, {
    void Function(MapChampionEntity champion)? onChampionTap,
  }) async {
    final token = ++_lifecycleToken;
    await dispose(invalidateToken: false);
    if (!_isTokenActive(token)) {
      return;
    }
    try {
      final manager = await _createManagerWithRetry(
        mapboxMap,
        token: token,
      );
      if (manager == null || !_isTokenActive(token)) {
        return;
      }
      _annotationManager = manager;
      _onChampionTap = onChampionTap;

      _tapCancelable?.cancel();
      _tapCancelable = _annotationManager?.tapEvents(
        onTap: (annotation) {
          final h3Index = _annotationIdsToH3Index[annotation.id];
          if (h3Index == null) {
            return;
          }
          final champion = _championsByIndex[h3Index];
          if (champion == null) {
            return;
          }
          _onChampionTap?.call(champion);
        },
      );
    } on PlatformException catch (error) {
      if (error.code == 'channel-error') {
        await dispose(invalidateToken: false);
        return;
      }
      rethrow;
    }
  }

  /// Update champions on the map
  Future<void> updateChampions(
    List<MapChampionEntity> champions,
    MapRegionAssignmentEntity assignedRegion,
  ) async {
    final manager = _annotationManager;
    if (manager == null) {
      return;
    }

    // Build new champions map
    final newChampionsMap = <String, MapChampionEntity>{};
    for (final champion in champions) {
      newChampionsMap[champion.h3Index] = champion;
    }

    // Remove old annotations that are no longer needed
    final toRemove = <String>[];
    for (final entry in _championsByIndex.entries) {
      if (!newChampionsMap.containsKey(entry.key)) {
        toRemove.add(entry.key);
      }
    }

    for (final h3Index in toRemove) {
      final annotation = _annotations.remove(h3Index);
      if (annotation != null) {
        await manager.delete(annotation);
        _annotationIdsToH3Index.remove(annotation.id);
      }
      _championsByIndex.remove(h3Index);
    }

    // Add or update champions with mock coordinates for testing
    // TODO: Replace with actual coordinates from backend or user profiles
    for (final champion in champions) {
      if (!_annotations.containsKey(champion.h3Index)) {
        // Create mock coordinates based on H3 index hash
        final mockCoords = _getMockCoordinates(champion.h3Index);
        await _addChampionWithCoords(manager, champion, mockCoords);
      }
    }
  }

  /// Get mock coordinates for testing (based on H3 index hash)
  ({double lat, double lng}) _getMockCoordinates(String h3Index) {
    // Create deterministic mock coordinates based on H3 index
    // Taraz, Kazakhstan coordinates: 45.1704, 69.5165
    final hash = h3Index.hashCode;
    final lat = 45.1704 + (hash % 1000) / 10000; // Taraz area
    final lng = 69.5165 + (hash % 1000) / 10000;
    return (lat: lat, lng: lng);
  }

  /// Add champion with specific coordinates
  Future<void> _addChampionWithCoords(
    PointAnnotationManager manager,
    MapChampionEntity champion,
    ({double lat, double lng}) coords,
  ) async {
    final pointAnnotationOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(coords.lng, coords.lat)),
      image: await _createChampionMarkerImage(),
      iconAnchor: IconAnchor.BOTTOM,
    );

    final pointAnnotation = await manager.create(pointAnnotationOptions);
    _annotations[champion.h3Index] = pointAnnotation;
    _annotationIdsToH3Index[pointAnnotation.id] = champion.h3Index;
    _championsByIndex[champion.h3Index] = champion;
  }

  /// Update user profiles for champions (reserved for future use)
  Future<void> updateChampionUsers(List<UserEntity> users) async {
    // Store users by ID for future use when profiles have coordinates
    for (final user in users) {
      _usersById[user.id] = user;
    }
  }

  /// Clear all champion markers
  Future<void> clear() async {
    final manager = _annotationManager;
    if (manager == null) {
      return;
    }

    await _deleteAllSafely(manager);
    _annotations.clear();
    _annotationIdsToH3Index.clear();
    _championsByIndex.clear();
  }

  /// Dispose the service
  Future<void> dispose({bool invalidateToken = true}) async {
    if (invalidateToken) {
      _lifecycleToken++;
    }
    _tapCancelable?.cancel();
    _tapCancelable = null;
    _onChampionTap = null;
    await clear();
    _annotationManager = null;
  }

  bool _isTokenActive(int token) => token == _lifecycleToken;

  Future<PointAnnotationManager?> _createManagerWithRetry(
    MapboxMap mapboxMap, {
    required int token,
  }) async {
    for (var attempt = 0; attempt < _managerInitAttempts; attempt++) {
      if (!_isTokenActive(token)) {
        return null;
      }
      try {
        return await mapboxMap.annotations.createPointAnnotationManager();
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

  /// Figma: 86×86 circle, 2px border rgba(206,165,72), shadow 0/0/4 gold.
  Future<Uint8List> _createChampionMarkerImage() async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    const gold = Color(0xFFCEA548);
    const circleSize = 86.0;
    const strokeW = 2.0;
    const shadowBlur = 4.0;
    const pad = shadowBlur + 2.0;
    const width = circleSize + pad * 2;
    const circleCx = width / 2;
    const circleCy = pad + circleSize / 2;
    const fillRadius = 41.0;

    final circleRect = Rect.fromCircle(
      center: Offset(circleCx, circleCy),
      radius: circleSize / 2,
    );

    final glowPaint = Paint()
      ..color = gold.withValues(alpha: 0.42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, shadowBlur);
    canvas.drawCircle(Offset(circleCx, circleCy), circleSize / 2, glowPaint);

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF3D4F66),
          Color(0xFF2A3544),
        ],
      ).createShader(circleRect);
    canvas.drawCircle(Offset(circleCx, circleCy), fillRadius, fillPaint);

    final personPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(circleCx, circleCy - 10),
      9.0,
      personPaint,
    );
    final bodyPath = Path()
      ..moveTo(circleCx - 17, circleCy + 14)
      ..quadraticBezierTo(
        circleCx,
        circleCy - 2,
        circleCx + 17,
        circleCy + 14,
      )
      ..lineTo(circleCx + 17, circleCy + 22)
      ..lineTo(circleCx - 17, circleCy + 22)
      ..close();
    canvas.drawPath(bodyPath, personPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..color = gold;
    canvas.drawCircle(
      Offset(circleCx, circleCy),
      fillRadius + strokeW / 2,
      ringPaint,
    );

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Champion',
        style: TextStyle(
          color: gold,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    final labelY = circleCy + fillRadius + 10;
    textPainter.paint(
      canvas,
      Offset((width - textPainter.width) / 2, labelY),
    );

    final height = labelY + textPainter.height + 8;
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.ceil(), height.ceil());
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
