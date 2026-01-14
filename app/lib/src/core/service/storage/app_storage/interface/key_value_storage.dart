part of "../storage_service.dart";

abstract interface class IKeyValueStorage {
  Future<IKeyValueStorage> initialize();

  Future<void> set<T>(String key, T value);
  T? get<T>(String key);
  Future<void> remove(String key);
}

final class KeyValueStorageImpl implements IKeyValueStorage {
  static KeyValueStorageImpl? _instance;
  late SharedPreferences _sharedPreferences;

  factory KeyValueStorageImpl() {
    _instance ??= KeyValueStorageImpl._();
    return _instance!;
  }

  KeyValueStorageImpl._();

  @override
  Future<IKeyValueStorage> initialize() async {
    _sharedPreferences = await SharedPreferences.getInstance();
    _instance = this;
    return this;
  }

  SharedPreferences get sharedPreferences => _sharedPreferences;

  @override
  Future<void> set<T>(String key, T value) async {
    if (value is int) {
      await _sharedPreferences.setInt(key, value);
    } else if (value is bool) {
      await _sharedPreferences.setBool(key, value);
    } else if (value is double) {
      await _sharedPreferences.setDouble(key, value);
    } else if (value is String) {
      await _sharedPreferences.setString(key, value);
    } else if (value is List<String>) {
      await _sharedPreferences.setStringList(key, value);
    } else {
      throw ArgumentError('Unsupported type: ${value.runtimeType}');
    }
    Log.debug('SharedPreferences [SET] $key', '$value');
  }

  @override
  T? get<T>(String key) {
    dynamic result;
    if (T == int) {
      result = _sharedPreferences.getInt(key);
    } else if (T == bool) {
      result = _sharedPreferences.getBool(key);
    } else if (T == double) {
      result = _sharedPreferences.getDouble(key);
    } else if (T == String) {
      result = _sharedPreferences.getString(key);
    } else if (T == List<String>) {
      result = _sharedPreferences.getStringList(key);
    } else {
      throw ArgumentError('Unsupported type: $T');
    }
    Log.debug('SharedPreferences [GET] $key', '$result');
    return result;
  }

  @override
  Future<void> remove(String key) async {
    await _sharedPreferences.remove(key);
    Log.debug('SharedPreferences [REMOVE] $key', 'removed');
  }
}
