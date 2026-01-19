import 'package:flutter/foundation.dart';

import 'package:app/src/core/service/storage/app_storage/storage_service.dart';
import 'package:app/src/core/utils/loggers/log.dart';

enum EnvironmentType {
  dev('dev'),
  prod('prod');

  const EnvironmentType(this.name);
  final String name;

  static EnvironmentType fromName(String name) {
    for (final env in values) {
      if (env.name == name) {
        return env;
      }
    }
    return EnvironmentType.prod;
  }
}

class EnvironmentManager {
  EnvironmentManager(this._storage);

  final IAppStorage _storage;
  EnvironmentType? _currentEnvironment;

  EnvironmentType get currentEnvironment =>
      _currentEnvironment ??= _loadEnvironment();

  bool get isDevelopment => currentEnvironment == EnvironmentType.dev;

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
    } catch (e) {
      Log.e('Failed to switch environment: $e');
      rethrow;
    }
  }
}
