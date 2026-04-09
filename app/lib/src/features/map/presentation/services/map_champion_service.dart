import 'dart:async';
import 'dart:ui';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:app/src/features/auth/domain/entities/user_entity.dart';
import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_region_assignment_entity.dart';
import 'package:app/src/features/map/presentation/services/map_avatar_resolver_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:h3_flutter/h3_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Service for managing champion markers on the map
class MapChampionService {
  MapChampionService();
  static const int _managerInitAttempts = 3;
  static const double _markerIconScale = 1.34;
  static const double _minChampionSizeMultiplier = 0.9;

  double _markerSizeMultiplier = 1.0;

  double get _effectiveSizeMultiplier =>
      _markerSizeMultiplier < _minChampionSizeMultiplier
          ? _minChampionSizeMultiplier
          : _markerSizeMultiplier;

  final H3 _h3 = const H3Factory().load();
  PointAnnotationManager? _annotationManager;
  final Map<String, PointAnnotation> _annotations = {};
  final Map<String, String> _annotationIdsToH3Index = {};
  final Map<String, MapChampionEntity> _championsByIndex = {};
  final Map<String, String> _markerSignatureByH3 = {};
  final Map<String, Uint8List> _markerImageCache = {};
  final Map<String, ({double lat, double lng})> _fallbackAnchorByH3 = {};
  final Map<String, UserEntity> _usersById = {};
  bool _h3RuntimeUnavailable = false;
  Future<void> _updateChain = Future<void>.value();
  Cancelable? _tapCancelable;
  void Function(MapChampionEntity champion)? _onChampionTap;
  int _lifecycleToken = 0;

  bool get isH3RuntimeUnavailable => _h3RuntimeUnavailable;

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
      if (_isRecoverableAnnotationError(error)) {
        await dispose(invalidateToken: false);
        return;
      }
      rethrow;
    }
  }

  Future<void> applyMarkerSizeMultiplier(double multiplier) async {
    if ((multiplier - _markerSizeMultiplier).abs() < 0.008) {
      return;
    }
    _markerSizeMultiplier = multiplier;
    final manager = _annotationManager;
    if (manager == null) {
      return;
    }
    final annotationsSnapshot = _annotations.values.toList(growable: false);
    for (final ann in annotationsSnapshot) {
      ann.iconSize = _markerIconScale * _effectiveSizeMultiplier;
      try {
        await manager.update(ann);
      } on PlatformException catch (error) {
        if (!_isRecoverableAnnotationError(error)) {
          rethrow;
        }
      }
    }
  }

  /// Update champions on the map
  Future<void> updateChampions(
    List<MapChampionEntity> champions,
    MapRegionAssignmentEntity assignedRegion,
    {
    double? fallbackLatitude,
    double? fallbackLongitude,
  }
  ) async {
    final previous = _updateChain;
    final done = Completer<void>();
    _updateChain = done.future;
    await previous;
    try {
      await _updateChampionsSerialized(
        champions,
        assignedRegion,
        fallbackLatitude: fallbackLatitude,
        fallbackLongitude: fallbackLongitude,
      );
    } finally {
      done.complete();
    }
  }

  Future<void> _updateChampionsSerialized(
    List<MapChampionEntity> champions,
    MapRegionAssignmentEntity assignedRegion, {
    double? fallbackLatitude,
    double? fallbackLongitude,
  }) async {
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
        try {
          await manager.delete(annotation);
        } on PlatformException catch (error) {
          if (_isRecoverableAnnotationError(error)) {
            _annotationIdsToH3Index.remove(annotation.id);
            _championsByIndex.remove(h3Index);
            continue;
          }
          rethrow;
        }
        _annotationIdsToH3Index.remove(annotation.id);
      }
      _championsByIndex.remove(h3Index);
      _markerSignatureByH3.remove(h3Index);
      _fallbackAnchorByH3.remove(h3Index);
    }

    for (final champion in champions) {
      final coords = _coordsForChampion(
        champion,
        assignedRegion: assignedRegion,
        fallbackLatitude: fallbackLatitude,
        fallbackLongitude: fallbackLongitude,
      );
      if (coords == null) {
        debugPrint('[MapChampionService] invalid h3: ${champion.h3Index}');
        continue;
      }
      final signature = _markerSignature(champion);
      final existing = _annotations[champion.h3Index];
      if (existing != null) {
        final knownSignature = _markerSignatureByH3[champion.h3Index];
        if (knownSignature != signature) {
          try {
            await manager.delete(existing);
          } on PlatformException catch (error) {
            if (!_isRecoverableAnnotationError(error)) {
              rethrow;
            }
          }
          _annotations.remove(champion.h3Index);
          _annotationIdsToH3Index.remove(existing.id);

          try {
            final markerImage = await _buildChampionMarkerImage(champion);
            await _addChampionWithCoords(manager, champion, coords, markerImage);
            _markerSignatureByH3[champion.h3Index] = signature;
          } on PlatformException catch (error) {
            if (_isRecoverableAnnotationError(error)) {
              continue;
            }
            rethrow;
          }
          continue;
        }

        existing
          ..geometry = Point(coordinates: Position(coords.lng, coords.lat))
          ..iconAnchor = IconAnchor.BOTTOM
          ..symbolSortKey = 8000
          ..iconSize = _markerIconScale * _effectiveSizeMultiplier;
        try {
          await manager.update(existing);
        } on PlatformException catch (error) {
          if (_isRecoverableAnnotationError(error)) {
            _annotations.remove(champion.h3Index);
            _annotationIdsToH3Index.remove(existing.id);
            final markerImage = await _buildChampionMarkerImage(champion);
            await _addChampionWithCoords(manager, champion, coords, markerImage);
            continue;
          }
          rethrow;
        }
        _championsByIndex[champion.h3Index] = champion;
        _markerSignatureByH3[champion.h3Index] = signature;
      } else {
        try {
          final markerImage = await _buildChampionMarkerImage(champion);
          await _addChampionWithCoords(manager, champion, coords, markerImage);
          _markerSignatureByH3[champion.h3Index] = signature;
        } on PlatformException catch (error) {
          if (_isRecoverableAnnotationError(error)) {
            continue;
          }
          rethrow;
        }
      }
    }
  }

  /// Центр H3-ячейки (как на бэкенде в `centerOfH3`): координаты пина чемпиона региона.
  ({double lat, double lng})? _cellCenter(String h3Hex) {
    if (_h3RuntimeUnavailable) {
      return null;
    }
    final normalized = h3Hex.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    try {
      final index = BigInt.parse(normalized, radix: 16);
      if (_h3.h3IsValid(index)) {
        final geo = _h3.h3ToGeo(index);
        return (lat: geo.lat, lng: geo.lon);
      }
      // Индекс с другой версии h3-js / другого bindings — иногда h3IsValid ложный, geo всё ещё ок.
      try {
        final geo = _h3.h3ToGeo(index);
        return (lat: geo.lat, lng: geo.lon);
      } catch (error) {
        final message = error.toString();
        if (message.contains('Failed to lookup symbol') ||
            message.contains('symbol not found')) {
          _h3RuntimeUnavailable = true;
        }
        debugPrint(
          '[MapChampionService] h3ToGeo failed for $normalized: $error',
        );
        return null;
      }
    } catch (error) {
      final message = error.toString();
      if (message.contains('Failed to lookup symbol') ||
          message.contains('symbol not found')) {
        _h3RuntimeUnavailable = true;
      }
      debugPrint(
        '[MapChampionService] h3 decode failed for $normalized: $error',
      );
      return null;
    }
  }

  ({double lat, double lng})? _coordsForChampion(
    MapChampionEntity champion, {
    required MapRegionAssignmentEntity assignedRegion,
    required double? fallbackLatitude,
    required double? fallbackLongitude,
  }) {
    final fromApi = _coordsFromApi(champion);
    if (fromApi != null) {
      return fromApi;
    }

    final fromH3 = _cellCenter(champion.h3Index);
    if (fromH3 != null) {
      return fromH3;
    }

    return _fallbackCoordsForChampion(
      champion,
      assignedRegion: assignedRegion,
      fallbackLatitude: fallbackLatitude,
      fallbackLongitude: fallbackLongitude,
    );
  }

  ({double lat, double lng})? _coordsFromApi(MapChampionEntity champion) {
    final lat = champion.centerLat;
    final lng = champion.centerLon;
    if (lat == null || lng == null) {
      return null;
    }
    if (lat.abs() > 90 || lng.abs() > 180) {
      return null;
    }
    return (lat: lat, lng: lng);
  }

  ({double lat, double lng})? _fallbackCoordsForChampion(
    MapChampionEntity champion, {
    required MapRegionAssignmentEntity assignedRegion,
    required double? fallbackLatitude,
    required double? fallbackLongitude,
  }) {
    final lat = fallbackLatitude;
    final lng = fallbackLongitude;
    final existingAnchor = _fallbackAnchorByH3[champion.h3Index];
    if (existingAnchor != null) {
      return existingAnchor;
    }
    if (lat == null || lng == null) {
      return null;
    }

    final isKnownRegionChampion = champion.h3Index == assignedRegion.h3Res5 ||
        champion.h3Index == assignedRegion.h3Res4 ||
        champion.h3Index == assignedRegion.h3Res2;
    if (!isKnownRegionChampion) {
      return null;
    }

    final seed = champion.h3Index.codeUnits.fold<int>(0, (a, b) => a + b);
    final angle = (seed % 360) * (math.pi / 180.0);
    final radiusByResolution = switch (champion.resolution) {
      5 => 0.0012,
      4 => 0.0022,
      _ => 0.0032,
    };

    final anchored = (
      lat: lat + math.cos(angle) * radiusByResolution,
      lng: lng + math.sin(angle) * radiusByResolution,
    );
    _fallbackAnchorByH3[champion.h3Index] = anchored;
    return anchored;
  }

  /// Add champion with specific coordinates
  Future<void> _addChampionWithCoords(
    PointAnnotationManager manager,
    MapChampionEntity champion,
    ({double lat, double lng}) coords,
    Uint8List markerImage,
  ) async {
    final pointAnnotationOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(coords.lng, coords.lat)),
      image: markerImage,
      iconAnchor: IconAnchor.BOTTOM,
      symbolSortKey: 8000,
      iconSize: _markerIconScale * _effectiveSizeMultiplier,
    );

    try {
      final pointAnnotation = await manager.create(pointAnnotationOptions);
      _annotations[champion.h3Index] = pointAnnotation;
      _annotationIdsToH3Index[pointAnnotation.id] = champion.h3Index;
      _championsByIndex[champion.h3Index] = champion;
      _markerSignatureByH3[champion.h3Index] = _markerSignature(champion);
    } on PlatformException catch (error) {
      if (_isRecoverableAnnotationError(error)) {
        return;
      }
      rethrow;
    }
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
    _markerSignatureByH3.clear();
    _fallbackAnchorByH3.clear();
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
    _markerImageCache.clear();
    _updateChain = Future<void>.value();
    _markerSizeMultiplier = 1.0;
  }

  String _markerSignature(MapChampionEntity champion) {
    return '${champion.userId}|${champion.username}|${champion.avatarUrl}';
  }

  Future<Uint8List> _buildChampionMarkerImage(MapChampionEntity champion) async {
    final resolvedAvatarUrl = await MapAvatarResolverService.instance.resolveAvatar(
      fallbackUrl: champion.avatarUrl,
      userId: champion.userId,
      username: champion.username,
    );
    final initials = _initialsForChampion(champion);
    final cacheKey = 'avatar:$resolvedAvatarUrl|initials:$initials';
    final cached = _markerImageCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final image = await _createChampionMarkerImage(
      avatarUrl: resolvedAvatarUrl,
      initials: initials,
    );
    _markerImageCache[cacheKey] = image;
    return image;
  }

  String _initialsForChampion(MapChampionEntity champion) {
    final source = champion.username.trim().isNotEmpty
        ? champion.username.trim()
        : champion.userId.trim();
    if (source.isEmpty) {
      return '?';
    }
    return source.substring(0, 1).toUpperCase();
  }

  Future<ui.Image?> _loadAvatarImage(String avatarUrl) async {
    final uri = Uri.tryParse(avatarUrl.trim());
    if (uri == null) {
      return null;
    }
    try {
      final byteData = await NetworkAssetBundle(uri).load(uri.toString());
      final bytes = byteData.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 220,
        targetHeight: 220,
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
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
      if (_isRecoverableAnnotationError(error)) {
        return;
      }
      rethrow;
    }
  }

  /// Figma: 86×86 circle, 2px border rgba(206,165,72), shadow 0/0/4 gold.
  Future<Uint8List> _createChampionMarkerImage({
    required String avatarUrl,
    required String initials,
  }) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    const gold = Color(0xFFCEA548);
    const circleSize = 86.0 * 1.18;
    const strokeW = 2.0;
    const shadowBlur = 4.0;
    const pad = shadowBlur + 2.0;
    const width = circleSize + pad * 2;
    const circleCx = width / 2;
    const circleCy = pad + circleSize / 2;
    final fillRadius = 41.0 * 1.18;

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

    final avatarImage = avatarUrl.trim().isNotEmpty
        ? await _loadAvatarImage(avatarUrl)
        : null;
    if (avatarImage != null) {
      final dst = Rect.fromCircle(
        center: Offset(circleCx, circleCy),
        radius: fillRadius,
      );
      final src = Rect.fromLTWH(
        0,
        0,
        avatarImage.width.toDouble(),
        avatarImage.height.toDouble(),
      );
      final clipPath = Path()..addOval(dst);
      canvas.save();
      canvas.clipPath(clipPath);
      canvas.drawImageRect(avatarImage, src, dst, Paint());
      canvas.restore();
    } else {
      final initialText = initials.trim().isEmpty ? '?' : initials.trim();
      final initialPainter = TextPainter(
        text: TextSpan(
          text: initialText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: fillRadius * 2);
      initialPainter.paint(
        canvas,
        Offset(
          circleCx - initialPainter.width / 2,
          circleCy - initialPainter.height / 2,
        ),
      );
    }

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
          fontSize: 15,
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
