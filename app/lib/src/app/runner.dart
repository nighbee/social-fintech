import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import 'application.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/storage/app_storage/storage_service.dart';

class Runner {
  Future<void> initializeAndRun({
    required AppFlavor flavor,
    required List<String> args,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
    
    await KeyValueStorageImpl().initialize();

    await configureDependencies();
    debugPrint('Dependencies configured successfully');

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    MainApp(flavor: flavor).run();
  }
}
