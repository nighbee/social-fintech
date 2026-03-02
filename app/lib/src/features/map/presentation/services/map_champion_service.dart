import 'dart:typed_data';
import 'dart:ui';

import 'package:app/src/features/auth/domain/entities/user_entity.dart';
import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_region_assignment_entity.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Service for managing champion markers on the map
class MapChampionService {
  MapChampionService();

  PointAnnotationManager? _annotationManager;
  final Map<String, PointAnnotation> _annotations = {};
  final Map<String, String> _annotationIdsToH3Index = {};
  final Map<String, MapChampionEntity> _championsByIndex = {};
  final Map<String, UserEntity> _usersById = {};
  Cancelable? _tapCancelable;
  void Function(MapChampionEntity champion)? _onChampionTap;

  /// Initialize the annotation manager
  Future<void> initialize(
    MapboxMap mapboxMap, {
    void Function(MapChampionEntity champion)? onChampionTap,
  }) async {
    _annotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();
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

    await manager.deleteAll();
    _annotations.clear();
    _annotationIdsToH3Index.clear();
    _championsByIndex.clear();
  }

  /// Dispose the service
  Future<void> dispose() async {
    _tapCancelable?.cancel();
    _tapCancelable = null;
    _onChampionTap = null;
    await clear();
    _annotationManager = null;
  }

  /// Create champion marker image
  Future<Uint8List> _createChampionMarkerImage() async {
    // Create a simple champion badge icon
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    const size = 60.0;
    final center = Offset(size / 2, size / 2);

    // Draw gold circle background
    final bgPaint = Paint()
      ..color = const Color(0xFFFFD700) // Gold color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size / 2, bgPaint);

    // Draw crown icon (simplified)
    final crownPaint = Paint()
      ..color = const Color(0xFF8B6914) // Darker gold
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0;

    final path = Path();
    // Crown base
    path.moveTo(center.dx - 15, center.dy + 5);
    path.lineTo(center.dx + 15, center.dy + 5);
    // Crown points
    path.lineTo(center.dx + 15, center.dy - 5);
    path.lineTo(center.dx + 8, center.dy);
    path.lineTo(center.dx, center.dy - 12);
    path.lineTo(center.dx - 8, center.dy);
    path.lineTo(center.dx - 15, center.dy - 5);
    path.close();

    canvas.drawPath(path, crownPaint);

    // Draw score circle
    final scorePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2 + 8), 10, scorePaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
