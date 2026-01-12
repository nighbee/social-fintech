import 'package:flutter/foundation.dart';
import 'package:app/src/app/application.dart';
import 'main.dart';

void main(List<String> args) {
  debugPrint('=== Running Production Build ===');
  mainWithFlavor(AppFlavor.production, args);
}

