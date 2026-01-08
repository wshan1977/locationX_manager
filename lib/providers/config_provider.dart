import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_config.dart';
import '../services/locator_api.dart';
import 'devices_provider.dart';
import 'selected_device_provider.dart';

final configControllerProvider =
StateNotifierProvider<ConfigController, ConfigState>((ref) {
  return ConfigController(ref);
});

class ConfigState {
  final bool loading;
  final bool saving;
  final bool dirty;
  final DeviceConfig? cfg;
  final String? error;

  const ConfigState({
    required this.loading,
    required this.saving,
    required this.dirty,
    required this.cfg,
    required this.error,
  });

  static const empty = ConfigState(
    loading: false,
    saving: false,
    dirty: false,
    cfg: null,
    error: null,
  );
}

class ConfigController extends StateNotifier<ConfigState> {
  ConfigController(this.ref) : super(ConfigState.empty);

  final Ref ref;
  final LocatorApi _api = LocatorApi();

  String _deviceIdFromDev(dynamic dev) {
    // 서버가 deviceId로 ble-pd-XXXX를 받는 경우가 많음
    final mac = (dev.mac ?? "").toString();
    if (mac.isNotEmpty) return mac;
    return dev.hostname.toString();
  }

  /// ✅ 강제 로딩 해제(현장 디버깅용)
  void forceStopLoading() {
    state = ConfigState(
      loading: false,
      saving: false,
      dirty: state.dirty,
      cfg: state.cfg,
      error: state.error,
    );
  }

  /// ✅ 선택된 장비의 config 로드
  Future<void> loadForSelected() async {
    final dev = ref.read(selectedDeviceProvider);
    if (dev == null) return;

    final deviceId = _deviceIdFromDev(dev);

    state = ConfigState(
      loading: true,
      saving: false,
      dirty: false,
      cfg: state.cfg,
      error: null,
    );

    try {
      final raw = await _api
          .getConfig(ip: dev.ip, port: 8080, deviceId: deviceId)
          .timeout(const Duration(seconds: 4)); // ✅ 무한 대기 방지

      state = ConfigState(
        loading: false,
        saving: false,
        dirty: false,
        cfg: DeviceConfig(raw),
        error: null,
      );
    } catch (e) {
      state = ConfigState(
        loading: false,
        saving: false,
        dirty: false,
        cfg: state.cfg,
        error: e.toString(),
      );
    } finally {
      // ✅ 혹시라도 로딩이 남아있으면 강제 종료
      if (state.loading) {
        state = ConfigState(
          loading: false,
          saving: state.saving,
          dirty: state.dirty,
          cfg: state.cfg,
          error: state.error,
        );
      }
    }
  }

  void markDirty() {
    if (state.cfg == null) return;
    state = ConfigState(
      loading: state.loading,
      saving: state.saving,
      dirty: true,
      cfg: state.cfg,
      error: state.error,
    );
  }

  /// ✅ 현재 cfg 저장
  Future<void> save() async {
    final dev = ref.read(selectedDeviceProvider);
    final cfg = state.cfg;
    if (dev == null || cfg == null) return;

    final deviceId = _deviceIdFromDev(dev);

    state = ConfigState(
      loading: false,
      saving: true,
      dirty: state.dirty,
      cfg: cfg,
      error: null,
    );

    try {
      await _api
          .setConfig(ip: dev.ip, port: 8080, deviceId: deviceId, body: cfg.toPutBody())
          .timeout(const Duration(seconds: 4));

      // 저장 후 다시 로드(정합성)
      final raw = await _api
          .getConfig(ip: dev.ip, port: 8080, deviceId: deviceId)
          .timeout(const Duration(seconds: 4));

      state = ConfigState(
        loading: false,
        saving: false,
        dirty: false,
        cfg: DeviceConfig(raw),
        error: null,
      );

      // 선택: 상태 갱신 훅(필요 없으면 지워도 됨)
      ref.read(devicesControllerProvider.notifier).refreshStatusesOnce();
    } catch (e) {
      state = ConfigState(
        loading: false,
        saving: false,
        dirty: state.dirty,
        cfg: cfg,
        error: e.toString(),
      );
    } finally {
      if (state.saving) {
        state = ConfigState(
          loading: state.loading,
          saving: false,
          dirty: state.dirty,
          cfg: state.cfg,
          error: state.error,
        );
      }
    }
  }
}
