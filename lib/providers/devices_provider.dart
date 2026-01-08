import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../services/udp_discovery.dart';
import '../services/udp_led_sender.dart';

/// Dashboard에서 사용하는 provider 이름 유지
final devicesControllerProvider =
ChangeNotifierProvider<DevicesProvider>((ref) => DevicesProvider());

/// ✅ 선택된 장비 키 (중복 방지 위해 IP 사용)
final selectedDeviceIdProvider = StateProvider<String?>((ref) => null);

class DevicesProvider extends ChangeNotifier {
  final UdpDiscoveryService _udp;

  DevicesProvider({UdpDiscoveryService? udp})
      : _udp = udp ?? const UdpDiscoveryService();

  final List<Device> _devices = [];
  bool _isDiscovering = false;
  bool _busy = false;
  String? _lastError;

  Timer? _blinkTimer;

  /// ✅ IP 기반으로 점멸 관리 (중복 hostname 때문에 id/deviceId 쓰면 꼬일 수 있음)
  final Set<String> _blinkingIps = {}; // 여러 장비 동시에 blink 가능

  List<Device> get devices => List.unmodifiable(_devices);

  // Dashboard 호환 getter
  bool get discovering => _isDiscovering;
  bool get busy => _busy;
  String? get error => _lastError;

  /// Dashboard Discover 버튼
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

      // ✅ Discover 후 선택된 IP가 목록에 없으면 선택 해제
      // (UI에서 selectedDeviceIdProvider를 IP로 쓰는 전제)
      // 이 Provider 파일 단독으로는 ref 접근이 불가하므로,
      // UI 쪽에서 discover 후 selectedId 검증하는 게 더 깔끔.
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isDiscovering = false;
      notifyListeners();
    }
  }

  void clearDevices() {
    _devices.clear();
    _stopUiBlinkAll();
    notifyListeners();
  }

  /// UI에서 LED 상태 수동 변경(예: LED Off(UI))
  /// ✅ deviceKey는 IP로 받는 걸 권장
  void updateLedStateByIp(String ip, LedState state) {
    final idx = _devices.indexWhere((d) => d.ip == ip);
    if (idx < 0) return;

    final d = _devices[idx];
    _devices[idx] = d.copyWith(
      ledState: state,
      blinkPhase: true,
    );

    if (state == LedState.blink) {
      _blinkingIps.add(ip);
      _ensureBlinkTimer();
    } else {
      _blinkingIps.remove(ip);
      if (_blinkingIps.isEmpty) _stopBlinkTimer();
    }

    notifyListeners();
  }

  // -----------------------------
  // UI 아이콘 점멸 타이머 (IP 기반)
  // -----------------------------
  void _ensureBlinkTimer() {
    if (_blinkTimer != null) return;

    _blinkTimer = Timer.periodic(
      const Duration(milliseconds: 350), // UI는 2~3Hz가 보기 좋음
          (_) {
        if (_blinkingIps.isEmpty) return;

        bool changed = false;
        for (int i = 0; i < _devices.length; i++) {
          final d = _devices[i];
          if (d.ledState == LedState.blink && _blinkingIps.contains(d.ip)) {
            _devices[i] = d.copyWith(blinkPhase: !d.blinkPhase);
            changed = true;
          }
        }
        if (changed) notifyListeners();
      },
    );
  }

  void _stopBlinkTimer() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

  void _stopUiBlinkAll() {
    _blinkingIps.clear();
    _stopBlinkTimer();

    for (int i = 0; i < _devices.length; i++) {
      final d = _devices[i];
      if (d.blinkPhase == false) {
        _devices[i] = d.copyWith(blinkPhase: true);
      }
    }
  }

  // -----------------------------
  // ✅ Identify (실제 UDP 전송 + UI 아이콘 점멸 동기화)
  // -----------------------------
  /// ✅ 이제 identify는 "ip"로 호출하는 것을 표준으로
  Future<void> identify(String ip) async {
    final idx = _devices.indexWhere((d) => d.ip == ip);
    if (idx < 0) return;

    final device = _devices[idx];
    final led = const UdpLedSender();

    try {
      _busy = true;
      _lastError = null;

      // 1) UI: blink 시작
      _devices[idx] = device.copyWith(ledState: LedState.blink, blinkPhase: true);
      _blinkingIps.add(ip);
      _ensureBlinkTimer();
      notifyListeners();

      // 2) 실장비 LED: 파이썬에서 검증한 JSON과 동일
      await led.blink(
        ip: device.ip,
        port: 40002,
        color: 'magenta',
        hz: 3.0,
        durationSec: 8,
      );

      // 3) 점멸 종료 대기(파이썬 예제 그대로 10초)
      await Future.delayed(const Duration(seconds: 10));

      // 4) 파랑 고정 ON
      await led.setOn(
        ip: device.ip,
        port: 40002,
        color: 'blue',
      );

      // 5) UI: blink 종료 → on
      _blinkingIps.remove(ip);
      if (_blinkingIps.isEmpty) _stopBlinkTimer();

      // blinkPhase는 true로 정리
      final idx2 = _devices.indexWhere((d) => d.ip == ip);
      if (idx2 >= 0) {
        _devices[idx2] = _devices[idx2].copyWith(
          ledState: LedState.on,
          blinkPhase: true,
        );
      }

      notifyListeners();
    } catch (e) {
      _lastError = e.toString();

      // 실패 시 UI: off로 롤백 + blink 종료
      _blinkingIps.remove(ip);
      if (_blinkingIps.isEmpty) _stopBlinkTimer();

      final idx2 = _devices.indexWhere((d) => d.ip == ip);
      if (idx2 >= 0) {
        _devices[idx2] = _devices[idx2].copyWith(
          ledState: LedState.off,
          blinkPhase: true,
        );
      }

      notifyListeners();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // 아래는 현재 최소 UI에서는 사용 안 함 (빈 구현 유지)
  Future<void> refreshStatusesOnce() async {}
  void nextUnconfigured() {}
  Future<void> resetAll() async {}
}
/// ✅ 선택된 장비 객체를 IP 기준으로 찾아서 제공
final selectedDeviceProvider = Provider<Device?>((ref) {
  final ctrl = ref.watch(devicesControllerProvider);
  final selectedIp = ref.watch(selectedDeviceIdProvider);

  if (selectedIp == null) return null;

  for (final d in ctrl.devices) {
    if (d.ip == selectedIp) return d;
  }
  return null;
});

