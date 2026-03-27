import 'package:flutter/foundation.dart';

import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/storage/app_storage/storage_service.dart';
import 'package:app/src/core/utils/loggers/log.dart';
import 'package:injectable/injectable.dart';

enum EnvironmentType {
  dev('dev', EndPoints.baseUrlDev),
  prod('prod', EndPoints.baseUrl);

  const EnvironmentType(this.name, this.url);
  final String name;
  final String url;

  static EnvironmentType fromName(String name) {
    for (final env in values) {
      if (env.name == name) {
        return env;
      }
    }
    return EnvironmentType.prod;
  }
}

@LazySingleton()
class EnvironmentManager {
  EnvironmentManager(this._storage);
  static const String _devBaseUrlOverride = String.fromEnvironment(
    'DEV_BASE_URL',
    defaultValue: '',
  );

  final IAppStorage _storage;
  EnvironmentType? _currentEnvironment;

  EnvironmentType get currentEnvironment =>
      _currentEnvironment ??= _loadEnvironment();

  bool get isDevelopment => currentEnvironment == EnvironmentType.dev;
  String get baseUrl {
    if (kIsWeb && currentEnvironment == EnvironmentType.dev) {
      return EndPoints.baseUrl;
    }
    if (currentEnvironment == EnvironmentType.dev &&
        _devBaseUrlOverride.trim().isNotEmpty) {
      return _devBaseUrlOverride.trim();
    }
    if (currentEnvironment == EnvironmentType.dev) {
      return _defaultDevBaseUrl;
    }
    return currentEnvironment.url;
  }

  EnvironmentType _loadEnvironment() {
    try {
      final String defaultEnv = kReleaseMode ? 'prod' : 'dev';
      final String envName = _storage.getEnvironment(defaultEnv);
      return EnvironmentType.fromName(envName);
    } catch (e) {
      Log.e('Failed to load environment: $e');
      return EnvironmentType.prod;
    }
  }

  Future<void> switchEnvironment(EnvironmentType env) async {
    if (currentEnvironment == env) return;

    try {
      Log.i('Switching to environment: ${env.name}');
      await _storage.setEnvironment(env.name);
      _currentEnvironment = env;
      _updateApiClient(_resolveBaseUrl(env));
    } catch (e) {
      Log.e('Failed to switch environment: $e');
      rethrow;
    }
  }

  void _updateApiClient(String url) {
    if (getIt.isRegistered<RestClient>(instanceName: 'DioClient')) {
      getIt<RestClient>(instanceName: 'DioClient').setBaseUrl(ipAddress: url);
    }
  }

  String _resolveBaseUrl(EnvironmentType env) {
    if (kIsWeb && env == EnvironmentType.dev) {
      return EndPoints.baseUrl;
    }
    if (env == EnvironmentType.dev && _devBaseUrlOverride.trim().isNotEmpty) {
      return _devBaseUrlOverride.trim();
    }
    if (env == EnvironmentType.dev) {
      return _defaultDevBaseUrl;
    }
    return env.url;
  }

  String get _defaultDevBaseUrl {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => EndPoints.baseUrlDev,
      _ => EndPoints.baseUrl,
    };
  }
}
