import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _deviceIdStorageKey = 'device_metadata.id';
const _unknownValue = 'unknown';

class DeviceMetadata {
  final String deviceId;
  final String deviceType;
  final String osName;
  final String osVersion;
  final String appVersion;

  const DeviceMetadata({
    required this.deviceId,
    required this.deviceType,
    required this.osName,
    required this.osVersion,
    required this.appVersion,
  });

  static Future<DeviceMetadata> collect() async {
    final deviceId = await _resolveDeviceId();
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceType = _detectDeviceType();
    final osName = deviceType == _unknownValue ? Platform.operatingSystem : deviceType;
    final osVersion = await _resolveOsVersion();

    return DeviceMetadata(
      deviceId: deviceId,
      deviceType: deviceType,
      osName: osName,
      osVersion: osVersion,
      appVersion: packageInfo.version,
    );
  }

  Map<String, String> toRequestBody() {
    return {
      'device_id': deviceId,
      'device_type': deviceType,
      'os_name': osName,
      'os_version': osVersion,
      'app_version': appVersion,
    };
  }
}

String _detectDeviceType() {
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  return _unknownValue;
}

Future<String> _resolveDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString(_deviceIdStorageKey);
  if (cached != null && cached.isNotEmpty) return cached;

  final generated = const Uuid().v4();
  await prefs.setString(_deviceIdStorageKey, generated);
  return generated;
}

Future<String> _resolveOsVersion() async {
  final plugin = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return info.version.release ?? info.version.sdkInt?.toString() ?? Platform.operatingSystemVersion;
    }
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return info.systemVersion ?? Platform.operatingSystemVersion;
    }
  } catch (_) {
    // Ignore and return fallback below
  }
  return Platform.operatingSystemVersion;
}
