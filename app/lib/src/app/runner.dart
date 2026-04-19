import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'application.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/storage/app_storage/storage_service.dart';

class Runner {
  Future<void> initializeAndRun({
    required AppFlavor flavor,
    required List<String> args,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    await _initializeFirebase();
    
    await KeyValueStorageImpl().initialize();

    await configureDependencies();
    debugPrint('Dependencies configured successfully');

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    MainApp(flavor: flavor).run();
  }

  Future<void> _initializeFirebase() async {
    if (!kIsWeb) {
      await _initializeMobileFirebase();
      return;
    }

    try {
      const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
      const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
      const messagingSenderId = String.fromEnvironment(
        'FIREBASE_WEB_MESSAGING_SENDER_ID',
      );
      const projectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
      const authDomain = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
      const storageBucket = String.fromEnvironment(
        'FIREBASE_WEB_STORAGE_BUCKET',
      );
      const measurementId = String.fromEnvironment(
        'FIREBASE_WEB_MEASUREMENT_ID',
      );

      if (apiKey.isNotEmpty &&
          appId.isNotEmpty &&
          messagingSenderId.isNotEmpty &&
          projectId.isNotEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: apiKey,
            appId: appId,
            messagingSenderId: messagingSenderId,
            projectId: projectId,
            authDomain: authDomain.isEmpty ? null : authDomain,
            storageBucket: storageBucket.isEmpty ? null : storageBucket,
            measurementId: measurementId.isEmpty ? null : measurementId,
          ),
        );
        debugPrint('Firebase initialized successfully (web, dart-define)');
        return;
      }

      debugPrint(
        'Firebase web options are missing. Skipping Firebase init for web. '
        'Provide FIREBASE_WEB_* via --dart-define or generate firebase_options.dart.',
      );
    } catch (e) {
      debugPrint('Firebase initialization skipped: $e');
    }
  }

  Future<void> _initializeMobileFirebase() async {
    try {
      await Firebase.initializeApp();
      debugPrint('Firebase initialized successfully');
      return;
    } catch (e) {
      debugPrint('Firebase default init failed on mobile, trying fallback: $e');
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyD0n3YjMtKPAGAR_kprsMMYYl-Wt-vrlK4',
          appId: '1:493875542368:ios:4b7c0c7d67bb972d868605',
          messagingSenderId: '493875542368',
          projectId: 'smsbb-6e583',
          storageBucket: 'smsbb-6e583.firebasestorage.app',
          iosBundleId: 'com.brightbund.bb',
        ),
      );
      debugPrint('Firebase initialized successfully (iOS fallback options)');
      return;
    }

    throw StateError(
      'Firebase initialization failed on mobile and no fallback options are configured for this platform.',
    );
  }
}
