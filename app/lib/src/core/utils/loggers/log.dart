import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../service/injectable/injectable_service.dart';

part 'debug.dart';
part 'error.dart';
part 'info.dart';

class Log {
  static Talker? _talker;

  static void _initializeTalker() {
    if (_talker == null) {
      try {
        _talker = getIt<Talker>();
      } catch (e) {
        // Talker not registered yet, use a fallback
        _talker = TalkerFlutter.init();
      }
    }
  }

  static Talker get _talkerInstance {
    _initializeTalker();
    return _talker!;
  }

  /// Call this method after DI is configured to ensure Log uses the registered Talker instance
  static void configureWithTalker(Talker talker) {
    _talker = talker;
  }

  static void info(String title, Object message) =>
      _talkerInstance.logCustom(_InfoWithTitle(title, message.toString()));
  static void i(Object message) =>
      _talkerInstance.logCustom(_Info(message.toString()));

  static void error(String title, Object message) =>
      _talkerInstance.logCustom(_ErrorWithTitle(title, message.toString()));
  static void e(Object message) =>
      _talkerInstance.logCustom(_Error(message.toString()));

  static void debug(String title, Object message) =>
      kDebugMode
          ? _talkerInstance.logCustom(
            _DebugWithTitle(title, message.toString()),
          )
          : null;
  static void d(Object message) =>
      kDebugMode ? _talkerInstance.logCustom(_Debug(message.toString())) : null;
}
