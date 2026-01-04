import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../services/udp_discovery.dart';

/// Dashboard에서 사용하는 provider 이름 유지
final devicesControllerProvider =
ChangeNotifierProvider<DevicesProvider>((ref) => DevicesProvider());

/// 선택된 장비 ID
final selectedDeviceIdProvider = StateProvider<String?>((ref) => null);

class DevicesProvider extends ChangeNotifier {
  final UdpDiscoveryService _udp;

  DevicesProvider({UdpDiscoveryService? udp})
      : _udp = udp ?? const UdpDiscoveryService();

  final List<Device> _devices = [];
  bool _isDiscovering = false;
  bool _busy = false;
  String? _lastError;

  List<Device> get devices => List.unmodifiable(_devices);

  // Dashboard 호환 getter
  bool get discovering => _isDiscovering;
  bool get busy => _busy;
  String? get error => _lastError;

  /// Dashboard의 Discover(UDP) 버튼이 호출
  Future<void> discover() => discoverUdp();

  Future<void> discoverUdp() async {
    if (_isDiscovering) return;

    _isDiscovering = true;
    _lastError = null;
    notifyListeners();

    try {
      final found = await _udp.discover(appName: 'LocationX-Windows');

      _devices
        ..clear()
        ..addAll(found);
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isDiscovering = false;
      notifyListeners();
    }
  }

  void clearDevices() {
    _devices.clear();
    notifyListeners();
  }

  /// ✅ LED 상태만 UI에 반영 (실제 UDP 전송은 identify()에서 다음 단계로 구현)
  void updateLedState(String deviceId, LedState state) {
    final idx = _devices.indexWhere((d) => d.deviceId == deviceId);
    if (idx < 0) return;

    _devices[idx] = _devices[idx].copyWith(ledState: state);
    notifyListeners();
  }

  // -----------------------------
  // 아래는 현재 UI가 호출하지만, 아직 실장비 구현 전이라 "빈 구현"
  // -----------------------------
  void select(String deviceId) {
    // 선택은 Dashboard에서 selectedDeviceIdProvider를 직접 set 하도록 권장
  }

  Future<void> refreshStatusesOnce() async {
    // 지금은 사용 안 함 (hostname/ip/fw/ledState만 표시)
  }

  Future<void> identify(String deviceId) async {
    // 다음 단계에서:
    // - deviceId로 device 찾아서
    // - LED UDP port로 LED_BLINK JSON 전송
    // - 일정 시간 뒤 OFF로 돌아오기
  }

  Future<void> confirmPosition({
    required String deviceId,
    required String floorId,
    required int anchorId,
    required double x,
    required double y,
    required double z,
    required double yawDeg,
    required String floorplanId,
    bool autoNext = false,
  }) async {
    // 현재는 리스트 최소화 단계라 사용 안 함
  }

  void nextUnconfigured() {
    // 현재는 사용 안 함
  }

  Future<void> resetAll() async {
    // 현재는 실장비 모드라 사용 안 함
  }
}
