import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'application.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';

class Runner {
  Future<void> initializeAndRun({
    required AppFlavor flavor,
    required List<String> args,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    // Configure dependencies (DI) - this initializes Talker
    await configureDependencies();
    debugPrint('Dependencies configured successfully');

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    MainApp(flavor: flavor).run();
  }
}
