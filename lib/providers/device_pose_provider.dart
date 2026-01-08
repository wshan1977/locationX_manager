import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device_pose.dart';
import '../providers/devices_provider.dart';

class DevicePoseNotifier extends StateNotifier<Map<String, DevicePose>> {
  DevicePoseNotifier() : super(const {});

  DevicePose? getPose(String ip) => state[ip];

  void setPose(String ip, DevicePose pose) {
    state = {...state, ip: pose};
  }

  void removePose(String ip) {
    final m = {...state};
    m.remove(ip);
    state = m;
  }
}

/// ✅ ip -> pose 저장소
final devicePoseMapProvider =
StateNotifierProvider<DevicePoseNotifier, Map<String, DevicePose>>(
      (ref) => DevicePoseNotifier(),
);

/// ✅ 선택된 장비(ip)의 pose만 뽑아오는 provider
final selectedDevicePoseProvider = Provider<DevicePose?>((ref) {
  final ip = ref.watch(selectedDeviceIdProvider);
  if (ip == null) return null;
  final map = ref.watch(devicePoseMapProvider);
  return map[ip];
});
