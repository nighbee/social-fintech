import 'dart:async';

import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/features/profile/domain/requests/search_profiles_request.dart';
import 'package:app/src/features/profile/domain/requests/user_id_request.dart';
import 'package:app/src/features/profile/domain/repositories/i_profile_repository.dart';

class MapAvatarResolverService {
  MapAvatarResolverService._();

  static final MapAvatarResolverService instance = MapAvatarResolverService._();

  final Map<String, String> _resolvedByKey = <String, String>{};
  final Map<String, Future<String>> _inFlightByKey = <String, Future<String>>{};
  final Map<String, DateTime> _lastFailedAtByKey = <String, DateTime>{};

  static const Duration _retryAfterFailure = Duration(seconds: 20);

  IProfileRepository? _tryGetProfileRepository() {
    try {
      if (!getIt.isRegistered<IProfileRepository>()) {
        return null;
      }
      return getIt<IProfileRepository>();
    } catch (_) {
      return null;
    }
  }

  Future<String> resolveAvatar({
    required String fallbackUrl,
    String userId = '',
    String username = '',
  }) {
    final normalizedFallback = normalizeAvatarUrl(fallbackUrl);
    if (normalizedFallback.isNotEmpty) {
      return Future<String>.value(normalizedFallback);
    }

    final normalizedUserId = userId.trim();
    final normalizedUsername = username.trim();
    if (normalizedUserId.isEmpty && normalizedUsername.isEmpty) {
      return Future<String>.value('');
    }

    final cacheKey = normalizedUserId.isNotEmpty
        ? 'uid:$normalizedUserId'
        : 'uname:${normalizedUsername.toLowerCase()}';

    final cached = _resolvedByKey[cacheKey];
    if (cached != null) {
      return Future<String>.value(cached);
    }

    final lastFailedAt = _lastFailedAtByKey[cacheKey];
    if (lastFailedAt != null &&
        DateTime.now().difference(lastFailedAt) < _retryAfterFailure) {
      return Future<String>.value('');
    }

    final pending = _inFlightByKey[cacheKey];
    if (pending != null) {
      return pending;
    }

    final future = _resolveFromProfile(
      userId: normalizedUserId,
      username: normalizedUsername,
      cacheKey: cacheKey,
    );
    _inFlightByKey[cacheKey] = future;

    return future.whenComplete(() {
      _inFlightByKey.remove(cacheKey);
    });
  }

  Future<String> _resolveFromProfile({
    required String userId,
    required String username,
    required String cacheKey,
  }) async {
    String resolved = '';
    final profileRepository = _tryGetProfileRepository();
    if (profileRepository == null) {
      _lastFailedAtByKey[cacheKey] = DateTime.now();
      return '';
    }

    if (userId.isNotEmpty) {
      final byIdResult = await profileRepository.getPublicProfile(
        UserIdRequest(userId: userId),
      );
      byIdResult.fold(
        (_) {},
        (profile) {
          resolved = normalizeAvatarUrl(profile.avatarUrl);
        },
      );
    }

    if (resolved.isEmpty && username.isNotEmpty) {
      final byNameResult = await profileRepository.searchProfiles(
        SearchProfilesRequest(query: username, limit: 5, offset: 0),
      );

      byNameResult.fold(
        (_) {},
        (profiles) {
          if (profiles.isEmpty) {
            return;
          }

          final lowered = username.toLowerCase();
          final exact = profiles.where((p) {
            final display = p.displayName.trim().toLowerCase();
            return display == lowered || display == '@$lowered';
          }).toList();

          final selected = exact.isNotEmpty ? exact.first : profiles.first;
          resolved = normalizeAvatarUrl(selected.avatarUrl);
        },
      );
    }

    if (resolved.isNotEmpty) {
      _resolvedByKey[cacheKey] = resolved;
      _lastFailedAtByKey.remove(cacheKey);
    } else {
      _lastFailedAtByKey[cacheKey] = DateTime.now();
    }
    return resolved;
  }

  String normalizeAvatarUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }

    final apiBase = Uri.tryParse(EndPoints.baseUrl);
    final origin = apiBase == null
        ? ''
        : '${apiBase.scheme}://${apiBase.host}${apiBase.hasPort ? ':${apiBase.port}' : ''}';
    if (origin.isEmpty) {
      return trimmed;
    }

    if (trimmed.startsWith('/')) {
      return '$origin$trimmed';
    }

    return '$origin/$trimmed';
  }
}
