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

  final IAppStorage _storage;
  EnvironmentType? _currentEnvironment;

  EnvironmentType get currentEnvironment =>
      _currentEnvironment ??= _loadEnvironment();

  bool get isDevelopment => currentEnvironment == EnvironmentType.dev;
  String get baseUrl => currentEnvironment.url;

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
      _updateApiClient(env.url);
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
}
