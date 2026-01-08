import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import 'devices_provider.dart';

/// ✅ selectedDeviceIdProvider(=IP) → Device?
final selectedDeviceProvider = Provider<Device?>((ref) {
  final st = ref.watch(devicesControllerProvider);
  final selectedIp = ref.watch(selectedDeviceIdProvider);
  if (selectedIp == null) return null;

  for (final d in st.devices) {
    if (d.ip == selectedIp) return d;
  }
  return null;
});
