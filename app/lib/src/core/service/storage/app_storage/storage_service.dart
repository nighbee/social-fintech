import 'package:app/src/core/service/storage/key_store.dart';
import 'package:app/src/core/utils/loggers/log.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'implementations/app/app_storage.dart';
part 'implementations/app/app_storage_impl.dart';
part 'interface/key_value_storage.dart';

final prefsInstance = KeyValueStorageImpl();
