import 'package:app/src/core/service/storage/app_storage/storage_service.dart';
import 'package:app/src/core/service/storage/key_store.dart';

/// Локальные настройки экрана «Location access» (бэкенд не используется).
const List<String> kLocationAccessOptionLabels = <String>[
  'Never',
  'Ask next time or when i share',
  'While using the app',
  'Always',
];

({String label, bool precise}) readLocationAccessPrefs({
  required String initialLabel,
  required bool initialPrecise,
}) {
  final storedLabel = prefsInstance.get<String>(KeyStore.locationAccessLabel);
  final storedPrecise = prefsInstance.get<bool>(KeyStore.locationAccessPrecise);

  String label = initialLabel;
  if (storedLabel != null && kLocationAccessOptionLabels.contains(storedLabel)) {
    label = storedLabel;
  } else if (kLocationAccessOptionLabels.contains(initialLabel)) {
    label = initialLabel;
  } else {
    label = kLocationAccessOptionLabels.first;
  }

  var precise = storedPrecise ?? initialPrecise;
  if (label == 'Never') {
    precise = false;
  }

  return (label: label, precise: precise);
}

Future<void> writeLocationAccessPrefs({
  required String label,
  required bool precise,
}) async {
  final effectivePrecise = label == 'Never' ? false : precise;
  await prefsInstance.set<String>(KeyStore.locationAccessLabel, label);
  await prefsInstance.set<bool>(
    KeyStore.locationAccessPrecise,
    effectivePrecise,
  );
}
