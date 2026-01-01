import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device.dart';

// ✅ UI에서 조절할 "전체 장비 수"
final deviceCountProvider = StateProvider<int>((ref) => 50);

class DevicesNotifier extends StateNotifier<List<Device>> {
  DevicesNotifier(this.ref) : super(_seed(ref.read(deviceCountProvider)));

  final Ref ref;

  static List<Device> _seed(int count) {
    // 데모용 장비 목록 생성
    return List.generate(count, (i) {
      final n = i + 1;
      final id = 'AX-${n.toString().padLeft(2, '0')}';
      final ip = '192.168.0.${100 + n}';

      // 일부는 미설정으로 남겨서 작업 큐가 보이게
      final baseStatus = (n % 7 == 0)
          ? DeviceStatus.onlineUnconfigured
          : DeviceStatus.onlineConfigured;

      // 몇 대는 오프라인/에러 데모
      final status = (n == 9)
          ? DeviceStatus.offline
          : (n == 13)
          ? DeviceStatus.error
          : baseStatus;

      return Device(id: id, ip: ip, status: status);
    });
  }

  /// 🔁 장비 수 변경: 전체 재생성(데모 데이터 리셋)
  void resetWithCount(int count) {
    state = _seed(count);
  }

  void identify(String id) {
    // TODO: 백엔드 붙이면 여기서 API 호출
  }

  void setConfigured(String id) {
    state = [
      for (final d in state)
        if (d.id == id) d.copyWith(status: DeviceStatus.onlineConfigured) else d
    ];
  }

  void setUnconfigured(String id) {
    // 위치도 같이 지우고 작업 큐로 복귀
    state = [
      for (final d in state)
        if (d.id == id)
          d.copyWith(status: DeviceStatus.onlineUnconfigured, clearPos: true)
        else
          d
    ];
  }

  void setDeviceFloorPos(String id, double fx, double fy) {
    state = [
      for (final d in state)
        if (d.id == id) d.copyWith(fx: fx, fy: fy) else d
    ];
  }
}

final devicesProvider =
StateNotifierProvider<DevicesNotifier, List<Device>>((ref) {
  return DevicesNotifier(ref);
});

// “작업 큐” = 미설정만
final unconfiguredQueueProvider = Provider<List<Device>>((ref) {
  final devices = ref.watch(devicesProvider);
  final q = devices
      .where((d) => d.status == DeviceStatus.onlineUnconfigured)
      .toList();
  q.sort((a, b) => a.id.compareTo(b.id));
  return q;
});

// 현재 작업 1대
final currentTaskProvider = Provider<Device?>((ref) {
  final q = ref.watch(unconfiguredQueueProvider);
  return q.isEmpty ? null : q.first;
});

// 요약
final summaryProvider =
Provider<({int total, int online, int unconfigured, int offline, int error})>(
        (ref) {
      final devices = ref.watch(devicesProvider);
      final total = devices.length;
      final offline = devices.where((d) => d.status == DeviceStatus.offline).length;
      final error = devices.where((d) => d.status == DeviceStatus.error).length;
      final unconfigured =
          devices.where((d) => d.status == DeviceStatus.onlineUnconfigured).length;
      final online = total - offline; // 단순화: offline만 제외
      return (
      total: total,
      online: online,
      unconfigured: unconfigured,
      offline: offline,
      error: error
      );
    });

// 선택된 장비 ID (DeviceList 클릭으로 바뀜)
final selectedDeviceIdProvider = StateProvider<String?>((ref) {
  final current = ref.watch(currentTaskProvider);
  return current?.id;
});

// 평면도에서 클릭한 “임시 핀” (정규화 좌표)
final tempFloorPosProvider = StateProvider<Offset?>((ref) => null);
