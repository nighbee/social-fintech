import 'dart:async';

import 'package:app/src/core/utils/loggers/log.dart';
import 'package:flutter/foundation.dart';

import 'src/app/application.dart';
import 'src/app/runner.dart';

void main(List<String> args) {
  final flavor = kReleaseMode ? AppFlavor.production : AppFlavor.development;
  mainWithFlavor(flavor, args);
}

Future<void> mainWithFlavor(AppFlavor flavor, List<String> args) async {
  // Log startup information
  debugPrint('=== BrightBund App Starting ===');
  debugPrint('Flavor: ${flavor.name}');
  debugPrint('==========================');

  runZonedGuarded(
    () async {
      await Runner().initializeAndRun(flavor: flavor, args: args);
    },
    (error, stack) {
      // Only use Log if it's available (after DI is configured)
      // Otherwise, use debugPrint as a fallback
      try {
        Log.e(error.toString());
      } catch (e) {
        debugPrint('Error before DI initialization: $error');
        debugPrint('Stack trace: $stack');
      }
    },
  );
}
