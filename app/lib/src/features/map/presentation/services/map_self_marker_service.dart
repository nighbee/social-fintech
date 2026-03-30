import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/src/features/map/presentation/services/map_location_settings.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Точка на карте «текущий пользователь» (не чемпион): пин с аватаром по GPS.
class MapSelfMarkerService {
  MapSelfMarkerService();
  static const int _managerInitAttempts = 3;
  static const double _sortKey = 20000;
  static const double _pinMapIconSize = 1.14;

  double _markerSizeMultiplier = 1.0;

  PointAnnotationManager? _annotationManager;
  PointAnnotation? _annotation;
  StreamSubscription<geo.Position>? _positionSub;
  Uint8List? _pinBytes;
  String? _pinBytesAvatarKey;

  int _lastLatKey = 0;
  int _lastLngKey = 0;
  double? _lastLatitude;
  double? _lastLongitude;
  int _lifecycleToken = 0;

  /// Очередь обновлений: иначе при частом GPS несколько `create` успевают до присвоения `_annotation` — дубли пинов.
  Future<void> _updateChain = Future<void>.value();

  Future<void> initialize(MapboxMap mapboxMap) async {
    await _updateChain;
    _lifecycleToken++;
    final token = _lifecycleToken;
    await _disposeAnnotationLayer(invalidateToken: false);
    if (!_isTokenActive(token)) {
      return;
    }
    try {
      final manager = await _createManagerWithRetry(mapboxMap, token: token);
      if (manager == null || !_isTokenActive(token)) {
        return;
      }
      _annotationManager = manager;
      await manager.setIconAllowOverlap(true);
      await manager.setIconIgnorePlacement(true);
    } on PlatformException catch (error) {
      if (error.code == 'channel-error') {
        await _disposeAnnotationLayer(invalidateToken: false);
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
    final existing = _annotation;
    final manager = _annotationManager;
    if (existing == null || manager == null) {
      return;
    }
    existing.iconSize = _pinMapIconSize * _markerSizeMultiplier;
    try {
      await manager.update(existing);
    } on PlatformException catch (error) {
      if (error.code != 'channel-error') {
        rethrow;
      }
    }
  }

  /// [onPosition] — координаты устройства (для запросов «рядом», регион и т.д.).
  Future<void> startLocationUpdates(
    String? Function() resolveAvatarUrl, {
    void Function(double latitude, double longitude)? onPosition,
  }) async {
    await _positionSub?.cancel();
    _positionSub = null;

    final enabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return;
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      return;
    }

    void handlePosition(geo.Position p) {
      onPosition?.call(p.latitude, p.longitude);
      unawaited(
        updatePosition(
          p.latitude,
          p.longitude,
          avatarUrl: resolveAvatarUrl(),
        ),
      );
    }

    final last = await MapGeo.getBestCurrentPosition();
    if (last != null) {
      handlePosition(last);
    }

    _positionSub = geo.Geolocator.getPositionStream(
      locationSettings: MapGeo.streamSettings(),
    ).listen(handlePosition);
  }

  Future<void> updatePosition(
    double latitude,
    double longitude, {
    String? avatarUrl,
  }) async {
    final previous = _updateChain;
    final done = Completer<void>();
    _updateChain = done.future;
    await previous;
    try {
      await _updatePositionSerialized(
        latitude,
        longitude,
        avatarUrl: avatarUrl,
      );
    } finally {
      done.complete();
    }
  }

  Future<void> _updatePositionSerialized(
    double latitude,
    double longitude, {
    String? avatarUrl,
  }) async {
    final token = _lifecycleToken;
    var manager = _annotationManager;
    if (manager == null || !_isTokenActive(token)) {
      return;
    }

    final latKey = (latitude * 1e6).round();
    final lngKey = (longitude * 1e6).round();
    final key = avatarUrl ?? '';
    final samePoint = _lastLatKey == latKey &&
        _lastLngKey == lngKey &&
        _pinBytesAvatarKey == key;
    if (!samePoint || _pinBytes == null) {
      if (_pinBytes == null || _pinBytesAvatarKey != key) {
        _pinBytes = await _buildUserPinPng(avatarUrl);
        if (!_isTokenActive(token)) {
          return;
        }
        _pinBytesAvatarKey = key;
      }
      _lastLatKey = latKey;
      _lastLngKey = lngKey;
      _lastLatitude = latitude;
      _lastLongitude = longitude;
    }

    manager = _annotationManager;
    if (manager == null || !_isTokenActive(token)) {
      return;
    }

    final point = Point(coordinates: Position(longitude, latitude));
    final image = _pinBytes;
    if (image == null) {
      return;
    }

    var existing = _annotation;
    if (existing == null) {
      try {
        await manager.deleteAll();
      } on PlatformException catch (error) {
        if (error.code != 'channel-error') {
          rethrow;
        }
      }
      if (!_isTokenActive(token)) {
        return;
      }
      manager = _annotationManager;
      if (manager == null) {
        return;
      }
      final created = await manager.create(
        PointAnnotationOptions(
          geometry: point,
          image: image,
          iconAnchor: IconAnchor.BOTTOM,
          symbolSortKey: _sortKey,
          iconSize: _pinMapIconSize * _markerSizeMultiplier,
        ),
      );
      if (!_isTokenActive(token)) {
        try {
          await manager.delete(created);
        } on PlatformException catch (error) {
          if (error.code != 'channel-error') {
            rethrow;
          }
        }
        return;
      }
      _annotation = created;
    } else {
      existing
        ..geometry = point
        ..image = image
        ..iconAnchor = IconAnchor.BOTTOM
        ..symbolSortKey = _sortKey
        ..iconSize = _pinMapIconSize * _markerSizeMultiplier;
      try {
        await manager.update(existing);
      } on PlatformException catch (error) {
        if (error.code != 'channel-error') {
          rethrow;
        }
      }
    }
  }

  Future<void> dispose({bool invalidateToken = true}) async {
    await _updateChain;
    if (invalidateToken) {
      _lifecycleToken++;
    }
    await _positionSub?.cancel();
    _positionSub = null;
    await _disposeAnnotationLayer(invalidateToken: false);
    _pinBytes = null;
    _pinBytesAvatarKey = null;
    _lastLatKey = 0;
    _lastLngKey = 0;
    _lastLatitude = null;
    _lastLongitude = null;
    _markerSizeMultiplier = 1.0;
  }

  /// Перерисовать пин (например, загрузился `avatarUrl` из профиля).
  Future<void> reloadAppearance({String? avatarUrl}) async {
    final lat = _lastLatitude;
    final lng = _lastLongitude;
    if (lat == null || lng == null) {
      return;
    }
    _pinBytes = null;
    _pinBytesAvatarKey = null;
    await updatePosition(lat, lng, avatarUrl: avatarUrl);
  }

  bool _isTokenActive(int token) => token == _lifecycleToken;

  Future<void> _disposeAnnotationLayer({required bool invalidateToken}) async {
    final manager = _annotationManager;
    _annotationManager = null;
    final ann = _annotation;
    _annotation = null;
    if (manager != null && ann != null) {
      try {
        await manager.delete(ann);
      } on PlatformException catch (error) {
        if (error.code != 'channel-error') {
          rethrow;
        }
      }
    }
    if (invalidateToken) {
      _lifecycleToken++;
    }
  }

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
}

Future<ui.Image?> _tryDecodeAvatar(String url) async {
  if (url.isEmpty) {
    return null;
  }
  try {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return null;
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != 200) {
      return null;
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    final chunks = builder.takeBytes();
    final codec = await ui.instantiateImageCodec(chunks);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}

Future<Uint8List> _buildUserPinPng(String? avatarUrl) async {
  final avatar = await _tryDecodeAvatar(avatarUrl ?? '');
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Figma: круг «я» 80×80, opacity 1.
    const scale = 1.08;
    final headRadius = 40.0 * scale;
    final w = 96.0 * scale;
    final centerX = w / 2;
    final headCy = 48.0 * scale;
    final tipY = 118.0 * scale;
    final height = tipY + 6.0;

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(centerX, headCy + 2), headRadius + 4, shadow);

    final pinFill = Paint()..color = Colors.white;
    final pinPath = Path()
      ..moveTo(centerX - headRadius - 3, headCy + headRadius * 0.32)
      ..arcTo(
        Rect.fromCircle(
          center: Offset(centerX, headCy),
          radius: headRadius + 3,
        ),
        math.pi * 0.65,
        math.pi * 1.7,
        false,
      )
      ..lineTo(centerX, tipY)
      ..close();
    canvas.drawPath(pinPath, pinFill);

    final borderPaint = Paint()
      ..color = const Color(0xFFE8E8EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(pinPath, borderPaint);

    final clipOval = Path()
      ..addOval(Rect.fromCircle(center: Offset(centerX, headCy), radius: headRadius));
    canvas.save();
    canvas.clipPath(clipOval);

    final avatarSize = headRadius * 2;
    if (avatar != null) {
      final dst = Rect.fromLTWH(
        centerX - headRadius,
        headCy - headRadius,
        avatarSize,
        avatarSize,
      );
      canvas.drawImageRect(
        avatar,
        Rect.fromLTWH(
          0,
          0,
          avatar.width.toDouble(),
          avatar.height.toDouble(),
        ),
        dst,
        Paint(),
      );
    } else {
      final placeholder = Paint()..color = const Color(0xFFD7DBE4);
      canvas.drawCircle(Offset(centerX, headCy), headRadius, placeholder);
      final person = Paint()..color = Colors.white.withValues(alpha: 0.95);
      canvas.drawCircle(Offset(centerX, headCy - 10), 12, person);
      final body = Path()
        ..moveTo(centerX - 22, headCy + 26)
        ..quadraticBezierTo(centerX, headCy + 2, centerX + 22, headCy + 26)
        ..lineTo(centerX + 22, headCy + 36)
        ..lineTo(centerX - 22, headCy + 36)
        ..close();
      canvas.drawPath(body, person);
    }
    canvas.restore();

    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(centerX, headCy), headRadius, ring);

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.ceil(), height.ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    avatar?.dispose();
  }
}
