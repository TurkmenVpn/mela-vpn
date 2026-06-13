import 'dart:async';

import 'package:melavpn/core/preferences/preferences_provider.dart';
import 'package:melavpn/core/utils/preferences_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'device_id_provider.g.dart';

const _kDeviceIdKey = 'melavpn_device_id';

/// Persistent unique device identifier shown in settings as "Happ ID".
/// Generated once on first launch and stored in SharedPreferences.
@Riverpod(keepAlive: true)
String deviceId(DeviceIdRef ref) {
  final prefs = ref.watch(sharedPreferencesProvider).requireValue;
  final existing = prefs.getString(_kDeviceIdKey);
  if (existing != null && existing.isNotEmpty) return existing;
  final newId = const Uuid().v4();
  unawaited(prefs.setString(_kDeviceIdKey, newId));
  return newId;
}

/// Short HWID — first 8 chars without dashes (displayed form).
@riverpod
String deviceIdShort(DeviceIdShortRef ref) {
  final full = ref.watch(deviceIdProvider);
  final stripped = full.replaceAll('-', '').padRight(8, '0');
  return stripped.substring(0, 8).toUpperCase();
}

/// Whether to send device ID as X-HWID header in subscription requests.
final sendHwidWithSubscription = PreferencesNotifier.create<bool, bool>('send_hwid_subscription', false);
