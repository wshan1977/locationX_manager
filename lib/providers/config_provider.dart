import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/simulator_api.dart';
import '../models/device_config.dart';
import 'devices_provider.dart';

final configControllerProvider =
StateNotifierProvider<ConfigController, ConfigState>((ref) {
  return ConfigController(ref);
});

class ConfigState {
  final bool loading;
  final bool saving;
  final String? error;
  final DeviceConfig? cfg;
  final bool dirty;

  const ConfigState({
    required this.loading,
    required this.saving,
    required this.dirty,
    this.cfg,
    this.error,
  });

  static const empty = ConfigState(loading: false, saving: false, dirty: false);
}

class ConfigController extends StateNotifier<ConfigState> {
  ConfigController(this.ref) : super(ConfigState.empty);

  final Ref ref;
  final _api = SimulatorApi(baseHost: "127.0.0.1", basePort: 8081);

  Future<void> loadForSelected() async {
    final deviceId = ref.read(selectedDeviceIdProvider);
    if (deviceId == null) return;

    state = ConfigState(loading: true, saving: false, dirty: false, cfg: null, error: null);
    try {
      final raw = await _api.getConfig(deviceId);
      state = ConfigState(loading: false, saving: false, dirty: false, cfg: DeviceConfig(raw), error: null);
    } catch (e) {
      state = ConfigState(loading: false, saving: false, dirty: false, cfg: null, error: e.toString());
    }
  }

  void markDirty() {
    if (state.cfg == null) return;
    state = ConfigState(loading: false, saving: state.saving, dirty: true, cfg: state.cfg, error: state.error);
  }

  Future<void> save() async {
    final deviceId = ref.read(selectedDeviceIdProvider);
    final cfg = state.cfg;
    if (deviceId == null || cfg == null) return;

    state = ConfigState(loading: false, saving: true, dirty: state.dirty, cfg: cfg, error: null);
    try {
      final resp = await _api.setConfig(deviceId, cfg.toPutBody());
      // 저장 후 서버 응답 기반으로 다시 로드(정합성)
      final raw = await _api.getConfig(deviceId);
      state = ConfigState(loading: false, saving: false, dirty: false, cfg: DeviceConfig(raw), error: null);

      // 장비 상태도 갱신(선택)
      ref.read(devicesControllerProvider.notifier).refreshStatusesOnce();

      // resp에 rebootRequired 등이 오면 여기서 UI로 보여줘도 됨
      (resp["rebootRequired"] ?? false);
    } catch (e) {
      state = ConfigState(loading: false, saving: false, dirty: state.dirty, cfg: cfg, error: e.toString());
    }
  }
}
