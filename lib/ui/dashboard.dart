import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../providers/devices_provider.dart';
import '../providers/selected_device_provider.dart';

import '../providers/app_mode_provider.dart';
import '../providers/engineer_password_provider.dart';

import '../services/config_web_api.dart';

import 'config_panel.dart';

class Dashboard extends ConsumerWidget {
  const Dashboard({super.key});

  Widget _ledIcon(Device d) {
    if (d.ledState == LedState.blink) {
      if (!d.blinkPhase) return const SizedBox(width: 24);
      return const Icon(Icons.circle, color: Colors.orange);
    }
    if (d.ledState == LedState.on) {
      return const Icon(Icons.circle, color: Colors.green);
    }
    return const Icon(Icons.circle_outlined, color: Colors.grey);
  }

  Future<bool> _askEngineerPassword(BuildContext context, WidgetRef ref) async {
    final saved = ref.read(engineerPasswordProvider);
    final ctrl = TextEditingController();

    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('엔지니어 모드'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '비밀번호',
            hintText: '기본 1234',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text == saved) Navigator.pop(context, true);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _changeEngineerPassword(BuildContext context, WidgetRef ref) {
    final current = ref.read(engineerPasswordProvider);
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('비밀번호 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '현재 비밀번호'),
            ),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '새 비밀번호'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (oldCtrl.text == current && newCtrl.text.isNotEmpty) {
                ref.read(engineerPasswordProvider.notifier).state = newCtrl.text;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('비밀번호가 변경되었습니다.')),
                );
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appModeProvider);
    final st = ref.watch(devicesControllerProvider);
    final ctrl = ref.read(devicesControllerProvider.notifier);
    final selectedDevice = ref.watch(selectedDeviceProvider);

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        title: Text(
          mode == AppMode.installer
              ? "LocationX Windows (Installer)"
              : "LocationX Windows (Engineer)",
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text("Devices: ${st.devices.length}")),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Consumer(builder: (context, ref, _) {
              final m = ref.watch(appModeProvider);
              return FilledButton.tonalIcon(
                icon: Icon(m == AppMode.engineer ? Icons.lock_open : Icons.lock),
                label: Text(m == AppMode.engineer ? "설치자 모드" : "엔지니어 모드"),
                onPressed: () async {
                  if (m == AppMode.engineer) {
                    ref.read(appModeProvider.notifier).state = AppMode.installer;
                    return;
                  }
                  final ok = await _askEngineerPassword(context, ref);
                  if (ok) ref.read(appModeProvider.notifier).state = AppMode.engineer;
                },
              );
            }),
          ),
          if (mode == AppMode.engineer)
            IconButton(
              tooltip: '비밀번호 변경',
              onPressed: () => _changeEngineerPassword(context, ref),
              icon: const Icon(Icons.password),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // LEFT
            SizedBox(
              width: 440,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: (st.discovering || st.busy)
                                ? null
                                : () => ctrl.discover(),
                            icon: const Icon(Icons.radar),
                            label: Text(st.discovering ? "Discovering..." : "Discover (UDP)"),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: st.devices.isEmpty
                                ? null
                                : () {
                              ctrl.clearDevices();
                              ref.read(selectedDeviceIdProvider.notifier).state = null;
                            },
                            child: const Text("Clear"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (st.error != null)
                        Text(st.error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 10),

                      Expanded(
                        child: st.devices.isEmpty
                            ? const Center(
                          child: Text(
                            "Discover를 누르면 같은 LAN의 LocationX 장비가 UDP로 응답합니다.\n"
                                "표시: hostname / ip / fw / mac / led",
                            textAlign: TextAlign.center,
                          ),
                        )
                            : ListView.separated(
                          itemCount: st.devices.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final d = st.devices[i];
                            final selected = (selectedDevice?.ip == d.ip);
                            final macLabel = (d.mac == null || d.mac!.isEmpty) ? "N/A" : d.mac!;
                            return ListTile(
                              key: ValueKey(d.ip),
                              dense: true,
                              selected: selected,
                              title: Text(
                                d.hostname,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                "IP: ${d.ip} | MAC: $macLabel | FW: ${d.fw}",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: _ledIcon(d),
                              onTap: () {
                                ref.read(selectedDeviceIdProvider.notifier).state = d.ip;
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // RIGHT
            Expanded(
              child: mode == AppMode.installer
                  ? _InstallerTabs(selectedDevice: selectedDevice, st: st, ctrl: ctrl)
                  : _EngineerPanel(selectedDevice: selectedDevice, st: st, ctrl: ctrl),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// Engineer panel
// =====================================================
class _EngineerPanel extends StatelessWidget {
  final Device? selectedDevice;
  final dynamic st;
  final dynamic ctrl;

  const _EngineerPanel({
    required this.selectedDevice,
    required this.st,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final d = selectedDevice;

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: d == null
                ? const Text("왼쪽에서 장비를 선택하세요.")
                : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _SelectedDeviceInfo(d: d)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 220,
                  child: FilledButton(
                    onPressed: st.busy ? null : () => ctrl.identify(d.ip),
                    child: Text(st.busy ? "처리중..." : "Identify (LED 점멸)"),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(height: 720, child: const ConfigPanel()),
      ],
    );
  }
}

class _SelectedDeviceInfo extends StatelessWidget {
  final Device d;
  const _SelectedDeviceInfo({required this.d});

  @override
  Widget build(BuildContext context) {
    final macLabel = (d.mac == null || d.mac!.isEmpty) ? "N/A" : d.mac!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("선택 장비", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text("Hostname: ${d.hostname}", maxLines: 1, overflow: TextOverflow.ellipsis),
        Text("IP: ${d.ip}", maxLines: 1, overflow: TextOverflow.ellipsis),
        Text("MAC: $macLabel", maxLines: 1, overflow: TextOverflow.ellipsis),
        Text("FW: ${d.fw}", maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

// =====================================================
// Installer: Tabs + Arrow nav + Multi-locator coordinate input
// 탭 순서: 불러오기 -> 설치방식 -> 좌표입력 -> MQTT설정 -> 적용
// =====================================================
class _LocatorRow {
  String id; // ble-pd-xxxx
  double x, y, z;
  double ox, oy, oz; // orientation
  _LocatorRow({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    required this.ox,
    required this.oy,
    required this.oz,
  });
}

class _InstallerTabs extends StatefulWidget {
  final Device? selectedDevice;
  final dynamic st;
  final dynamic ctrl;

  const _InstallerTabs({
    required this.selectedDevice,
    required this.st,
    required this.ctrl,
  });

  @override
  State<_InstallerTabs> createState() => _InstallerTabsState();
}

class _InstallerTabsState extends State<_InstallerTabs> {
  final api = const ConfigWebApi(port: 8080);

  final mqttIpCtrl = TextEditingController();
  final mqttPortCtrl = TextEditingController(text: '1883');

  String installMode = 'multiple'; // single/multiple
  bool working = false;
  String? msg;

  String locatorJson = '';
  String positioningJson = '';
  String mqttText = '';

  // multi locator inputs
  int locatorCount = 4;
  final List<_LocatorRow> rows = [
    _LocatorRow(id: 'ble-pd-REPLACE_ME_1', x: 0, y: 0, z: 3, ox: 0, oy: 180, oz: 90),
    _LocatorRow(id: 'ble-pd-REPLACE_ME_2', x: 3, y: 0, z: 3, ox: 0, oy: 180, oz: 90),
    _LocatorRow(id: 'ble-pd-REPLACE_ME_3', x: 2, y: -1, z: 3, ox: 0, oy: 180, oz: 90),
    _LocatorRow(id: 'ble-pd-REPLACE_ME_4', x: 2, y: -2, z: 3, ox: 0, oy: 180, oz: 90),
  ];

  late final TabController _tabCtrl;
  final _tabIdx = ValueNotifier<int>(0);

  @override
  void dispose() {
    mqttIpCtrl.dispose();
    mqttPortCtrl.dispose();
    _tabIdx.dispose();
    super.dispose();
  }

  // ---------- Arrow nav ----------
  Widget _navArrows() {
    return Row(
      children: [
        IconButton(
          tooltip: '이전',
          onPressed: _tabIdx.value <= 0
              ? null
              : () => DefaultTabController.of(context).animateTo(_tabIdx.value - 1),
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: '다음',
          onPressed: _tabIdx.value >= 4
              ? null
              : () => DefaultTabController.of(context).animateTo(_tabIdx.value + 1),
          icon: const Icon(Icons.arrow_forward),
        ),
        const Spacer(),
        if (working) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Text(working ? 'Working...' : ''),
      ],
    );
  }

  // ---------- Load ----------
  Future<void> _loadFromPi() async {
    final d = widget.selectedDevice;
    if (d == null) {
      setState(() => msg = '장비를 먼저 선택하세요.');
      return;
    }

    setState(() {
      working = true;
      msg = null;
    });

    try {
      // ✅ UI 멈춤 체감 줄이기: 6초 타임아웃
      final data = await api.load(d.ip).timeout(const Duration(seconds: 6));

      mqttText = (data['mqtt'] ?? '');
      locatorJson = (data['locator'] ?? '');
      positioningJson = (data['positioning'] ?? '');

      final host = _pickKv(mqttText, 'BROKER_HOST');
      final port = _pickKv(mqttText, 'BROKER_PORT');
      if (host != null) mqttIpCtrl.text = host;
      if (port != null) mqttPortCtrl.text = port;

      // positioning에서 locators가 있으면 UI 테이블로도 반영
      _tryParseLocatorsFromPositioning(positioningJson);

      if (!mounted) return;
      setState(() => msg = '불러오기 완료 (BROKER_HOST=${mqttIpCtrl.text})');

      // ✅ 불러오기 성공하면 다음 탭으로 자동 이동 (원하면 유지/삭제 가능)
      DefaultTabController.of(context).animateTo(1);
    } catch (e) {
      if (!mounted) return;
      setState(() => msg = 'Load 실패(Timeout/Parse): $e');
    } finally {
      if (!mounted) return;
      setState(() => working = false);
    }
  }

  // ---------- Apply ----------
  Future<void> _saveApplyToPi() async {
    final d = widget.selectedDevice;
    if (d == null) {
      setState(() => msg = '장비를 먼저 선택하세요.');
      return;
    }

    final brokerIp = mqttIpCtrl.text.trim();
    final brokerPort = mqttPortCtrl.text.trim();

    if (brokerIp.isEmpty) {
      setState(() => msg = 'MQTT 서버 IP를 입력하세요.');
      return;
    }

    setState(() {
      working = true;
      msg = null;
    });

    try {
      // 1) 현재 서버 내용 로드(안전)
      final data = await api.load(d.ip).timeout(const Duration(seconds: 6));
      final oldMqtt = (data['mqtt'] ?? '');

      // 2) mqtt 갱신(중복 키 제거 후 삽입)
      var newMqtt = _removeAllKeys(oldMqtt, {'BROKER_HOST', 'BROKER_PORT'});
      newMqtt = _ensureEndsWithNewline(newMqtt);
      newMqtt += 'BROKER_HOST=$brokerIp\n';
      newMqtt += 'BROKER_PORT=$brokerPort\n';

      // 3) JSON 결정
      final useLocator = (installMode == 'single') ? (locatorJson.isNotEmpty ? locatorJson : _defaultSingleLocatorJson()) : locatorJson;
      final usePositioning = (installMode == 'multiple') ? _buildPositioningJsonFromRows() : positioningJson;

      // 4) Save + Apply
      await api.save(ip: d.ip, mqtt: newMqtt, locator: useLocator, positioning: usePositioning);
      await api.apply(d.ip);

      // 5) 검증
      final verify = await api.load(d.ip).timeout(const Duration(seconds: 6));
      final vMqtt = verify['mqtt'] ?? '';
      final vHost = _pickKv(vMqtt, 'BROKER_HOST');
      final vPort = _pickKv(vMqtt, 'BROKER_PORT');

      if (!mounted) return;
      setState(() => msg = '적용 완료. (Pi: BROKER_HOST=$vHost, BROKER_PORT=$vPort)');
    } catch (e) {
      if (!mounted) return;
      setState(() => msg = '적용 실패: $e');
    } finally {
      if (!mounted) return;
      setState(() => working = false);
    }
  }

  // ---------- Multi-locator UI helpers ----------
  void _setLocatorCount(int n) {
    setState(() {
      locatorCount = n;
      while (rows.length < n) {
        final idx = rows.length + 1;
        rows.add(_LocatorRow(
          id: 'ble-pd-REPLACE_ME_$idx',
          x: 0,
          y: 0,
          z: 3,
          ox: 0,
          oy: 180,
          oz: 90,
        ));
      }
      while (rows.length > n) {
        rows.removeLast();
      }
    });
  }

  void _tryParseLocatorsFromPositioning(String positioningText) {
    try {
      final obj = jsonDecode(positioningText);
      if (obj is! Map<String, dynamic>) return;
      final locs = obj['locators'];
      if (locs is! List) return;

      final parsed = <_LocatorRow>[];
      for (final it in locs) {
        if (it is! Map) continue;
        final id = (it['id'] ?? '').toString();
        final c = it['coordinate'] as Map?;
        final o = it['orientation'] as Map?;
        if (c == null || o == null) continue;

        parsed.add(_LocatorRow(
          id: id,
          x: (c['x'] as num?)?.toDouble() ?? 0,
          y: (c['y'] as num?)?.toDouble() ?? 0,
          z: (c['z'] as num?)?.toDouble() ?? 3,
          ox: (o['x'] as num?)?.toDouble() ?? 0,
          oy: (o['y'] as num?)?.toDouble() ?? 180,
          oz: (o['z'] as num?)?.toDouble() ?? 90,
        ));
      }

      if (parsed.isNotEmpty) {
        locatorCount = parsed.length;
        rows
          ..clear()
          ..addAll(parsed);
      }
    } catch (_) {
      // ignore
    }
  }

  String _defaultSingleLocatorJson() {
    // 필요하면 여기 기본값을 네가 원하는 single 템플릿으로 바꿔도 됨
    return const JsonEncoder.withIndent('   ').convert({
      "version": 1,
      "aoxMode": "SL_RTL_AOX_MODE_REAL_TIME_BASIC",
      "antennaMode": "SL_RTL_AOX_ARRAY_TYPE_4x4_URA",
      "antennaArray": List.generate(16, (i) => i),
      "angleFiltering": true,
      "angleFilteringWeight": 0.6,
      "angleCorrectionTimeout": 5,
      "angleCorrectionDelay": 3,
      "cteMode": "CONNLESS",
      "cteSamplingInterval": 3,
      "cteLength": 20,
      "slotDuration": 1,
      "reportMode": "ANGLE",
      "allowList": null,
      "azimuthMask": null,
      "elevationMask": null
    });
  }

  String _buildPositioningJsonFromRows() {
    final locators = rows.take(locatorCount).map((r) {
      return {
        "id": r.id,
        "config": {
          "version": 1,
          "aoxMode": "SL_RTL_AOD_MODE_REAL_TIME_FAST_RESPONSE",
          "antennaMode": "SL_RTL_AOX_ARRAY_TYPE_4x4_URA",
          "antennaArray": null,
          "angleFiltering": true,
          "angleFilteringWeight": 0.6,
          "angleCorrectionTimeout": 5,
          "angleCorrectionDelay": 1,
          "cteMode": "SILABS",
          "periodSamples": 64,
          "cteSamplingInterval": 1,
          "cteLength": 160,
          "slotDuration": 1,
          "reportMode": "ANGLE",
          "allowList": [],
          "azimuthMask": [],
          "elevationMask": []
        },
        "coordinate": {"x": r.x, "y": r.y, "z": r.z},
        "orientation": {"x": r.ox, "y": r.oy, "z": r.oz}
      };
    }).toList();

    final obj = {
      "version": 1,
      "id": "positioning-test_room",
      "estimationModeLocation": "SL_RTL_LOC_ESTIMATION_MODE_THREE_DIM_HIGH_ACCURACY",
      "validationModeLocation": "SL_RTL_LOC_MEASUREMENT_VALIDATION_FULL",
      "estimationIntervalSec": 0.02,
      "locationFiltering": true,
      "locationFilteringWeight": 0.1,
      "numberOfSequenceIds": 6,
      "maximumSequenceIdDiffs": 20,
      "locators": locators,
    };
    return const JsonEncoder.withIndent('   ').convert(obj);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.selectedDevice;
    final canUse = (d != null) && (!working);

    return DefaultTabController(
      length: 5,
      child: Builder(builder: (ctx) {
        _tabCtrl = DefaultTabController.of(ctx);
        _tabCtrl.addListener(() {
          if (_tabCtrl.indexIsChanging) return;
          _tabIdx.value = _tabCtrl.index;
        });

        return Column(
          children: [
            // 상단: 선택 장비 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: d == null
                    ? const Text("왼쪽에서 장비를 선택하세요.")
                    : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _SelectedDeviceInfo(d: d)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 220,
                      child: FilledButton(
                        onPressed: widget.st.busy ? null : () => widget.ctrl.identify(d.ip),
                        child: Text(widget.st.busy ? "처리중..." : "Identify (LED 점멸)"),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (msg != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: Text(
                  msg!,
                  style: TextStyle(
                    color: msg!.contains('실패') ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

            // ✅ 화살표 네비게이션 (요구사항 #1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ValueListenableBuilder<int>(
                valueListenable: _tabIdx,
                builder: (_, __, ___) => _navArrows(),
              ),
            ),

            const SizedBox(height: 6),

            // ✅ 탭 순서 변경 (요구사항 #3)
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: '불러오기'),
                Tab(text: '설치 방식'),
                Tab(text: '좌표 입력(다중)'),
                Tab(text: 'MQTT 설정'),
                Tab(text: '적용'),
              ],
            ),

            const SizedBox(height: 8),

            Expanded(
              child: TabBarView(
                children: [
                  // 1) 불러오기
                  ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("불러오기 (Pi 서버 GET /)", style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: canUse ? _loadFromPi : null,
                                icon: const Icon(Icons.download),
                                label: Text(working ? "Loading..." : "Load (GET /)"),
                              ),
                              const SizedBox(height: 10),
                              Text(d == null ? "장비 선택 후 사용할 수 있습니다." : "대상: http://${d.ip}:8080/"),
                              const SizedBox(height: 10),
                              const Text("불러오면 mqtt/locator/positioning 텍스트를 가져오고, positioning에 locators가 있으면 좌표 테이블도 채워집니다."),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 2) 설치 방식
                  ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("설치 방식", style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              RadioListTile<String>(
                                value: 'single',
                                groupValue: installMode,
                                onChanged: working ? null : (v) => setState(() => installMode = v ?? 'single'),
                                title: const Text("단일 Locator (Angle)"),
                              ),
                              RadioListTile<String>(
                                value: 'multiple',
                                groupValue: installMode,
                                onChanged: working ? null : (v) => setState(() => installMode = v ?? 'multiple'),
                                title: const Text("다중 Locator (Positioning)"),
                              ),
                              const SizedBox(height: 8),
                              Text("현재 선택: ${installMode == 'single' ? 'Single' : 'Multiple'}"),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 3) 좌표 입력(다중)
                  ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("다중 Locator 좌표 입력", style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  const Text("Locator 개수: "),
                                  const SizedBox(width: 8),
                                  DropdownButton<int>(
                                    value: locatorCount,
                                    items: [2, 3, 4, 5, 6, 7, 8]
                                        .map((n) => DropdownMenuItem(value: n, child: Text("$n")))
                                        .toList(),
                                    onChanged: working ? null : (v) => _setLocatorCount(v ?? 4),
                                  ),
                                  const Spacer(),
                                  FilledButton.icon(
                                    onPressed: working
                                        ? null
                                        : () {
                                      final built = _buildPositioningJsonFromRows();
                                      setState(() {
                                        positioningJson = built;
                                        msg = 'positioning_config.json 자동 생성됨 (locators=$locatorCount)';
                                      });
                                    },
                                    icon: const Icon(Icons.auto_fix_high),
                                    label: const Text("JSON 생성"),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // 테이블 형태 입력
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text("ID")),
                                    DataColumn(label: Text("x")),
                                    DataColumn(label: Text("y")),
                                    DataColumn(label: Text("z")),
                                    DataColumn(label: Text("ox")),
                                    DataColumn(label: Text("oy")),
                                    DataColumn(label: Text("oz")),
                                  ],
                                  rows: List.generate(locatorCount, (i) {
                                    final r = rows[i];
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          SizedBox(
                                            width: 220,
                                            child: TextFormField(
                                              initialValue: r.id,
                                              onChanged: (v) => r.id = v.trim(),
                                              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                            ),
                                          ),
                                        ),
                                        _numCell(r.x, (v) => r.x = v),
                                        _numCell(r.y, (v) => r.y = v),
                                        _numCell(r.z, (v) => r.z = v),
                                        _numCell(r.ox, (v) => r.ox = v),
                                        _numCell(r.oy, (v) => r.oy = v),
                                        _numCell(r.oz, (v) => r.oz = v),
                                      ],
                                    );
                                  }),
                                ),
                              ),

                              const SizedBox(height: 10),
                              Text(
                                installMode != 'multiple'
                                    ? "현재 설치 방식이 Single 입니다. (Multiple을 선택하면 이 좌표가 사용됩니다.)"
                                    : "Multiple 모드에서는 이 좌표/ID로 positioning_config.json이 생성되어 적용됩니다.",
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 4) MQTT 설정
                  ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("MQTT 서버 설정", style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: mqttIpCtrl,
                                      enabled: !working,
                                      decoration: const InputDecoration(
                                        labelText: "MQTT 서버 IP",
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 160,
                                    child: TextField(
                                      controller: mqttPortCtrl,
                                      enabled: !working,
                                      decoration: const InputDecoration(
                                        labelText: "Port",
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text("이 값이 Pi의 mqtt_server_setting.txt(BROKER_HOST/PORT)에 반영됩니다."),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 5) 적용
                  ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Save + Apply", style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text("설치 방식: ${installMode == 'single' ? 'Single' : 'Multiple'}"),
                              Text("MQTT(입력): ${mqttIpCtrl.text.trim().isEmpty ? '(미입력)' : mqttIpCtrl.text.trim()} : ${mqttPortCtrl.text.trim()}"),
                              if (installMode == 'multiple')
                                Text("Locators: $locatorCount (좌표/ID 기반 JSON 생성됨)"),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: canUse ? _saveApplyToPi : null,
                                icon: const Icon(Icons.check_circle),
                                label: Text(working ? "Working..." : "Apply (Save + Apply)"),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Apply는 Pi에서:\n"
                                    "- mqtt_server_setting.txt 업데이트\n"
                                    "- locator_config.json / positioning_config.json 교체 + backup\n"
                                    "- aoa 스크립트 -m 패치\n"
                                    "까지 반영됩니다.",
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  // DataTable numeric cell
  DataCell _numCell(double value, void Function(double) onSet) {
    return DataCell(
      SizedBox(
        width: 80,
        child: TextFormField(
          initialValue: value.toString(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          onChanged: (v) {
            final n = double.tryParse(v.trim());
            if (n != null) onSet(n);
          },
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
        ),
      ),
    );
  }

  // mqtt helpers
  String _normalizeLine(String s) => s.replaceAll('\r', '');

  String? _pickKv(String text, String key) {
    final lines = _normalizeLine(text).split('\n');
    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('#')) continue;
      final idx = t.indexOf('=');
      if (idx <= 0) continue;
      final k = t.substring(0, idx).trim();
      final v = t.substring(idx + 1).trim();
      if (k == key) return v;
    }
    return null;
  }

  String _removeAllKeys(String text, Set<String> keys) {
    final out = <String>[];
    final lines = _normalizeLine(text).split('\n');
    for (final line in lines) {
      final raw = line;
      final t = raw.trim();
      if (t.isEmpty) {
        out.add(raw);
        continue;
      }
      if (t.startsWith('#')) {
        out.add(raw);
        continue;
      }
      final idx = t.indexOf('=');
      if (idx <= 0) {
        out.add(raw);
        continue;
      }
      final k = t.substring(0, idx).trim();
      if (keys.contains(k)) continue;
      out.add(raw);
    }
    return out.join('\n').trimRight();
  }

  String _ensureEndsWithNewline(String s) {
    if (s.isEmpty) return '';
    return s.endsWith('\n') ? s : '$s\n';
  }
}
