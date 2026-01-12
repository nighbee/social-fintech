import 'dart:async';

import 'package:flutter/foundation.dart';

import 'src/app/application.dart';
import 'src/app/runner.dart';

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
      debugPrint('Error: $error');
      debugPrint('Stack trace: $stack');
    },
  );
}
