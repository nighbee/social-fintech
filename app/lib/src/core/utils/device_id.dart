import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:app/src/core/service/storage/app_storage/storage_service.dart';

class DeviceId {
  static final DeviceId _instance = DeviceId._internal();
  factory DeviceId() => _instance;
  DeviceId._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Uuid _uuid = const Uuid();
  final _storage = KeyValueStorageImpl();

  static const String _deviceIdKey = 'DEVICE_ID';

  /// Get or generate device ID
  /// First tries to get from storage, if not exists generates and saves one
  Future<String> getDeviceId() async {
    // Ensure storage is initialized
    await _storage.initialize();
    
    // Try to get from storage first
    final storedId = _storage.get<String>(_deviceIdKey);
    if (storedId != null && storedId.isNotEmpty) {
      return storedId;
    }

    // Generate new device ID
    String deviceId;
    try {
      // Try to use device-specific ID if available
      final androidInfo = await _deviceInfo.androidInfo;
      deviceId = androidInfo.id; // Android ID
      
      // If Android ID is not available or invalid, generate UUID
      if (deviceId.isEmpty || deviceId == '9774d56d682e549c') {
        deviceId = _uuid.v4();
      }
    } catch (e) {
      // Fallback to UUID if device info is not available
      deviceId = _uuid.v4();
    }

    // Save for future use
    await _storage.set<String>(_deviceIdKey, deviceId);
    return deviceId;
  }

  /// Reset device ID (useful for testing)
  Future<void> resetDeviceId() async {
    await _storage.remove(_deviceIdKey);
  }
}

